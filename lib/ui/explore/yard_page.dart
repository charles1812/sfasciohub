import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'explore_app.dart';

class YardPage extends StatefulWidget {
  const YardPage({super.key, required this.id});
  final String id;
  @override
  State<YardPage> createState() => _YardPageState();
}

class _YardPageState extends State<YardPage> {
  late final Future<Yard?> _yard = Repository.instance.yard(widget.id);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _yard,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
        }
        final y = snap.data;
        if (y == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Sfasciacarrozze non trovato.')));
        final t = Theme.of(context).textTheme;
        return Scaffold(
          appBar: AppBar(title: Text(y.name)),
          body: NestedScrollView(
            headerSliverBuilder: (_, _) => [
              SliverToBoxAdapter(
                child: Container(
                  color: Brand.asphaltSoft,
                  child: Constrained(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(y.name, style: t.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text([y.address, y.place].where((s) => s.isNotEmpty).join(', '), style: const TextStyle(color: Colors.white70)),
                        if (y.hours.isNotEmpty) Text(y.hours, style: const TextStyle(color: Colors.white54, fontSize: 12.5)),
                        if (y.description.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(y.description, style: const TextStyle(color: Colors.white)),
                        ],
                        const SizedBox(height: 14),
                        Theme(data: Theme.of(context).copyWith(brightness: Brightness.dark), child: ContactButtons(yard: y)),
                      ]),
                    ),
                  ),
                ),
              ),
            ],
            body: SearchTab(yardId: y.id),
          ),
        );
      },
    );
  }
}
