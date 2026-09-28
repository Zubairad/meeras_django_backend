import 'package:permission_handler/permission_handler.dart';
import 'package:location/location.dart';

Future<bool> ensureMeshPermissions() async {
  final statuses = await [
    Permission.bluetooth,
    Permission.bluetoothAdvertise,
    Permission.bluetoothConnect,
    Permission.bluetoothScan,
    Permission.location,
    Permission.nearbyWifiDevices,
  ].request();

  final allGranted = statuses.values.every((s) => s.isGranted);
  if (!allGranted) return false;

  final locationEnabled = await Location.instance.requestService();
  return locationEnabled;
}