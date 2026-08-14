import '../../../models/angle_sample.dart';

/// Acumula las muestras de ángulos durante una grabación en curso.
class AngleSampleBuffer {
  final List<AngleSample> _samples = [];

  List<AngleSample> get samples => List.unmodifiable(_samples);

  int get length => _samples.length;

  void add(AngleSample sample) => _samples.add(sample);

  void clear() => _samples.clear();
}
