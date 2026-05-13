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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:flutter_hbb/common.dart' show gFFI;
import 'package:flutter_hbb/mobile/pages/home_page.dart' show PageShape;
import 'package:flutter_hbb/mobile/pages/settings_page.dart';
import 'package:flutter_hbb/models/platform_model.dart' show bind;
import 'package:flutter_hbb/models/server_model.dart' show ServerModel;

import 'branding.dart';

// ---- Hidden settings unlock --------------------------------------
// The branded home page deliberately hides upstream RustDesk's
// settings drawer so end users can't change the rendezvous server,
// reset the unattended password, or otherwise drift configuration
// out of the values we baked in at build time. Field technicians
// still need access for diagnostics, so we expose a hidden door:
//
//   Hold D-pad DOWN for >= 3 seconds → PIN dialog → enter `1820`
//                                                  → mobile SettingsPage.
//
// The PIN is NOT a secret — it gates against accidental discovery,
// not against a determined attacker. Any tech in the field knows it.
// Don't rotate this without telling the field-ops team.
const String _kSettingsPin = '1820';
const Duration _kDpadHoldDuration = Duration(seconds: 3);

// Implements upstream's PageShape contract so it can be a member of
// HomePageState._pages alongside ChatPage / SettingsPage. Title + icon
// surface in the bottom-nav scaffold; appBarActions is empty because
// the branded home is deliberately chrome-free (the hidden D-pad
// unlock is the only way out into Settings).
class SimiSupportHomePage extends StatefulWidget
    implements PageShape {
  @override
  final String title = 'Next Support';
  @override
  final Widget icon = const Icon(Icons.support_agent);
  @override
  final List<Widget> appBarActions = const [];

  const SimiSupportHomePage({super.key});

  @override
  State<SimiSupportHomePage> createState() => _SimiSupportHomePageState();
}

class _SimiSupportHomePageState extends State<SimiSupportHomePage> {
  bool _passwordRevealed = false;
  final FocusNode _focusNode = FocusNode(debugLabel: 'simi-support-home');
  Timer? _dpadHoldTimer;
  bool _pinDialogOpen = false;

  // Live values from the RustDesk core. Both are nullable until the
  // FFI roundtrip resolves; we surface a "—" / "••••••••" placeholder
  // until they're in. The polling timer refreshes them every 5s so
  // the screen stays correct after a password rotation or ID reroll.
  String? _supportId;
  String? _supportPassword;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Grab focus on first frame so the Focus widget's onKeyEvent
    // actually fires. Without this the page can't see D-pad input
    // on Android TV / signage devices that don't auto-focus the
    // body Scaffold.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
    _loadSupportCreds();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadSupportCreds(),
    );
  }

  Future<void> _loadSupportCreds() async {
    try {
      final id = await bind.mainGetMyId();
      final pw = await bind.mainGetPermanentPassword();
      if (!mounted) return;
      // Only setState if values actually changed — avoids a needless
      // rebuild every 5s when nothing's moved.
      if (id != _supportId || pw != _supportPassword) {
        setState(() {
          _supportId = id;
          _supportPassword = pw;
        });
      }
    } catch (_) {
      // FFI not ready yet (eg cold-start race). Next tick will retry.
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _dpadHoldTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    // Only D-pad DOWN is our trigger; everything else falls through
    // so the rest of the UI behaves normally.
    if (event.logicalKey != LogicalKeyboardKey.arrowDown) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) {
      // Start the hold timer on first key-down. Key-repeats on
      // Android arrive as KeyRepeatEvent, which we ignore — the
      // timer is the source of truth for "held long enough".
      _dpadHoldTimer ??= Timer(_kDpadHoldDuration, _onDpadHoldComplete);
    } else if (event is KeyUpEvent) {
      // Released before the timer fired → cancel, no dialog.
      _dpadHoldTimer?.cancel();
      _dpadHoldTimer = null;
    }
    // Consume the event so D-pad DOWN doesn't also scroll/focus-move
    // any visible widget while the user is holding the unlock combo.
    return KeyEventResult.handled;
  }

  void _onDpadHoldComplete() {
    _dpadHoldTimer = null;
    if (!mounted || _pinDialogOpen) return;
    _pinDialogOpen = true;
    showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const _PinUnlockDialog(),
    ).then((entered) {
      _pinDialogOpen = false;
      if (!mounted) return;
      if (entered == _kSettingsPin) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const SettingsPage(),
          ),
        );
      } else if (entered != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incorrect PIN')),
        );
      }
      // Reclaim focus once the dialog has closed so subsequent
      // unlock attempts work without the user having to tap.
      _focusNode.requestFocus();
    });
  }

  // ---- Upstream API bridges (wired against pinned RustDesk 1.4.6) -----
  //
  // ID: `bind.mainGetMyId()` is the canonical accessor. It's an FFI
  //     call that returns the 9-digit RustDesk ID the device registered
  //     with at hbbs (help.simiconnect.com). We cache the value into
  //     `_supportId` via the periodic refresh in initState() — calling
  //     the FFI on every build() would needlessly thrash the bridge.
  //
  // Password: `bind.mainGetPermanentPassword()` returns the unattended
  //     password the RustDesk core generates locally on first launch
  //     and persists. Rotating it happens server-side (operator pushes
  //     a `rotate-password` event into hbbs) — the periodic refresh
  //     picks the new value up within 5s of rotation.
  //
  // Tech-connected indicator: `gFFI.serverModel.clients` is a
  //     ChangeNotifier-backed `List<Client>`. The build() method uses
  //     `context.watch<ServerModel>()` to rebuild on connect/disconnect
  //     without us having to manually subscribe.

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Watch the ServerModel so the "Tech is connecting" banner appears
    // and disappears in real time as inbound sessions open/close. We
    // pull the model off gFFI rather than expecting a Provider to be
    // mounted above us — gFFI is the canonical singleton across
    // upstream RustDesk's mobile flow.
    final serverModel = context.watch<ServerModel?>() ?? gFFI.serverModel;
    final techConnected = serverModel.clients.isNotEmpty;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKey,
      autofocus: true,
      child: Scaffold(
        backgroundColor: SimiBranding.brandSurface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(),
                const SizedBox(height: 24),
                if (techConnected) const _TechConnectingBanner(),
                const SizedBox(height: 16),
                _IdCard(supportId: _supportId ?? '—'),
                const SizedBox(height: 16),
                _PasswordCard(
                  password: _supportPassword ?? '••••••••',
                  revealed: _passwordRevealed && _supportPassword != null,
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
      ),
    );
  }
}

// ---- PIN unlock dialog -------------------------------------------
// Plain numeric field with auto-focus + auto-submit on Enter. The
// dialog returns the entered text via `Navigator.pop(value)` so the
// caller can compare against `_kSettingsPin` without leaking the
// expected value into this widget's state.
class _PinUnlockDialog extends StatefulWidget {
  const _PinUnlockDialog();
  @override
  State<_PinUnlockDialog> createState() => _PinUnlockDialogState();
}

class _PinUnlockDialogState extends State<_PinUnlockDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Technician access'),
      content: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: true,
        keyboardType: TextInputType.number,
        obscureText: true,
        maxLength: 8,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          labelText: 'PIN',
          counterText: '',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Unlock'),
        ),
      ],
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
