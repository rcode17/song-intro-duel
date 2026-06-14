import 'song.dart';

class PlayerState {
  final String id;
  final String name;
  final int score;
  final String? answer;
  final int? lastPoints; // puntos ganados en la última ronda

  const PlayerState({
    required this.id,
    required this.name,
    required this.score,
    this.answer,
    this.lastPoints,
  });

  factory PlayerState.fromMap(String id, Map<String, dynamic> map) {
    return PlayerState(
      id: id,
      name: '${map['name'] ?? 'Jugador'}',
      score: (map['score'] ?? 0) as int,
      answer: map['answer'] as String?,
      lastPoints: map['lastPoints'] as int?,
    );
  }
}

class RoomState {
  final String code;
  final String hostId;
  final String status;
  final String genre;
  final int round;
  final int maxRounds;
  final Song? currentSong;
  final List<String> options;
  final String? correctTitle;
  final DateTime? roundStartedAt;
  final int roundDurationSeconds; // duración del audio por ronda
  final Map<String, PlayerState> players;

  const RoomState({
    required this.code,
    required this.hostId,
    required this.status,
    required this.genre,
    required this.round,
    required this.maxRounds,
    required this.currentSong,
    required this.options,
    required this.correctTitle,
    required this.roundStartedAt,
    required this.roundDurationSeconds,
    required this.players,
  });

  factory RoomState.fromMap(String code, Map<String, dynamic> map) {
    final rawPlayers = (map['players'] as Map<String, dynamic>? ?? {});
    return RoomState(
      code: code,
      hostId: '${map['hostId'] ?? ''}',
      status: '${map['status'] ?? 'waiting'}',
      genre: '${map['genre'] ?? 'reggaeton'}',
      round: (map['round'] ?? 0) as int,
      maxRounds: (map['maxRounds'] ?? 5) as int,
      currentSong: map['currentSong'] == null
          ? null
          : Song.fromMap(Map<String, dynamic>.from(map['currentSong'])),
      options: List<String>.from(map['options'] ?? const []),
      correctTitle: map['correctTitle'] as String?,
      roundStartedAt: map['roundStartedAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['roundStartedAt'] as int),
      roundDurationSeconds: (map['roundDurationSeconds'] ?? 7) as int,
      players: rawPlayers.map(
        (key, value) => MapEntry(
          key,
          PlayerState.fromMap(key, Map<String, dynamic>.from(value)),
        ),
      ),
    );
  }
}
