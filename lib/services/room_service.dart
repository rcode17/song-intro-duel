import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/room.dart';
import '../models/song.dart';
import 'deezer_service.dart';

class RoomService {
  final FirebaseFirestore _firestore;
  final DeezerService _deezerService;
  final Random _random = Random();
  final Uuid _uuid = const Uuid();

  RoomService({FirebaseFirestore? firestore, DeezerService? deezerService})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _deezerService = deezerService ?? DeezerService();

  String createLocalPlayerId() => _uuid.v4();

  Stream<RoomState> roomStream(String code) {
    return _firestore.collection('rooms').doc(code).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) throw Exception('La sala no existe');
      return RoomState.fromMap(snapshot.id, data);
    });
  }

  Future<String> createRoom({
    required String playerId,
    required String playerName,
    required String genre,
    int maxRounds = 5,
    int roundDuration = 5,
  }) async {
    final code = _generateCode();
    await _firestore.collection('rooms').doc(code).set({
      'hostId': playerId,
      'status': 'waiting',
      'genre': genre,
      'round': 0,
      'maxRounds': maxRounds,
      'roundDuration': roundDuration,
      'createdAt': FieldValue.serverTimestamp(),
      'players': {
        playerId: {'name': playerName, 'score': 0, 'answer': null, 'lastPoints': null}
      },
    });
    return code;
  }

  Future<void> joinRoom({
    required String code,
    required String playerId,
    required String playerName,
  }) async {
    final ref = _firestore.collection('rooms').doc(code.toUpperCase());
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw Exception('La sala no existe');
      final data = snapshot.data()!;
      final players = Map<String, dynamic>.from(data['players'] ?? {});
      if (!players.containsKey(playerId) && players.length >= 2) {
        throw Exception('Esta sala ya tiene 2 jugadores');
      }
      players[playerId] = {
        'name': playerName,
        'score': players[playerId]?['score'] ?? 0,
        'answer': null,
        'lastPoints': null,
      };
      transaction.update(ref, {'players': players});
    });
  }

  Future<void> startNextRound(RoomState room) async {
    if (room.round >= room.maxRounds) {
      await _firestore.collection('rooms').doc(room.code).update({'status': 'finished'});
      return;
    }

    final nextRound = room.round + 1;
    final duration = room.roundDuration;

    final songs = await _deezerService.searchSongsByGenre(room.genre);
    if (songs.length < 4) throw Exception('No hay suficientes canciones para este género');

    final current = songs.first;

    // Generar opciones confusas: mezcla títulos parecidos del mismo género
    // con variantes del título correcto para causar confusión
    final otherTitles = songs.skip(1).map((s) => s.title).toList();
    final confusingOptions = _buildConfusingOptions(current.title, otherTitles);
    final options = <String>[current.title, ...confusingOptions]..shuffle(_random);

    final players = {
      for (final entry in room.players.entries)
        entry.key: {
          'name': entry.value.name,
          'score': entry.value.score,
          'answer': null,
          'lastPoints': null,
        }
    };

    await _firestore.collection('rooms').doc(room.code).update({
      'status': 'playing',
      'round': nextRound,
      'roundDurationSeconds': duration,
      'currentSong': current.toMap(),
      'correctTitle': current.title,
      'options': options,
      // 5s de countdown 3-2-1 antes de arrancar + 2.5s de gracia para cargar audio
      'roundStartedAt': DateTime.now().millisecondsSinceEpoch + 5000 + 2500,
      'countdownStartedAt': DateTime.now().millisecondsSinceEpoch,
      'players': players,
    });
  }

  Future<void> submitAnswer({
    required RoomState room,
    required String playerId,
    required String answer,
    required int secondsElapsed,
  }) async {
    final ref = _firestore.collection('rooms').doc(room.code);

    bool allAnswered = false;

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final data = snapshot.data();
      if (data == null) return;

      final players = Map<String, dynamic>.from(data['players'] ?? {});
      final player = Map<String, dynamic>.from(players[playerId] ?? {});
      if (player['answer'] != null) return;

      final correctTitle = '${data['correctTitle']}';
      final isCorrect = answer == correctTitle;
      final points = isCorrect
          ? _pointsForSpeed(secondsElapsed, data['roundDurationSeconds'] as int? ?? 7)
          : 0;

      player['answer'] = answer.isEmpty ? '(tiempo agotado)' : answer;
      player['score'] = (player['score'] ?? 0) + points;
      player['lastPoints'] = points;
      players[playerId] = player;

      // Verificar si todos respondieron dentro de la misma transacción
      allAnswered = players.values
          .every((p) => (p as Map<String, dynamic>)['answer'] != null);

      transaction.update(ref, {'players': players});
    });

    // Avanzar automáticamente si todos respondieron
    if (allAnswered) {
      await Future.delayed(const Duration(seconds: 2));
      final roomSnap = await ref.get();
      final roomData = roomSnap.data();
      if (roomData == null) return;
      // Verificar de nuevo que sigue siendo necesario avanzar
      if (roomData['status'] != 'playing') return;
      final currentRoom = RoomState.fromMap(ref.id, roomData);
      await startNextRound(currentRoom);
    }
  }

  /// Puntos según velocidad de respuesta.
  /// Responder en el primer tercio del tiempo = 20pts
  /// Segundo tercio = 10pts
  /// Último tercio = 5pts
  int _pointsForSpeed(int secondsElapsed, int roundDuration) {
    final third = roundDuration / 3;
    if (secondsElapsed <= third) return 20;
    if (secondsElapsed <= third * 2) return 10;
    return 5;
  }

  /// Construye 3 opciones falsas que causen confusión mezclando:
  /// - Títulos de otras canciones del mismo género (parecidos en longitud/estilo)
  /// - Variantes del título correcto (palabras intercambiadas, artículo cambiado)
  List<String> _buildConfusingOptions(String correctTitle, List<String> otherTitles) {
    final result = <String>[];

    // 1. Buscar títulos de longitud similar al correcto (±3 palabras)
    final correctWords = correctTitle.split(' ').length;
    final similar = otherTitles
        .where((t) => (t.split(' ').length - correctWords).abs() <= 3)
        .where((t) => t != correctTitle)
        .toList()
      ..shuffle(_random);

    result.addAll(similar.take(2));

    // 2. Si no hay suficientes similares, generar variante del título correcto
    if (result.length < 3) {
      final variant = _titleVariant(correctTitle);
      if (variant != null && !result.contains(variant)) {
        result.add(variant);
      }
    }

    // 3. Completar con cualquier otro título si aún faltan
    if (result.length < 3) {
      final remaining = otherTitles.where((t) => !result.contains(t) && t != correctTitle).toList()
        ..shuffle(_random);
      result.addAll(remaining.take(3 - result.length));
    }

    return result.take(3).toList();
  }

  /// Genera una variante confusa del título cambiando una palabra clave.
  String? _titleVariant(String title) {
    final words = title.split(' ');
    if (words.length < 2) return null;

    // Reemplazar la última palabra con una alternativa común
    final swaps = {
      'amor': 'fuego',
      'fuego': 'amor',
      'noche': 'noche entera',
      'corazón': 'alma',
      'alma': 'corazón',
      'vida': 'locura',
      'locura': 'vida',
      'quiero': 'necesito',
      'necesito': 'quiero',
      'bella': 'linda',
      'linda': 'bella',
      'baby': 'mami',
      'mami': 'baby',
    };

    for (int i = words.length - 1; i >= 0; i--) {
      final lower = words[i].toLowerCase();
      if (swaps.containsKey(lower)) {
        final newWords = List<String>.from(words);
        newWords[i] = swaps[lower]!;
        return newWords.join(' ');
      }
    }

    // Si no hay swap, invertir las dos primeras palabras
    if (words.length >= 2) {
      return [words[1], words[0], ...words.skip(2)].join(' ');
    }

    return null;
  }

  /// Revancha: reinicia la misma sala con los mismos jugadores, puntajes en 0.
  Future<void> rematch({required RoomState room, required int maxRounds}) async {
    final players = {
      for (final entry in room.players.entries)
        entry.key: {
          'name': entry.value.name,
          'score': 0,
          'answer': null,
          'lastPoints': null,
        }
    };
    await _firestore.collection('rooms').doc(room.code).update({
      'status': 'waiting',
      'round': 0,
      'maxRounds': maxRounds,
      'roundDuration': room.roundDuration, // conservar duración de fragmento
      'currentSong': null,
      'correctTitle': null,
      'options': [],
      'roundStartedAt': null,
      'countdownStartedAt': null,
      'players': players,
    });
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(5, (_) => chars[_random.nextInt(chars.length)]).join();
  }
}
