import 'package:flutter/material.dart';

/// Design System tokens (v1) to drive colors, spacing, radii, shadows,
/// typography and reusable effects. These are intentionally simple and
/// can be extended when we roll this out across the app.
class DSColor {
  // Brand
  static const Color primary = Color(0xFF7C5CFF); // purple brand
  static const Color primaryDark = Color(0xFF5E3BFF);
  static const Color accent = Color(0xFF6F7DFB);

  // Surfaces (light mode)
  static const Color surface = Colors.white;
  static const Color surfaceSoft = Color(0xFFF7F7FB);
  static const Color surfaceTint = Color(0xFFEDEBFF);

  // Surfaces (dark mode)
  static const Color surfaceDark = Color(0xFF1F2937);
  static const Color surfaceSoftDark = Color(0xFF111827);
  static const Color surfaceTintDark = Color(0xFF374151);

  // Content (light mode)
  static const Color heading = Color(0xFF1E2340);
  static const Color body = Color(0xFF4A4E69);
  static const Color muted = Color(0xFF8C8FA1);

  // Content (dark mode)
  static const Color headingDark = Colors.white;
  static const Color bodyDark = Color(0xFFD1D5DB);
  static const Color mutedDark = Color(0xFF9CA3AF);

  // Helper methods to get colors based on brightness
  static Color getSurface(Brightness brightness) {
    return brightness == Brightness.dark ? surfaceDark : surface;
  }

  static Color getSurfaceSoft(Brightness brightness) {
    return brightness == Brightness.dark ? surfaceSoftDark : surfaceSoft;
  }

  static Color getSurfaceTint(Brightness brightness) {
    return brightness == Brightness.dark ? surfaceTintDark : surfaceTint;
  }

  static Color getHeading(Brightness brightness) {
    return brightness == Brightness.dark ? headingDark : heading;
  }

  static Color getBody(Brightness brightness) {
    return brightness == Brightness.dark ? bodyDark : body;
  }

  static Color getMuted(Brightness brightness) {
    return brightness == Brightness.dark ? mutedDark : muted;
  }

  // Status
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF6366F1);
  static const Color danger = Color(0xFFEF4444);

  // Pills/Badges backgrounds
  static const Color pillBg = Color(0xFFEDEBFF);
  static const Color pillSelected = primary;

  // Gradient used in the screenshot background (light mode)
  static const List<Color> backdropGradient = [
    Color(0xFFC8F1FF),
    Color(0xFFF5D9FF),
    Color(0xFFFFF3D6),
  ];

  // Gradient for dark mode background (nuanced dark gradient)
  static const List<Color> backdropGradientDark = [
    Color(0xFF1A1F3A),
    Color(0xFF2D1B3A),
    Color(0xFF3A2B1F),
  ];

  // Helper method to get backdrop gradient based on brightness
  static List<Color> getBackdropGradient(Brightness brightness) {
    return brightness == Brightness.dark ? backdropGradientDark : backdropGradient;
  }
}

class DSSpacing {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
}

class DSRadius {
  static const BorderRadius soft = BorderRadius.all(Radius.circular(14));
  static const BorderRadius round = BorderRadius.all(Radius.circular(20));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(100));
}

class DSShadow {
  static List<BoxShadow> card = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> floating(Color color) => [
        BoxShadow(
          color: color.withOpacity(0.3),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];
}

class DSTypo {
  // Base styles without color (for use with copyWith)
  static const TextStyle _baseTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  static const TextStyle _baseH1 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
  );

  static const TextStyle _baseH2 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle _baseBody = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle _baseCaption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  // Legacy static styles (for backward compatibility, but will use light colors)
  static TextStyle get title => _baseTitle.copyWith(color: DSColor.heading);
  static TextStyle get h1 => _baseH1.copyWith(color: DSColor.heading);
  static TextStyle get h2 => _baseH2.copyWith(color: DSColor.heading);
  static TextStyle get body => _baseBody.copyWith(color: DSColor.body);
  static TextStyle get caption => _baseCaption.copyWith(color: DSColor.muted);

  // Theme-aware methods (using Brightness)
  static TextStyle titleTheme(Brightness brightness) {
    return _baseTitle.copyWith(color: DSColor.getHeading(brightness));
  }

  static TextStyle h1Theme(Brightness brightness) {
    return _baseH1.copyWith(color: DSColor.getHeading(brightness));
  }

  static TextStyle h2Theme(Brightness brightness) {
    return _baseH2.copyWith(color: DSColor.getHeading(brightness));
  }

  static TextStyle bodyTheme(Brightness brightness) {
    return _baseBody.copyWith(color: DSColor.getBody(brightness));
  }

  static TextStyle captionTheme(Brightness brightness) {
    return _baseCaption.copyWith(color: DSColor.getMuted(brightness));
  }

  // Theme-aware methods (using BuildContext - more convenient)
  static TextStyle titleOf(BuildContext context) {
    return titleTheme(Theme.of(context).brightness);
  }

  static TextStyle h1Of(BuildContext context) {
    return h1Theme(Theme.of(context).brightness);
  }

  static TextStyle h2Of(BuildContext context) {
    return h2Theme(Theme.of(context).brightness);
  }

  static TextStyle bodyOf(BuildContext context) {
    return bodyTheme(Theme.of(context).brightness);
  }

  static TextStyle captionOf(BuildContext context) {
    return captionTheme(Theme.of(context).brightness);
  }
}

