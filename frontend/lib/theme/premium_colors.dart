import 'package:flutter/material.dart';

// Premium Dark Theme Palette
const Color kPremiumBg = Color(0xFF070709);         // Very deep off-black
const Color kPremiumSidebar = Color(0xFF0C0C0E);    // Slightly lighter for depth
const Color kPremiumCard = Color(0xFF121215);       // Elevated element background
const Color kPremiumBorder = Color(0xFF222226);     // Subtle borders

const Color kPremiumAccent = Color(0xFFFACC15);     // Rich vivid yellow (amber)
const Color kPremiumText = Color(0xFFFFFFFF);
const Color kPremiumTextMuted = Color(0xFF8E8E93);  // Sleek gray

// Gradient matching the "ETHAN CROSS" banner
const LinearGradient kHeroPremiumGradient = LinearGradient(
  colors: [Color(0xFFFFDF73), Color(0xFFFF8A5C), Color(0xFFE54A4A)],
  stops: [0.0, 0.5, 1.0],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// Glowing shadows for premium elements
BoxShadow kPremiumGlow(Color color) => BoxShadow(
  color: color.withOpacity(0.25),
  blurRadius: 24,
  spreadRadius: 2,
  offset: const Offset(0, 8),
);
