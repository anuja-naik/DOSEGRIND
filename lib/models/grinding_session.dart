class GrindingSession {
  const GrindingSession({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.jar,
    required this.sourceMode,
    required this.durationSeconds,
    required this.energyWh,
    required this.averagePowerW,
    required this.maximumPowerW,
    required this.temperatureC,
    required this.temperatureTrendC,
    required this.texture,
    this.recipeName,
    this.feedback,
  });
  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final String jar;
  final String sourceMode;
  final int durationSeconds;
  final double energyWh;
  final double averagePowerW;
  final double maximumPowerW;
  final double? temperatureC;
  final List<double> temperatureTrendC;
  final String texture;
  final String? recipeName;
  final String? feedback;

  Map<String, dynamic> toJson() => {
        'id': id,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt.toIso8601String(),
        'jar': jar,
        'sourceMode': sourceMode,
        'durationSeconds': durationSeconds,
        'energyWh': energyWh,
        'averagePowerW': averagePowerW,
        'maximumPowerW': maximumPowerW,
        'temperatureC': temperatureC,
        'temperatureTrendC': temperatureTrendC,
        'texture': texture,
        'recipeName': recipeName,
        'feedback': feedback,
      };

  factory GrindingSession.fromJson(Map<String, dynamic> j) => GrindingSession(
        id: j['id'] as String,
        startedAt: DateTime.parse(j['startedAt'] as String),
        endedAt: DateTime.parse(j['endedAt'] as String),
        jar: j['jar'] as String? ?? 'Unknown jar',
        sourceMode: j['sourceMode'] as String? ?? 'LIVE',
        durationSeconds: (j['durationSeconds'] as num?)?.toInt() ?? 0,
        energyWh: (j['energyWh'] as num?)?.toDouble() ?? 0,
        averagePowerW: (j['averagePowerW'] as num?)?.toDouble() ?? 0,
        maximumPowerW: (j['maximumPowerW'] as num?)?.toDouble() ?? 0,
        temperatureC: (j['temperatureC'] as num?)?.toDouble(),
        temperatureTrendC: (j['temperatureTrendC'] as List<dynamic>? ?? const []).whereType<num>().map((e) => e.toDouble()).toList(),
        texture: j['texture'] as String? ?? 'medium',
        recipeName: j['recipeName'] as String?,
        feedback: j['feedback'] as String?,
      );
}
