/// Configurazione passata al build con --dart-define (vedi README).
/// Senza SUPABASE_URL l'app parte in modalità demo.
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Indirizzo del sito pubblico, per i link "condividi" e "vedi sul sito".
  static const siteUrl = String.fromEnvironment('SITE_URL', defaultValue: 'https://charles1812.github.io/sfasciohub/');

  static bool get hasSupabase => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
