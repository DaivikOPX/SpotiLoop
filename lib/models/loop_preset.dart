import 'dart:convert';

class LoopPreset {
  final String id;
  final String trackId;
  final String trackTitle;
  final String trackArtist;
  final String name;
  final int startMs;
  final int endMs;
  final DateTime createdAt;

  LoopPreset({
    required this.id,
    required this.trackId,
    required this.trackTitle,
    required this.trackArtist,
    required this.name,
    required this.startMs,
    required this.endMs,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'trackId': trackId,
        'trackTitle': trackTitle,
        'trackArtist': trackArtist,
        'name': name,
        'startMs': startMs,
        'endMs': endMs,
        'createdAt': createdAt.toIso8601String(),
      };

  factory LoopPreset.fromJson(Map<String, dynamic> json) => LoopPreset(
        id: json['id'] as String,
        trackId: json['trackId'] as String,
        trackTitle: json['trackTitle'] as String? ?? 'Unknown Title',
        trackArtist: json['trackArtist'] as String? ?? 'Unknown Artist',
        name: json['name'] as String? ?? 'Custom Loop',
        startMs: json['startMs'] as int,
        endMs: json['endMs'] as int,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );

  static String encodeList(List<LoopPreset> list) =>
      jsonEncode(list.map((p) => p.toJson()).toList());

  static List<LoopPreset> decodeList(String jsonString) {
    if (jsonString.isEmpty) return [];
    try {
      final decoded = jsonDecode(jsonString) as List<dynamic>;
      return decoded.map((item) => LoopPreset.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }
}
