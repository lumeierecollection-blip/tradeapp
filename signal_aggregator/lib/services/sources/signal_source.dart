import '../../models/signal.dart';

abstract class SignalSource {
  String get key;
  String get name;
  bool get requiresSetup;
  Future<List<Signal>> fetch();
}
