import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'providers/analysis_provider.dart';
import 'utils/theme.dart';
import 'screens/upload_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive local cache database
  await Hive.initFlutter();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AnalysisProvider()),
      ],
      child: const HepBAnalyzerApp(),
    ),
  );
}

class HepBAnalyzerApp extends StatefulWidget {
  const HepBAnalyzerApp({super.key});

  @override
  State<HepBAnalyzerApp> createState() => _HepBAnalyzerAppState();
}

class _HepBAnalyzerAppState extends State<HepBAnalyzerApp> {
  ThemeMode _themeMode = ThemeMode.dark; // Default to dark mode for premium feel

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hepatitis B Data Analyzer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: AppShell(
        toggleTheme: _toggleTheme,
        themeMode: _themeMode,
      ),
    );
  }
}

class AppShell extends StatelessWidget {
  final VoidCallback toggleTheme;
  final ThemeMode themeMode;

  const AppShell({
    super.key,
    required this.toggleTheme,
    required this.themeMode,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnalysisProvider>();

    if (provider.isLoading && provider.parseProgress == 0.0) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Dynamic routing based on patient cache presence
    if (provider.allPatients.isEmpty) {
      return UploadScreen(
        toggleTheme: toggleTheme,
        themeMode: themeMode,
      );
    } else {
      return DashboardScreen(
        toggleTheme: toggleTheme,
        themeMode: themeMode,
      );
    }
  }
}
