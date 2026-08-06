import 'package:workmanager/workmanager.dart';

import '../ui/theme.dart';
import 'market_service.dart';
import 'notifications.dart';
import 'sources/source_registry.dart';
import 'validator.dart';

@pragma('vm:entry-point')
void backgroundFetchDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final registry = SourceRegistry();
      final signals = await registry.fetchAll(registry.all);
      final symbols = <String>{};
      for (final s in signals) {
        symbols.addAll(s.symbols);
      }
      if (symbols.isEmpty) return true;

      final marketService = MarketService();
      final markets = await marketService.fetchSnapshots(symbols.take(20).toList());
      marketService.dispose();

      final validator = Validator();
      final notifications = NotificationService();
      await notifications.init();

      final seen = <String>{};
      final strong = signals.where((s) {
        if (!seen.add(s.id)) return false;
        final vs = validator.validate(s, markets);
        return vs != null && vs.probability >= 70;
      }).toList();

      for (final s in strong.take(5)) {
        final vs = validator.validate(s, markets)!;
        await notifications.showSignalAlert(
          vs.symbol,
          '${vs.direction.label} ${vs.symbol}',
          'Rightness ${vs.probability.round()}% · buy at ${AppTheme.fmtClock(vs.buyAt)} · sell at ${AppTheme.fmtClock(vs.sellAt)}.',
        );
      }
    } catch (_) {
      // Background work is best-effort.
    }
    return true;
  });
}

