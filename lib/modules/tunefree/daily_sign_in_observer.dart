import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../providers/kugou_provider.dart';
import '../../services/kugou_api/kugou_api_client.dart';

/// Cold start, newly authenticated account, resume after midnight, and restored
/// connectivity all enter the same account/day gate in KugouProvider.
class DailySignInObserver extends StatefulWidget {
  const DailySignInObserver({super.key, required this.child});
  final Widget child;
  @override
  State<DailySignInObserver> createState() => _DailySignInObserverState();
}

class _DailySignInObserverState extends State<DailySignInObserver>
    with WidgetsBindingObserver {
  String? _account;
  bool _scheduled = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    KugouApiClient.networkReachable.addListener(_networkChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.watch<KugouProvider>();
    final account = provider.isLoggedIn ? provider.userid : null;
    if (_account != account) {
      _account = account;
      if (account != null) _schedule();
    }
  }

  void _schedule() {
    if (_scheduled || !mounted) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted)
        unawaited(context.read<KugouProvider>().autoReceiveVipIfNeeded());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _networkChanged() {
    if (KugouApiClient.networkReachable.value &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed)
      _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _schedule();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    KugouApiClient.networkReachable.removeListener(_networkChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
