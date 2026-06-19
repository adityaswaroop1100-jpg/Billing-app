import 'package:flutter/material.dart';
import 'screens/billing_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KaveriSweetsBillingApp());
}

class KaveriSweetsBillingApp extends StatelessWidget {
  const KaveriSweetsBillingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kaveri Sweets Billing',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF1B2B4B), // Navy blue (matches bill header)
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B2B4B),
          primary: const Color(0xFF1B2B4B),
          secondary: const Color(0xFFC9973A), // Gold
          surface: const Color(0xFFFBF4E2),   // Cream (matches bill background)
          background: const Color(0xFFF5EDD8),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5EDD8),
        cardTheme: const CardThemeData(
          color: Color(0xFFFBF4E2),
          elevation: 2,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1B2B4B),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'serif',
            color: Colors.white,
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: Colors.transparent,
          selectedColor: const Color(0xFFC9973A).withOpacity(0.2),
          side: const BorderSide(color: Color(0xFFC9973A)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          labelStyle: const TextStyle(color: Color(0xFF1B2B4B), fontWeight: FontWeight.bold),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFFFBF4E2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1B2B4B),
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: const BillingScreen(),
    );
  }
}
