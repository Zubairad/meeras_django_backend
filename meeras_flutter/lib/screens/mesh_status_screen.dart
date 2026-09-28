import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/mesh_service.dart';
import '../theme/meeras_theme.dart';

class MeshStatusScreen extends StatelessWidget {
  const MeshStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mesh = context.watch<NearbyMeshService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Offline Mesh Status')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              _statTile('Connected peers', '${mesh.connectedPeerCount}'),
              const SizedBox(width: 12),
              _statTile('Pending sync', '${mesh.pendingOutboxCount}'),
            ],
          ),
          const SizedBox(height: 24),
          Text('Received over mesh', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (mesh.receivedLog.isEmpty)
            const Text('Nothing received yet.', style: TextStyle(color: MeerasTheme.textMuted))
          else
            ...mesh.receivedLog.map((e) => Card(
              color: MeerasTheme.surface,
              child: ListTile(
                title: Text(e.payload['title']?.toString() ?? e.recordType.name),
                subtitle: Text('${e.relayHops} hop(s) • from ${e.originDeviceId}'),
              ),
            )),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: MeerasTheme.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: MeerasTheme.accent)),
        Text(label, style: const TextStyle(color: MeerasTheme.textMuted, fontSize: 12)),
      ]),
    ),
  );
}