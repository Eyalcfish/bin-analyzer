import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/executable_provider.dart';
import 'providers/explorer_provider.dart';
import 'providers/lab_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BinAnalyzerApp());
}

class BinAnalyzerApp extends StatelessWidget {
  const BinAnalyzerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ExplorerProvider()),
        ChangeNotifierProvider(create: (_) => ExecutableProvider()),
        ChangeNotifierProvider(create: (_) => LabProvider()),
      ],
      child: MaterialApp(
        title: 'BinAnalyzer - C Assembly & Machine Code Explorer',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF11111B),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF89B4FA),
            secondary: Color(0xFFCBA6F7),
            surface: Color(0xFF1E1E2E),
            surfaceContainerHighest: Color(0xFF313244),
            onPrimary: Color(0xFF11111B),
            onSecondary: Color(0xFF11111B),
            onSurface: Color(0xFFCDD6F4),
          ),
          textTheme: GoogleFonts.interTextTheme(
            ThemeData.dark().textTheme.apply(
              bodyColor: const Color(0xFFCDD6F4),
              displayColor: const Color(0xFFCDD6F4),
            ),
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
