import 'package:flutter/material.dart';

import '../theme.dart';

/// Top-level sub-tabs for a hub screen. Each child keeps its own Scaffold and
/// AppBar; children are kept alive so switching tabs doesn't reload them.
class HubTabs extends StatelessWidget {
  final List<String> labels;
  final List<Widget> children;

  const HubTabs({super.key, required this.labels, required this.children});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: labels.length,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            TabBar(
              indicatorColor: AppTheme.accent,
              labelColor: AppTheme.textPrimary,
              unselectedLabelColor: AppTheme.textMuted,
              dividerColor: AppTheme.line,
              tabs: [for (final l in labels) Tab(text: l, height: 40)],
            ),
            Expanded(
              child: TabBarView(
                children: [for (final c in children) _KeepAlive(child: c)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
