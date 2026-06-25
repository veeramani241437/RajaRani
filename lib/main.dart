import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/supabase_service.dart';
import 'screens/setup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase Service
  await SupabaseService.initialize();
  
  runApp(const RajaRaniApp());
}

class RajaRaniApp extends StatelessWidget {
  const RajaRaniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'Raja Rani',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: const Color(0xFF3C2415),
            scaffoldBackgroundColor: const Color(0xFFFAF6EE),
            textTheme: GoogleFonts.outfitTextTheme(
              ThemeData.dark().textTheme,
            ),
          ),
          // Apply a global text scaler clamp to eliminate text scale-driven crashes/overflows
          builder: (context, child) {
            final data = MediaQuery.of(context);
            return MediaQuery(
              data: data.copyWith(
                textScaler: data.textScaler.clamp(
                  minScaleFactor: 0.8,
                  maxScaleFactor: 1.2,
                ),
              ),
              child: child!,
            );
          },
          home: const SetupScreen(),
        );
      },
    );
  }
}
