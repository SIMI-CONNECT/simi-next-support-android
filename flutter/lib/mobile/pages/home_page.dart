import 'package:flutter/material.dart';
import 'package:flutter_hbb/mobile/pages/server_page.dart';
import 'package:flutter_hbb/web/settings_page.dart';
import '../../common.dart';
import '../../models/platform_model.dart';
import '../../models/state_model.dart';
import '../../simi_branding/signage_home_page.dart';
import 'connection_page.dart';

// Retained so the upstream PageShape contract (referenced indirectly
// from a few places) still compiles. Concrete pages we no longer
// instantiate (ConnectionPage, ChatPage, SettingsPage) implement it
// themselves and are unaffected.
abstract class PageShape extends Widget {
  final String title = "";
  final Widget icon = Icon(null);
  final List<Widget> appBarActions = [];
}

class HomePage extends StatefulWidget {
  static final homeKey = GlobalKey<HomePageState>();

  HomePage() : super(key: homeKey);

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  // Single-screen signage UI — no nav, no tabs. The 3-dot menu in the
  // AppBar still gives techs access to set permanent password / change
  // ID via the existing ServerPage._DropDownAction widget.
  static final _serverPage = ServerPage();

  // Kept on the public surface because upstream code reads this getter.
  int get selectedIndex => 0;
  bool get isChatPageCurrentTab => false;
  void refreshPages() {} // no-op now; nothing to refresh.

  @override
  void initState() {
    super.initState();
    // Closed-product unattended signage: on every launch, auto-fire the
    // screen-sharing service once the first frame is up. The Android
    // system MediaProjection consent prompt still appears, but the
    // InputService AccessibilityService auto-clicks it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!gFFI.serverModel.isStart) {
        gFFI.serverModel.toggleService();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xFF000000),
        foregroundColor: const Color(0xFFFFFFFF),
        elevation: 0,
        title: const Text('Simi Next Support'),
        actions: _serverPage.appBarActions,
      ),
      body: const SignageHomePage(),
    );
  }
}

class WebHomePage extends StatelessWidget {
  final connectionPage =
      ConnectionPage(appBarActions: <Widget>[const WebSettingsPage()]);

  @override
  Widget build(BuildContext context) {
    stateGlobal.isInMainPage = true;
    handleUnilink(context);
    return Scaffold(
      // backgroundColor: MyTheme.grayBg,
      appBar: AppBar(
        centerTitle: true,
        title: Text("${bind.mainGetAppNameSync()} (Preview)"),
        actions: connectionPage.appBarActions,
      ),
      body: connectionPage,
    );
  }

  handleUnilink(BuildContext context) {
    if (webInitialLink.isEmpty) {
      return;
    }
    final link = webInitialLink;
    webInitialLink = '';
    final splitter = ["/#/", "/#", "#/", "#"];
    var fakelink = '';
    for (var s in splitter) {
      if (link.contains(s)) {
        var list = link.split(s);
        if (list.length < 2 || list[1].isEmpty) {
          return;
        }
        list.removeAt(0);
        fakelink = "rustdesk://${list.join(s)}";
        break;
      }
    }
    if (fakelink.isEmpty) {
      return;
    }
    final uri = Uri.tryParse(fakelink);
    if (uri == null) {
      return;
    }
    final args = urlLinkToCmdArgs(uri);
    if (args == null || args.isEmpty) {
      return;
    }
    bool isFileTransfer = false;
    bool isViewCamera = false;
    bool isTerminal = false;
    String? id;
    String? password;
    for (int i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--connect':
        case '--play':
          id = args[i + 1];
          i++;
          break;
        case '--file-transfer':
          isFileTransfer = true;
          id = args[i + 1];
          i++;
          break;
        case '--view-camera':
          isViewCamera = true;
          id = args[i + 1];
          i++;
          break;
        case '--terminal':
          isTerminal = true;
          id = args[i + 1];
          i++;
          break;
        case '--terminal-admin':
          setEnvTerminalAdmin();
          isTerminal = true;
          id = args[i + 1];
          i++;
          break;
        case '--password':
          password = args[i + 1];
          i++;
          break;
        default:
          break;
      }
    }
    if (id != null) {
      connect(context, id, 
        isFileTransfer: isFileTransfer, 
        isViewCamera: isViewCamera, 
        isTerminal: isTerminal,
        password: password);
    }
  }
}
