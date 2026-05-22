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
  // Customer-spec for the Next Support first-launch screen
  // (originally promised to the Dromana panel customer):
  //   solid BLACK background, SIMI Next logo + ID/password centred.
  // v0.1.3 shipped with `brandSurface = #FFFFFFFF` (white) which made
  // the screen "look wrong"; this rev flips the home-screen surface to
  // black and pushes text + helper colors to the light side so they
  // remain legible.
  //
  // Brand-blue accents (primary / primaryDark) keep the simi-next-android
  // values for cross-fleet consistency. Canonical brand colour source
  // is the simi-web design-tokens module.
  static const Color brandPrimary = Color(0xFF0F62FE);
  static const Color brandPrimaryDark = Color(0xFF0043CE);
  static const Color brandAccent = Color(0xFF42BE65);
  // Surface = the scaffold background of the branded home page.
  static const Color brandSurface = Color(0xFF000000);
  static const Color brandOnPrimary = Color(0xFFFFFFFF);
  // Foreground tokens for text on the black surface. Kept on this
  // class so the home-page widget tree doesn't have to inline raw
  // ARGB literals every time it wants "primary label" or "muted
  // helper text" against the brand background.
  static const Color brandOnSurface = Color(0xFFFFFFFF);
  static const Color brandOnSurfaceMuted = Color(0xB3FFFFFF); // 70% white
  static const Color brandOnSurfaceFaint = Color(0x80FFFFFF); // 50% white
  // Slightly-lifted card surface so the ID + password panels read as
  // distinct affordances against the pure-black background instead of
  // dissolving into it.
  static const Color brandCardSurface = Color(0xFF1A1A1A);

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
