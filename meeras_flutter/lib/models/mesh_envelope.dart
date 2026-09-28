import 'dart:convert';
import 'dart:typed_data';

enum RecordType { helpRequest, broadcast, chatMessage }

class MeshEnvelope {
  final String uuid;
  final RecordType recordType;
  final Map<String, dynamic> payload;
  final String originDeviceId;
  final DateTime createdOfflineAt;
  int relayHops;

  MeshEnvelope({
    required this.uuid,
    required this.recordType,
    required this.payload,
    required this.originDeviceId,
    required this.createdOfflineAt,
    this.relayHops = 0,
  });

  Map<String, dynamic> toJson() => {
    'uuid': uuid,
    'record_type': recordType.name,
    'payload': payload,
    'origin_device_id': originDeviceId,
    'created_offline_at': createdOfflineAt.toIso8601String(),
    'relay_hops': relayHops,
  };

  factory MeshEnvelope.fromJson(Map<String, dynamic> json) => MeshEnvelope(
    uuid: json['uuid'],
    recordType: RecordType.values.byName(json['record_type']),
    payload: Map<String, dynamic>.from(json['payload']),
    originDeviceId: json['origin_device_id'],
    createdOfflineAt: DateTime.parse(json['created_offline_at']),
    relayHops: json['relay_hops'] ?? 0,
  );

  Uint8List toBytes() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));
  static MeshEnvelope fromBytes(Uint8List bytes) =>
      MeshEnvelope.fromJson(jsonDecode(utf8.decode(bytes)));
}