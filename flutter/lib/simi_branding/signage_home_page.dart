// Simi Next Support — signage home page.
//
// One screen, DPAD-tunable, big-font readouts only. No tabs, no
// permission switches, no Stop service button, no connection-manager
// list. The AccessibilityService auto-grants Screen Capture and
// home_page auto-fires the foreground service, so by the time the
// operator sees this surface it's already serving — they just need
// to read off the ID and password to the tech.
//
// What lives here:
//   - Status badge (Ready / Connecting / Not ready / Tech connected)
//   - Support ID (very large)
//   - Password (very large)
//
// Anything else (Settings, Set permanent password, etc.) is reachable
// via the AppBar 3-dot menu, which lives outside this widget.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../common.dart';
import '../models/platform_model.dart';
import '../models/server_model.dart';

class SignageHomePage extends StatelessWidget {
  const SignageHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: gFFI.serverModel,
      child: Consumer<ServerModel>(
        builder: (context, serverModel, _) => _Body(serverModel: serverModel),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.serverModel});
  final ServerModel serverModel;

  @override
  Widget build(BuildContext context) {
    final hasClient = serverModel.clients.isNotEmpty;
    final id = serverModel.serverId.value.text.trim();
    final showOneTime = serverModel.approveMode != 'click' &&
        serverModel.verificationMethod != kUsePermanentPassword;
    final pwd = !showOneTime ? '••••••' : serverModel.serverPasswd.value.text;
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.white,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top: status badge.
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: _StatusBadge(serverModel: serverModel, hasClient: hasClient),
              ),
            ),
            // Middle: ID + password, both centered.
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
              padding: EdgeInsets.only(bottom: 16, left: 32, right: 32),
              child: _Footnote(),
            ),
          ],
        ),
      ),
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
      text = 'Technician connected';
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
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
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
        color: Color(0xFF8D8D8D),
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
          color: const Color(0xFF161616),
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
      'Read the Support ID and Password to your Simi technician.',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 18,
        color: Color(0xFF6F6F6F),
      ),
    );
  }
}
