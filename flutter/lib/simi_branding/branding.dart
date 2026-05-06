// Simi Next Support — branding constants.
//
// This module is rsync'd into upstream RustDesk's flutter/lib/ tree
// by bootstrap-fork.sh. Upstream code that needs to reference brand
// strings or colors should `import 'package:flutter_hbb/simi_branding/branding.dart';`
// (TODO(verify): confirm upstream's pubspec.yaml `name:` is
// `flutter_hbb` at PINNED_TAG — RustDesk has used that name
// historically but verify before relying on it).

import 'package:flutter/material.dart';

class SimiBranding {
  SimiBranding._();

  // ---- Identity --------------------------------------------------------
  static const String appName = 'Next Support';
  static const String tagline = 'Simi technician support';

  // ---- External URLs ---------------------------------------------------
  static const String supportPortalUrl =
      'https://help.simiconnect.com/dashboard';
  static const String supportHelpUrl = 'https://help.simiconnect.com';

  // ---- Asset paths -----------------------------------------------------
  // See flutter/assets/logo/README.md for the operator drop-in spec.
  static const String logoAsset = 'assets/logo/simi-next-support.png';

  // ---- Colors ----------------------------------------------------------
  // TODO(verify): values mirror simi-next-android colors.xml
  // (simi_primary = #FF0F62FE) as of 2026-05-06. Brand owner sign-off
  // pending before 1.0. Canonical source: simi-web design tokens.
  static const Color brandPrimary = Color(0xFF0F62FE);
  static const Color brandPrimaryDark = Color(0xFF0043CE);
  static const Color brandAccent = Color(0xFF42BE65);
  static const Color brandSurface = Color(0xFFFFFFFF);
  static const Color brandOnPrimary = Color(0xFFFFFFFF);

  // Legacy alias used by other Simi apps; kept for cross-fleet
  // consistency even though Next Support is blue-primary.
  static const Color brandOrange = Color(0xFFFF6F00);

  // ---- Feature flags ---------------------------------------------------
  // Next Support devices are *controlled*, never controllers.
  // Outbound-control surfaces must be hidden.
  static const bool enableOutboundControl = false;

  // We push updates via our own OTA channel — disable upstream's
  // GitHub-release update check.
  static const bool enableUpstreamUpdateCheck = false;

  // Settings sub-pages we keep:
  static const bool showLanguageSettings = true;
  static const bool showThemeSettings = true;
  static const bool showAudioToggle = true;
  static const bool showFileTransferToggle = true;

  // Settings sub-pages we hide:
  static const bool showAddressBook = false;
  static const bool showIdServerEntry = false; // baked at build time
  static const bool showRelayServerEntry = false; // baked at build time
  static const bool showRecentSessions = false;
}
