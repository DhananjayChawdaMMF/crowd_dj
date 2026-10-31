import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Shows each non-null message put on any of [notices] as a snackbar, then
/// clears it so the same message can be shown again later.
class NoticeListener extends StatefulWidget {
  const NoticeListener({super.key, required this.notices, required this.child});

  final List<RxnString> notices;
  final Widget child;

  @override
  State<NoticeListener> createState() => _NoticeListenerState();
}

class _NoticeListenerState extends State<NoticeListener> {
  final _workers = <Worker>[];

  @override
  void initState() {
    super.initState();
    for (final notice in widget.notices) {
      _workers.add(
        ever<String?>(notice, (message) {
          if (message == null || !mounted) return;
          ScaffoldMessenger.maybeOf(context)
            ?..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(message),
                behavior: SnackBarBehavior.floating,
                width: 420,
              ),
            );
          notice.value = null;
        }),
      );
    }
  }

  @override
  void dispose() {
    for (final w in _workers) {
      w.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
