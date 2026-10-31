import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Runs a GetX [Bindings] when the route is mounted and removes the
/// controllers it registered when the route is disposed, so go_router
/// navigation gets the same lifecycle as GetPage bindings.
class BindingScope extends StatefulWidget {
  const BindingScope({
    super.key,
    required this.binding,
    required this.child,
    this.onDispose = const [],
  });

  final Bindings binding;
  final Widget child;

  /// Disposal callbacks for each controller the binding registers.
  final List<void Function()> onDispose;

  @override
  State<BindingScope> createState() => _BindingScopeState();
}

class _BindingScopeState extends State<BindingScope> {
  @override
  void initState() {
    super.initState();
    widget.binding.dependencies();
  }

  @override
  void dispose() {
    for (final dispose in widget.onDispose) {
      dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
