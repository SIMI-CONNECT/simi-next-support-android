// Simi Next Support — branded home page.
//
// PURPOSE
// -------
// Replace upstream RustDesk's mobile home page (which centers on a
// "Connect to remote ID" text field — i.e. outbound control) with a
// surface that ONLY supports being controlled. The technician on the
// other end runs RustDesk-proper or our web console; this device
// just displays its ID + password and waits.
//
// WIRING (operator finishes — see patches/0010-...)
// -----
// In upstream `flutter/lib/mobile/pages/home_page.dart` (verify path
// against PINNED_TAG), replace the body of the connect tab / home
// scaffold with `SimiSupportHomePage()`. The patch under
// `patches/0010-home-page-replace-outbound-ui.patch` is a TEMPLATE
// describing the change in prose.

import 'package:flutter/material.dart';
import 'branding.dart';

class SimiSupportHomePage extends StatefulWidget {
  const SimiSupportHomePage({super.key});

  @override
  State<SimiSupportHomePage> createState() => _SimiSupportHomePageState();
}

class _SimiSupportHomePageState extends State<SimiSupportHomePage> {
  bool _passwordRevealed = false;

  // ---- Upstream API bridges ---------------------------------------
  // TODO(verify): the upstream RustDesk Flutter codebase exposes the
  // device's RustDesk ID via something like
  // `gFFI.serverModel.serverId` (a ValueNotifier<String>) or via
  // `bind.mainGetMyId()` (a sync FFI call). The exact call site
  // lives in `flutter/lib/models/server_model.dart` at PINNED_TAG.
  // Confirm before wiring; the placeholder below returns a literal.
  String _readSupportId() {
    // return gFFI.serverModel.serverId.value;
    return '---------';
  }

  // TODO(verify): unattended password is exposed via upstream's
  // `bind.mainGetPermanentPassword()` or
  // `gFFI.serverModel.verificationMethod`/`serverPasswd` — verify
  // against `flutter/lib/models/server_model.dart`.
  String _readSupportPassword() {
    // return bind.mainGetPermanentPassword();
    return '••••••••';
  }

  // TODO(verify): inbound-session indicator. Upstream tracks active
  // clients in `gFFI.serverModel.clients` (List<Client>). When
  // non-empty, a tech is connected.
  bool _isTechConnected() {
    // return gFFI.serverModel.clients.isNotEmpty;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: SimiBranding.brandSurface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(),
              const SizedBox(height: 24),
              if (_isTechConnected()) const _TechConnectingBanner(),
              const SizedBox(height: 16),
              _IdCard(supportId: _readSupportId()),
              const SizedBox(height: 16),
              _PasswordCard(
                password: _readSupportPassword(),
                revealed: _passwordRevealed,
                onToggle: () => setState(() {
                  _passwordRevealed = !_passwordRevealed;
                }),
              ),
              const Spacer(),
              _Footer(theme: theme),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(SimiBranding.logoAsset, width: 48, height: 48),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(SimiBranding.appName,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
            Text(SimiBranding.tagline,
                style: TextStyle(fontSize: 13, color: Colors.black54)),
          ],
        ),
      ],
    );
  }
}

class _TechConnectingBanner extends StatelessWidget {
  const _TechConnectingBanner();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SimiBranding.brandPrimary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(children: [
        Icon(Icons.link, color: SimiBranding.brandPrimary),
        SizedBox(width: 8),
        Text('Tech is connecting',
            style: TextStyle(color: SimiBranding.brandPrimary)),
      ]),
    );
  }
}

class _IdCard extends StatelessWidget {
  final String supportId;
  const _IdCard({required this.supportId});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your support ID',
                style: TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 4),
            SelectableText(
              supportId,
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordCard extends StatelessWidget {
  final String password;
  final bool revealed;
  final VoidCallback onToggle;
  const _PasswordCard(
      {required this.password,
      required this.revealed,
      required this.onToggle});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Password (rotate via dashboard)',
                  style: TextStyle(fontSize: 13, color: Colors.black54)),
              const SizedBox(height: 4),
              Text(
                revealed ? password : '••••••••',
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2),
              ),
              const SizedBox(height: 4),
              Text(revealed ? 'Tap to hide' : 'Tap to reveal',
                  style: const TextStyle(fontSize: 11, color: Colors.black45)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final ThemeData theme;
  const _Footer({required this.theme});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(SimiBranding.tagline,
            style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 4),
        // TODO(verify): wire to url_launcher (already an upstream dep)
        // to open SimiBranding.supportHelpUrl externally.
        Text('Need help? help.simiconnect.com',
            style: TextStyle(fontSize: 12, color: SimiBranding.brandPrimary)),
      ],
    );
  }
}
