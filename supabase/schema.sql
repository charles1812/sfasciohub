-- SfascioHub · schema Supabase
-- Incollalo in Supabase → SQL Editor → New query → Run. Si può rieseguire.

-- ============================================================
-- Tabelle
-- ============================================================

-- Uno sfasciacarrozze (autodemolizione) iscritto alla piattaforma
create table if not exists public.yards (
  id          uuid primary key default gen_random_uuid(),
  owner_id    uuid not null references auth.users(id) on delete cascade,
  name        text not null check (char_length(name) between 2 and 80),
  city        text not null default '',
  province    text not null default '' check (char_length(province) <= 2),
  address     text not null default '',
  phone       text not null default '',
  whatsapp    text not null default '',
  email       text not null default '',
  hours       text not null default '',
  description text not null default '',
  lat         double precision,
  lng         double precision,
  published   boolean not null default true,
  created_at  timestamptz not null default now()
);
create index if not exists yards_owner_idx on public.yards(owner_id);

-- Chi lavora nello sfasciacarrozze (il titolare è 'owner', gli altri 'staff')
create table if not exists public.yard_members (
  yard_id uuid not null references public.yards(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role    text not null default 'staff' check (role in ('owner', 'staff')),
  primary key (yard_id, user_id)
);

-- Un veicolo presente nel piazzale
create table if not exists public.vehicles (
  id           uuid primary key default gen_random_uuid(),
  yard_id      uuid not null references public.yards(id) on delete cascade,
  make         text not null check (char_length(make) between 1 and 40),
  model        text not null check (char_length(model) between 1 and 60),
  version      text not null default '',
  year         int  check (year between 1950 and 2100),
  fuel         text not null default '' check (fuel in ('', 'benzina', 'diesel', 'gpl', 'metano', 'ibrida', 'elettrica')),
  color        text not null default '',
  km           int  check (km >= 0),
  engine_code  text not null default '',
  -- zone danneggiate: front, front_left, front_right, left, right, rear, rear_left, rear_right, roof, interior, engine, glass
  damage_zones text[] not null default '{}',
  notes        text not null default '',
  status       text not null default 'available' check (status in ('available', 'reserved', 'gone')),
  published    boolean not null default true,
  arrived_on   date not null default current_date,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists vehicles_yard_idx on public.vehicles(yard_id);
create index if not exists vehicles_search_idx on public.vehicles(make, model, year);

-- Foto di un veicolo (file nel bucket 'vehicle-photos')
create table if not exists public.vehicle_photos (
  id         uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  path       text not null,
  position   int  not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists vehicle_photos_vehicle_idx on public.vehicle_photos(vehicle_id, position);

-- ============================================================
-- Funzioni di supporto
-- ============================================================

create or replace function public.is_yard_member(y uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from yard_members m where m.yard_id = y and m.user_id = auth.uid());
$$;

-- Chi crea uno sfasciacarrozze ne diventa automaticamente titolare
create or replace function public.add_yard_owner()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into yard_members (yard_id, user_id, role) values (new.id, new.owner_id, 'owner')
  on conflict do nothing;
  return new;
end $$;
drop trigger if exists yards_add_owner on public.yards;
create trigger yards_add_owner after insert on public.yards
  for each row execute function public.add_yard_owner();

create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;
drop trigger if exists vehicles_touch on public.vehicles;
create trigger vehicles_touch before update on public.vehicles
  for each row execute function public.touch_updated_at();

-- ============================================================
-- Sicurezza (Row Level Security)
-- ============================================================
alter table public.yards          enable row level security;
alter table public.yard_members   enable row level security;
alter table public.vehicles       enable row level security;
alter table public.vehicle_photos enable row level security;

-- yards: tutti vedono quelli pubblicati, i membri vedono il proprio
drop policy if exists yards_read on public.yards;
create policy yards_read on public.yards for select
  using (published or public.is_yard_member(id));
drop policy if exists yards_insert on public.yards;
create policy yards_insert on public.yards for insert to authenticated
  with check (owner_id = auth.uid());
drop policy if exists yards_update on public.yards;
create policy yards_update on public.yards for update to authenticated
  using (public.is_yard_member(id)) with check (public.is_yard_member(id));
drop policy if exists yards_delete on public.yards;
create policy yards_delete on public.yards for delete to authenticated
  using (owner_id = auth.uid());

-- yard_members: ognuno vede le righe dei propri sfasciacarrozze
drop policy if exists members_read on public.yard_members;
create policy members_read on public.yard_members for select to authenticated
  using (public.is_yard_member(yard_id));

-- vehicles: il pubblico vede i veicoli pubblicati di sfasciacarrozze pubblicati
drop policy if exists vehicles_read on public.vehicles;
create policy vehicles_read on public.vehicles for select
  using (
    public.is_yard_member(yard_id)
    or (published and status <> 'gone'
        and exists (select 1 from yards y where y.id = yard_id and y.published))
  );
drop policy if exists vehicles_write on public.vehicles;
create policy vehicles_write on public.vehicles for all to authenticated
  using (public.is_yard_member(yard_id)) with check (public.is_yard_member(yard_id));

-- vehicle_photos: seguono il veicolo
drop policy if exists photos_read on public.vehicle_photos;
create policy photos_read on public.vehicle_photos for select
  using (exists (select 1 from vehicles v where v.id = vehicle_id));
drop policy if exists photos_write on public.vehicle_photos;
create policy photos_write on public.vehicle_photos for all to authenticated
  using (exists (select 1 from vehicles v where v.id = vehicle_id and public.is_yard_member(v.yard_id)))
  with check (exists (select 1 from vehicles v where v.id = vehicle_id and public.is_yard_member(v.yard_id)));

-- ============================================================
-- Storage: bucket pubblico per le foto, scrittura solo ai membri
-- Percorso dei file: <yard_id>/<vehicle_id>/<nome>.jpg
-- ============================================================
insert into storage.buckets (id, name, public)
values ('vehicle-photos', 'vehicle-photos', true)
on conflict (id) do update set public = true;

drop policy if exists photos_upload on storage.objects;
create policy photos_upload on storage.objects for insert to authenticated
  with check (bucket_id = 'vehicle-photos'
              and public.is_yard_member(((storage.foldername(name))[1])::uuid));
drop policy if exists photos_modify on storage.objects;
create policy photos_modify on storage.objects for update to authenticated
  using (bucket_id = 'vehicle-photos'
         and public.is_yard_member(((storage.foldername(name))[1])::uuid));
drop policy if exists photos_remove on storage.objects;
create policy photos_remove on storage.objects for delete to authenticated
  using (bucket_id = 'vehicle-photos'
         and public.is_yard_member(((storage.foldername(name))[1])::uuid));
