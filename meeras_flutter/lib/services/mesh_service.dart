import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/mesh_envelope.dart';

class NearbyMeshService extends ChangeNotifier {
  static const _serviceId = 'org.meeras.app';
  static const _strategy = Strategy.P2P_CLUSTER;
  static const _maxHops = 6;

  final String deviceId;
  final _connectedEndpoints = <String>{};

  late Box<Map> _outboxBox;
  late Box<int> _seenBox;
  static const _seenTtl = Duration(days: 3);

  final List<MeshEnvelope> receivedLog = [];

  NearbyMeshService({required this.deviceId});

  int get connectedPeerCount => _connectedEndpoints.length;
  int get pendingOutboxCount => _outboxBox.length;

  Future<void> init() async {
    await Hive.initFlutter();
    _outboxBox = await Hive.openBox<Map>('mesh_outbox');
    _seenBox = await Hive.openBox<int>('mesh_seen');
    _pruneSeen();

    await Nearby().startAdvertising(
      deviceId,
      _strategy,
      serviceId: _serviceId,
      onConnectionInitiated: _onConnectionInitiated,
      onConnectionResult: (id, status) {
        if (status == Status.CONNECTED) _connectedEndpoints.add(id);
        notifyListeners();
      },
      onDisconnected: (id) {
        _connectedEndpoints.remove(id);
        notifyListeners();
      },
    );

    await Nearby().startDiscovery(
      deviceId,
      _strategy,
      serviceId: _serviceId,
      onEndpointFound: (id, name, serviceId) {
        Nearby().requestConnection(
          deviceId,
          id,
          onConnectionInitiated: _onConnectionInitiated,
          onConnectionResult: (id, status) {
            if (status == Status.CONNECTED) _connectedEndpoints.add(id);
            notifyListeners();
          },
          onDisconnected: (id) {
            _connectedEndpoints.remove(id);
            notifyListeners();
          },
        );
      },
      onEndpointLost: (id) {},
    );
  }

  void _onConnectionInitiated(String id, ConnectionInfo info) {
    Nearby().acceptConnection(
      id,
      onPayLoadRecieved: (endpointId, payload) {
        if (payload.type == PayloadType.BYTES && payload.bytes != null) {
          _handleIncoming(payload.bytes!, fromEndpoint: endpointId);
        }
      },
      onPayloadTransferUpdate: (endpointId, update) {},
    );
  }

  Future<void> stop() async {
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    await Nearby().stopAllEndpoints();
  }

  Future<void> createAndBroadcast({
    required RecordType type,
    required Map<String, dynamic> payload,
  }) async {
    final envelope = MeshEnvelope(
      uuid: const Uuid().v4(),
      recordType: type,
      payload: payload,
      originDeviceId: deviceId,
      createdOfflineAt: DateTime.now().toUtc(),
    );
    _markSeen(envelope.uuid);
    await _saveToOutbox(envelope);
    _floodToAll(envelope, excludeEndpoint: null);
    notifyListeners();
  }

  void _handleIncoming(Uint8List bytes, {required String fromEndpoint}) {
    final envelope = MeshEnvelope.fromBytes(bytes);
    if (_alreadySeen(envelope.uuid)) return;
    _markSeen(envelope.uuid);
    envelope.relayHops += 1;
    _saveToOutbox(envelope);
    receivedLog.insert(0, envelope);
    notifyListeners();

    if (envelope.relayHops < _maxHops) {
      _floodToAll(envelope, excludeEndpoint: fromEndpoint);
    }
  }

  void _floodToAll(MeshEnvelope envelope, {required String? excludeEndpoint}) {
    final bytes = envelope.toBytes();
    for (final endpointId in _connectedEndpoints) {
      if (endpointId == excludeEndpoint) continue;
      Nearby().sendBytesPayload(endpointId, bytes);
    }
  }

  Future<void> _saveToOutbox(MeshEnvelope e) => _outboxBox.put(e.uuid, e.toJson());

  List<MeshEnvelope> get pendingSync =>
      _outboxBox.values.map((m) => MeshEnvelope.fromJson(Map<String, dynamic>.from(m))).toList();

  Future<void> clearFromOutbox(Iterable<String> uuids) async {
    for (final id in uuids) {
      await _outboxBox.delete(id);
    }
    notifyListeners();
  }

  bool _alreadySeen(String uuid) => _seenBox.containsKey(uuid);
  void _markSeen(String uuid) => _seenBox.put(uuid, DateTime.now().millisecondsSinceEpoch);
  void _pruneSeen() {
    final cutoff = DateTime.now().subtract(_seenTtl).millisecondsSinceEpoch;
    final stale = _seenBox.keys.where((k) => (_seenBox.get(k) ?? 0) < cutoff).toList();
    for (final k in stale) {
      _seenBox.delete(k);
    }
  }
}