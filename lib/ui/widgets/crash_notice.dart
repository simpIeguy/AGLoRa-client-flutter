import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/log_sharing.dart';
import '../../util/log.dart';
import '../strings.dart';

/// After a launch that had an error: once, a banner "last time there was an
/// error" with a button to save the journal.
class CrashNotice extends StatefulWidget {
  const CrashNotice({
    super.key,
    required this.messengerKey,
    required this.child,
    this.log,
  });

  final GlobalKey<ScaffoldMessengerState> messengerKey;
  final Widget child;

  /// the journal to ask; the app's own when null
  final AppLog? log;

  @override
  State<CrashNotice> createState() => _CrashNoticeState();
}

class _CrashNoticeState extends State<CrashNotice> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _show());
  }

  void _show() {
    final log = widget.log ?? AppLog.instance;
    final messenger = widget.messengerKey.currentState;
    if (!mounted || messenger == null || !log.previousRunHadError) return;
    log.previousRunHadError = false;
    void close() => messenger.hideCurrentMaterialBanner();
    messenger.showMaterialBanner(MaterialBanner(
      leading: const Icon(Icons.bug_report_outlined),
      content: const Text(S.crashNotice),
      actions: [
        TextButton(
          onPressed: () {
            close();
            unawaited(shareLog(log).catchError((Object _) {}));
          },
          child: const Text(S.saveLog),
        ),
        TextButton(onPressed: close, child: const Text(S.close)),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
