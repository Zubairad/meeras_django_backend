import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/help_requests_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/admin_moderation_screen.dart';
import 'screens/mesh_status_screen.dart';
import 'theme/meeras_theme.dart';
import 'widgets/main_scaffold.dart';
import 'services/mesh_service.dart';
import 'services/mesh_permissions.dart';
import 'screens/new_help_request_screen.dart';

Future<String> _loadOrCreateDeviceId() async {
  final box = await Hive.openBox('device');
  var id = box.get('id') as String?;
  if (id == null) {
    id = const Uuid().v4();
    await box.put('id', id);
  }
  return id;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final deviceId = await _loadOrCreateDeviceId();
  final meshService = NearbyMeshService(deviceId: deviceId);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider<NearbyMeshService>.value(value: meshService),
      ],
      child: const MeerasApp(),
    ),
  );
}

class MeerasApp extends StatelessWidget {
  const MeerasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meeras',
      debugShowCheckedModeBanner: false,
      theme: MeerasTheme.dark,
      home: const _AuthGate(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/home': (_) => const MainScaffold(),
        '/help-requests': (_) => const HelpRequestsScreen(),
        '/inventory': (_) => const InventoryScreen(),
        '/admin/moderation': (_) => const AdminModerationScreen(),
        '/mesh-status': (_) => const MeshStatusScreen(),
        '/help-requests/new': (_) => const NewHelpRequestScreen(),
      },
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();
  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final auth = context.read<AuthProvider>();
    try {
      await auth.fetchMe();
    } catch (_) {}
    if (mounted) {
      setState(() => _checked = true);
      if (auth.isLoggedIn) {
        Navigator.pushReplacementNamed(context, '/home');
        _startMeshInBackground();
      }
    }
  }

  void _startMeshInBackground() {
    final mesh = context.read<NearbyMeshService>();
    ensureMeshPermissions().then((granted) {
      if (granted) {
        mesh.init();
      } else {
        debugPrint('Mesh permissions denied — offline sync will not work.');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const Scaffold(
        backgroundColor: MeerasTheme.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.volunteer_activism,
                  color: MeerasTheme.accent, size: 48),
              SizedBox(height: 16),
              CircularProgressIndicator(
                  color: MeerasTheme.accent, strokeWidth: 2),
            ],
          ),
        ),
      );
    }
    return const LoginScreen();
  }
}