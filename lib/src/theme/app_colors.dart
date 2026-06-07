import 'package:flutter/material.dart';

import '../models/reader_models.dart';

class AppColors {
  const AppColors._();

  static const _lightInk = Color(0xFF202124);
  static const _lightSubtle = Color(0xFF666A70);
  static const _lightMuted = Color(0xFF8A8D93);
  static const _lightCanvas = Color(0xFFF4F4F4);
  static const _lightSurface = Color(0xFFFBFBFA);
  static const _lightPanel = Color(0xFFEFEFEF);
  static const _lightRail = Color(0xFFE8E8E8);
  static const _lightLine = Color(0xFFDADCE0);
  static const _lightToolbarItem = Color(0xFFF0F0F0);
  static const _lightAccent = Color(0xFFE94C5F);
  static const _lightAccentSoft = Color(0xFFFFE8EC);
  static const _lightAccentLine = Color(0xFFF2B7C0);
  static const _lightNote = Color(0xFFFFF3B8);
  static const _lightHighlight = Color(0x66FFE066);
  static const _lightSelection = Color(0x558CB8FF);
  static const noteGlyphStroke = _lightInk;
  static const noteFoldSurface = _lightSurface;

  static const _darkInk = Color(0xFFF2F2F2);
  static const _darkSubtle = Color(0xFFC6C6C6);
  static const _darkMuted = Color(0xFF9A9A9A);
  static const _darkCanvas = Color(0xFF202020);
  static const _darkSurface = Color(0xFF242424);
  static const _darkPanel = Color(0xFF2B2B2B);
  static const _darkRail = Color(0xFF242424);
  static const _darkLine = Color(0xFF3A3A3A);
  static const _darkToolbarItem = Color(0xFF303030);
  static const _darkAccent = Color(0xFFFF6375);
  static const _darkAccentSoft = Color(0xFF3B2027);
  static const _darkAccentLine = Color(0xFF8B4652);
  static const _darkNote = Color(0xFF3A3320);
  static const _darkHighlight = Color(0x66FFE066);
  static const _darkSelection = Color(0x664C87D8);

  static const highlightPalette = <Color>[
    Color(0x66FFE45C),
    Color(0x66FFA640),
    Color(0x66FF6F61),
    Color(0x66E35BA6),
    Color(0x66A06CFF),
    Color(0x66647BFF),
    Color(0x664DB7FF),
    Color(0x6639C6C6),
    Color(0x6657C978),
    Color(0x668F98A3),
  ];

  static Color ink = _lightInk;
  static Color subtle = _lightSubtle;
  static Color muted = _lightMuted;
  static Color canvas = _lightCanvas;
  static Color nightCanvas = _darkCanvas;
  static Color surface = _lightSurface;
  static Color panel = _lightPanel;
  static Color rail = _lightRail;
  static Color line = _lightLine;
  static Color toolbarItem = _lightToolbarItem;
  static Color accent = _lightAccent;
  static Color accentSoft = _lightAccentSoft;
  static Color accentLine = _lightAccentLine;
  static Color note = _lightNote;
  static Color highlight = _lightHighlight;
  static Color selection = _lightSelection;
  static Color pageSeparator = _lightCanvas;
  static Color danger = const Color(0xFFE5484D);
  static bool isNightMode = false;

  static void setNightMode(bool enabled) {
    setTheme(nightMode: enabled);
  }

  static void setTheme({
    required bool nightMode,
    ReaderAccent accentChoice = ReaderAccent.rose,
  }) {
    final accents = _accentTokens(accentChoice, nightMode);
    isNightMode = nightMode;
    ink = nightMode ? _darkInk : _lightInk;
    subtle = nightMode ? _darkSubtle : _lightSubtle;
    muted = nightMode ? _darkMuted : _lightMuted;
    canvas = nightMode ? _darkCanvas : _lightCanvas;
    surface = nightMode ? _darkSurface : _lightSurface;
    panel = nightMode ? _darkPanel : _lightPanel;
    rail = nightMode ? _darkRail : _lightRail;
    line = nightMode ? _darkLine : _lightLine;
    toolbarItem = nightMode ? _darkToolbarItem : _lightToolbarItem;
    accent = accents.$1;
    accentSoft = accents.$2;
    accentLine = accents.$3;
    note = nightMode ? _darkNote : _lightNote;
    highlight = nightMode ? _darkHighlight : _lightHighlight;
    selection = nightMode ? _darkSelection : _lightSelection;
    pageSeparator = canvas;
    danger = nightMode ? const Color(0xFFFF6B6B) : const Color(0xFFE5484D);
  }

  static (Color, Color, Color) _accentTokens(
    ReaderAccent accentChoice,
    bool nightMode,
  ) {
    return switch ((accentChoice, nightMode)) {
      (ReaderAccent.rose, false) => (
        _lightAccent,
        _lightAccentSoft,
        _lightAccentLine,
      ),
      (ReaderAccent.rose, true) => (
        _darkAccent,
        _darkAccentSoft,
        _darkAccentLine,
      ),
      (ReaderAccent.purple, false) => (
        Color(0xFF7367F0),
        Color(0xFFEDEBFF),
        Color(0xFFB8B0FF),
      ),
      (ReaderAccent.purple, true) => (
        Color(0xFF8D84FF),
        Color(0xFF2E2B52),
        Color(0xFF625AC8),
      ),
      (ReaderAccent.green, false) => (
        Color(0xFF31B37A),
        Color(0xFFE3F7EE),
        Color(0xFF8BD8B5),
      ),
      (ReaderAccent.green, true) => (
        Color(0xFF4FD39A),
        Color(0xFF1D3D31),
        Color(0xFF39966D),
      ),
    };
  }
}
