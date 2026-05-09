// Simi Next Support — signage home page.
//
// Black-background, single-screen, DPAD-tunable surface for signage TVs.
//
// Layout (top to bottom):
//   - SIMI Next logo
//   - Status badge (Ready / Connecting / Not ready / Tech connected)
//   - Support ID (very large, white)
//   - Password (very large, white, monospace)
//   - "Give this code to your Simi Engineer"
//
// The AccessibilityService auto-grants screen capture and home_page
// auto-fires the foreground service, so by the time the operator
// sees this surface it's already serving — they just read the values
// to the engineer.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../common.dart';
import '../models/platform_model.dart';
import '../models/server_model.dart';

const Color _kBg = Color(0xFF000000);
const Color _kFg = Color(0xFFFFFFFF);
const Color _kFgDim = Color(0xFFB0B0B0);
const Color _kFgFaint = Color(0xFF8D8D8D);

class SignageHomePage extends StatefulWidget {
  const SignageHomePage({Key? key}) : super(key: key);

  @override
  State<SignageHomePage> createState() => _SignageHomePageState();
}

class _SignageHomePageState extends State<SignageHomePage> {
  String _permanentPwd = '';
  Timer? _pwdTimer;

  @override
  void initState() {
    super.initState();
    _refreshPermanentPwd();
    _pwdTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _refreshPermanentPwd();
    });
  }

  @override
  void dispose() {
    _pwdTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshPermanentPwd() async {
    final p = (await bind.mainGetPermanentPassword()).trim();
    if (p != _permanentPwd && mounted) {
      setState(() => _permanentPwd = p);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: gFFI.serverModel,
      child: Consumer<ServerModel>(
        builder: (context, serverModel, _) => _Body(
          serverModel: serverModel,
          permanentPwd: _permanentPwd,
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.serverModel, required this.permanentPwd});
  final ServerModel serverModel;
  final String permanentPwd;

  @override
  Widget build(BuildContext context) {
    final hasClient = serverModel.clients.isNotEmpty;
    final id = serverModel.serverId.value.text.trim();
    // When verification-method == use-permanent-password (which we
    // pin in HomePageState.initState for the auto-pair flow),
    // serverModel.serverPasswd.text becomes "-". Show the actual
    // permanent password instead — that's what the engineer needs.
    final pwd = permanentPwd.isNotEmpty
        ? permanentPwd
        : (serverModel.verificationMethod != kUsePermanentPassword
            ? serverModel.serverPasswd.value.text
            : '••••••');
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: _kBg,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top: logo + status badge.
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Column(
                children: [
                  const _Logo(),
                  const SizedBox(height: 16),
                  _StatusBadge(serverModel: serverModel, hasClient: hasClient),
                ],
              ),
            ),
            // Middle: ID + password, centered.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _Label('Support ID'),
                    const SizedBox(height: 12),
                    _BigValue(value: id.isEmpty ? '—' : id),
                    const SizedBox(height: 48),
                    const _Label('Password'),
                    const SizedBox(height: 12),
                    _BigValue(value: pwd, monospace: true),
                  ],
                ),
              ),
            ),
            // Bottom: footnote.
            const Padding(
              padding: EdgeInsets.only(bottom: 24, left: 32, right: 32),
              child: _Footnote(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/simi_next_logo.png',
      height: 280,
      fit: BoxFit.contain,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.serverModel, required this.hasClient});
  final ServerModel serverModel;
  final bool hasClient;

  @override
  Widget build(BuildContext context) {
    String text;
    Color bg;
    IconData icon;
    if (hasClient) {
      text = 'Engineer connected';
      bg = const Color(0xFF42BE65);
      icon = Icons.cast_connected;
    } else if (serverModel.connectStatus < 0) {
      text = 'Not ready';
      bg = const Color(0xFFDA1E28);
      icon = Icons.warning_amber_rounded;
    } else if (serverModel.connectStatus == 0 || !serverModel.isStart) {
      text = 'Connecting…';
      bg = const Color(0xFFFFB000);
      icon = Icons.cloud_sync_outlined;
    } else {
      text = 'Ready for support';
      bg = const Color(0xFF0F62FE);
      icon = Icons.check_circle_outline;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(40),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _kFg, size: 28),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              color: _kFg,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 18,
        letterSpacing: 2,
        color: _kFgFaint,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _BigValue extends StatelessWidget {
  const _BigValue({required this.value, this.monospace = false});
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Text(
        value,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.visible,
        softWrap: false,
        style: TextStyle(
          fontSize: 80,
          fontWeight: FontWeight.w700,
          letterSpacing: monospace ? 8 : 2,
          fontFamily: monospace ? 'monospace' : null,
          color: _kFg,
        ),
      ),
    );
  }
}

class _Footnote extends StatelessWidget {
  const _Footnote();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Give this code to your Simi Engineer',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 22,
        color: _kFgDim,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
