import 'joint_angles.dart';
import 'joint_angular_velocity.dart';

/// Una fila de datos: los 8 ángulos articulares y su velocidad angular en
/// un instante durante una grabación. Se agrega una muestra por frame
/// procesado, incondicionalmente (incluso con todos los valores en `null`),
/// para no dejar huecos irregulares en la serie de tiempo exportada.
class AngleSample {
  const AngleSample({
    required this.timestampMs,
    required this.frameIndex,
    required this.angles,
    required this.velocity,
  });

  /// Milisegundos desde que empezó la grabación (no desde epoch) — es la
  /// clave para sincronizar esta fila con un instante del video.
  final int timestampMs;

  /// Contador 0,1,2... de muestras agregadas al buffer. No es el conteo de
  /// frames crudos de la cámara: los descartados por el throttling de
  /// MeasurementController no cuentan.
  final int frameIndex;

  final JointAngles angles;

  /// Velocidad angular en °/s. `JointAngularVelocity.empty` si no hubo
  /// frame anterior válido.
  final JointAngularVelocity velocity;
}
