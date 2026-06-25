import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class GameTheme {
  // Board Game Color Palette
  static const Color woodDark = Color(0xFF1E0D05);
  static const Color woodMedium = Color(0xFF3B1E0E);
  static const Color woodLight = Color(0xFF63402C);
  
  static const Color parchmentBgColor = Color(0xFF9E7245); // Deeper warm golden-brown oak background
  static const Color parchmentCardColor = Color(0xFFE2C49C); // Deeper warm golden cream panels
  
  static const Color goldAccent = Color(0xFFC98E16); // Deeper rich polished gold
  static const Color orangeAccent = Color(0xFFB84500); // Deeper rust orange
  static const Color greenAccent = Color(0xFF256629); // Deeper forest green
  static const Color blueAccent = Color(0xFF0F529C); // Deeper royal blue
  static const Color redAccent = Color(0xFFA51B1B); // Deeper crimson red

  // Asset Strings
  static const String parchmentBg = 'assets/parchment_bg.png';
  static const String kingAvatar = 'assets/avatar_king.png';
  static const String queenAvatar = 'assets/avatar_queen.png';
  static const String policeAvatar = 'assets/avatar_police.png';
  static const String thiefAvatar = 'assets/avatar_thief.png';
  static const String princeAvatar = 'assets/avatar_prince.png';
  static const String commanderAvatar = 'assets/avatar_commander.png';
  static const String ministerAvatar = 'assets/avatar_minister.png';
  static const String soldierAvatar = 'assets/avatar_soldier.png';
  static const String merchantAvatar = 'assets/avatar_citizen.png';
  static const String citizenAvatar = 'assets/avatar_citizen.png';
  static const String mysteryAvatar = 'assets/avatar_mystery.png';

  // Screen background decoration (Parchment texture fit)
  static const BoxDecoration backgroundDecoration = BoxDecoration(
    image: DecorationImage(
      image: AssetImage(parchmentBg),
      fit: BoxFit.cover,
    ),
  );

  // Wooden Framed Board Container Decoration
  static BoxDecoration boardDecoration({
    double borderRadius = 16.0,
    Color bgCol = parchmentCardColor,
    Color borderCol = woodDark,
    double borderWidth = 2.5,
  }) {
    return BoxDecoration(
      color: bgCol,
      borderRadius: BorderRadius.circular(borderRadius.r),
      border: Border.all(color: borderCol, width: borderWidth.w),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.15),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // 2D Comic Style Button Decoration (Wooden outline + Solid color)
  static BoxDecoration buttonDecoration({
    Color color = orangeAccent,
    double borderRadius = 12.0,
    double shadowOffset = 4.0,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(borderRadius.r),
      border: Border.all(color: woodDark, width: 2.5.w),
      boxShadow: [
        if (shadowOffset > 0)
          BoxShadow(
            color: woodDark.withOpacity(0.4),
            blurRadius: 0,
            offset: Offset(0, shadowOffset.h),
          ),
      ],
    );
  }

  // Custom typography style
  static TextStyle headerStyle({
    required double fontSize,
    Color color = woodDark,
    bool isBold = true,
  }) {
    return GoogleFonts.outfit(
      fontSize: fontSize.sp,
      fontWeight: isBold ? FontWeight.w900 : FontWeight.w800,
      color: color,
    );
  }

  static TextStyle bodyStyle({
    required double fontSize,
    Color color = woodDark,
    FontWeight weight = FontWeight.w700,
  }) {
    return GoogleFonts.outfit(
      fontSize: fontSize.sp,
      fontWeight: weight,
      color: color,
    );
  }
}
