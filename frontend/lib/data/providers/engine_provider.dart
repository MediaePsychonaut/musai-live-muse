import 'package:flutter_riverpod/flutter_riverpod.dart';

enum EngineType {
  flash20Exp,
  flash25Native,
}

class EngineNotifier extends Notifier<EngineType> {
  @override
  EngineType build() {
    return EngineType.flash25Native;
  }

  void switchEngine(EngineType engine) {
    state = engine;
  }
}

final engineProvider = NotifierProvider<EngineNotifier, EngineType>(() {
  return EngineNotifier();
});
