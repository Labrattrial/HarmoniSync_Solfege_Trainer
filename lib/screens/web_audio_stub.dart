// Minimal no-op stubs for non-web platforms so conditional import compiles

class AudioContext {
  final num? currentTime = 0;
  final Object? destination = Object();

  GainNode createGain() => GainNode();
  OscillatorNode createOscillator() => OscillatorNode();
}

class GainNode {
  final AudioParam? gain = AudioParam();
  void connectNode(Object destination) {}
}

class OscillatorNode {
  String? type;
  final AudioParam? frequency = AudioParam();
  void connectNode(Object destination) {}
  void start2(num when) {}
  void stop(num when) {}
}

class AudioParam {
  double? value;
  void setValueAtTime(double value, num time) {}
  void exponentialRampToValueAtTime(double value, num time) {}
}


