import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../models/room.dart';
import '../services/room_service.dart';

class RoomScreen extends StatefulWidget {
  final String code;
  final String playerId;

  const RoomScreen({super.key, required this.code, required this.playerId});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final RoomService _roomService = RoomService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  StreamSubscription<RoomState>? _roomSub;
  RoomState? _room;

  String? _lastPlayedSongId;
  Timer? _stopTimer;
  Timer? _countdownTimer;

  int _secondsLeft = 0;
  int _secondsElapsed = 0;
  bool _audioStarted = false;
  bool _startingRound = false; // evita doble clic y muestra loading

  @override
  void initState() {
    super.initState();
    _roomSub = _roomService.roomStream(widget.code).listen(
      (room) {
        setState(() => _room = room);
        if (room.status == 'playing') {
          _playPreview(room);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _room = null);
      },
    );
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    _stopTimer?.cancel();
    _countdownTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playPreview(RoomState room) async {
    final song = room.currentSong;
    final startedAt = room.roundStartedAt;
    final duration = room.roundDurationSeconds;
    final songKey = '${song?.deezerId}-${room.round}';

    if (song == null || startedAt == null || _lastPlayedSongId == songKey) return;
    _lastPlayedSongId = songKey;

    _stopTimer?.cancel();
    _countdownTimer?.cancel();

    if (mounted) {
      setState(() {
        _secondsLeft = duration;
        _secondsElapsed = 0;
        _audioStarted = false;
      });
    }

    final delay = startedAt.difference(DateTime.now());
    if (delay.inMilliseconds > 0) {
      await Future.delayed(delay);
    }
    if (!mounted) return;

    await _audioPlayer.setUrl(song.previewUrl);
    await _audioPlayer.seek(Duration.zero);
    unawaited(_audioPlayer.play());

    // Marcar que el audio arrancó — ahora sí mostramos opciones y countdown
    if (mounted) setState(() => _audioStarted = true);

    // Countdown arranca con el audio
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        _secondsElapsed++;
        _secondsLeft = (duration - _secondsElapsed).clamp(0, duration);
      });
      if (_secondsElapsed >= duration) timer.cancel();
    });

    // Al agotar el tiempo: parar audio y forzar avance si es el host
    _stopTimer = Timer(Duration(seconds: duration), () async {
      _audioPlayer.pause();
      // Si se acabó el tiempo y queda alguien sin responder,
      // el host avanza automáticamente (registra respuesta vacía primero)
      if (!mounted) return;
      final current = _room;
      if (current == null) return;
      final me = current.players[widget.playerId];
      if (me?.answer == null) {
        // Registrar tiempo agotado como respuesta vacía
        await _roomService.submitAnswer(
          room: current,
          playerId: widget.playerId,
          answer: '',
          secondsElapsed: duration,
        );
      }
    });
  }

  Future<void> _startRound(RoomState room) async {
    if (_startingRound) return;
    setState(() => _startingRound = true);
    try {
      await _roomService.startNextRound(room);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al iniciar: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _startingRound = false);
    }
  }

  Future<void> _answer(RoomState room, String answer) async {
    _audioPlayer.pause();
    await _roomService.submitAnswer(
      room: room,
      playerId: widget.playerId,
      answer: answer,
      secondsElapsed: _secondsElapsed,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_room == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final room = _room!;
    final isHost = room.hostId == widget.playerId;
    final me = room.players[widget.playerId];

    return Scaffold(
      appBar: AppBar(title: Text('Sala ${room.code}')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(room: room),
                const SizedBox(height: 16),

                if (room.status == 'waiting') ...[
                  Text(
                    'Código para tu amigo: ${room.code}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text('Jugadores conectados: ${room.players.length}/2',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  const Text(
                    '(Puedes jugar solo o esperar a un segundo jugador)',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: (isHost && !_startingRound)
                        ? () => _startRound(room)
                        : null,
                    child: _startingRound
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Empezar partida'),
                  ),

                ] else if (room.status == 'finished') ...[
                  const SizedBox(height: 20),
                  const Text('🏆 Partida terminada',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _Scoreboard(room: room, showLastPoints: false),
                  const SizedBox(height: 16),
                  // Mostrar ganador
                  _Winner(room: room),

                ] else ...[
                  // Ronda y countdown
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Ronda ${room.round}/${room.maxRounds}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      if (_audioStarted)
                        _AudioCountdown(
                          secondsLeft: _secondsLeft,
                          totalSeconds: room.roundDurationSeconds,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (!_audioStarted) ...[
                    const SizedBox(height: 40),
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 12),
                    const Text('🎵 Cargando canción...',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey)),
                  ] else ...[
                    // Indicador de velocidad mientras no se ha respondido
                    if (me?.answer == null)
                      _SpeedBonus(
                        secondsElapsed: _secondsElapsed,
                        totalSeconds: room.roundDurationSeconds,
                      ),

                    const SizedBox(height: 16),

                    // Opciones visibles desde que arranca el audio
                    ...room.options.map((option) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AnswerButton(
                        option: option,
                        myAnswer: me?.answer,
                        correctTitle: room.correctTitle,
                        onTap: me?.answer == null ? () => _answer(room, option) : null,
                      ),
                    )),

                    // Resultado de esta ronda
                    if (me?.answer != null) ...[
                      const SizedBox(height: 8),
                      _PointsEarned(
                        points: me!.lastPoints ?? 0,
                        correct: me.answer == room.correctTitle,
                        correctTitle: room.correctTitle,
                      ),
                    ],

                    // Estado de los demás jugadores
                    const SizedBox(height: 8),
                    _PlayersStatus(room: room, myPlayerId: widget.playerId),
                  ],

                  const Spacer(),
                  _Scoreboard(room: room, showLastPoints: true),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final RoomState room;
  const _Header({required this.room});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('🎵 ${room.genre}'),
            Text(room.status == 'playing' ? '▶ En juego' : room.status,
                style: TextStyle(
                  color: room.status == 'playing' ? Colors.green : Colors.grey,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ),
    );
  }
}

/// Countdown compacto en línea (número + barra)
class _AudioCountdown extends StatelessWidget {
  final int secondsLeft;
  final int totalSeconds;
  const _AudioCountdown({required this.secondsLeft, required this.totalSeconds});

  @override
  Widget build(BuildContext context) {
    final progress = totalSeconds > 0 ? secondsLeft / totalSeconds : 0.0;
    final color = secondsLeft <= 2
        ? Colors.red
        : secondsLeft <= totalSeconds ~/ 2
            ? Colors.orange
            : Colors.deepPurple;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 4,
                color: color,
                backgroundColor: Colors.grey.shade200,
              ),
              Text('$secondsLeft',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Text('seg', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
      ],
    );
  }
}

/// Indicador de bonus según velocidad — se actualiza en tiempo real
class _SpeedBonus extends StatelessWidget {
  final int secondsElapsed;
  final int totalSeconds;
  const _SpeedBonus({required this.secondsElapsed, required this.totalSeconds});

  @override
  Widget build(BuildContext context) {
    final third = totalSeconds / 3;
    final String label;
    final Color color;

    if (secondsElapsed <= third) {
      label = '⚡ Responde ya · +20 pts';
      color = Colors.amber.shade700;
    } else if (secondsElapsed <= third * 2) {
      label = '🕐 +10 pts si aciertas';
      color = Colors.orange;
    } else {
      label = '🐢 +5 pts si aciertas';
      color = Colors.grey;
    }

    return Text(label,
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontWeight: FontWeight.w600));
  }
}

/// Botón de respuesta con feedback visual tras responder
class _AnswerButton extends StatelessWidget {
  final String option;
  final String? myAnswer;
  final String? correctTitle;
  final VoidCallback? onTap;

  const _AnswerButton({
    required this.option,
    required this.myAnswer,
    required this.correctTitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final answered = myAnswer != null;
    final isCorrect = option == correctTitle;
    final isMyChoice = option == myAnswer;

    Color? bgColor;
    if (answered) {
      if (isCorrect) bgColor = Colors.green.shade100;
      if (isMyChoice && !isCorrect) bgColor = Colors.red.shade100;
    }

    return FilledButton.tonal(
      onPressed: onTap,
      style: bgColor != null
          ? FilledButton.styleFrom(backgroundColor: bgColor)
          : null,
      child: Text(option),
    );
  }
}

/// Resultado de la ronda con la respuesta correcta visible
class _PointsEarned extends StatelessWidget {
  final int points;
  final bool correct;
  final String? correctTitle;

  const _PointsEarned({
    required this.points,
    required this.correct,
    required this.correctTitle,
  });

  @override
  Widget build(BuildContext context) {
    if (correct) {
      return Text('✅ ¡Correcto! +$points pts',
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16));
    }
    return Column(
      children: [
        const Text('❌ Incorrecto — 0 pts',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        if (correctTitle != null && correctTitle!.isNotEmpty)
          Text('Era: $correctTitle',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
      ],
    );
  }
}

/// Muestra en tiempo real quién ya respondió y quién sigue pensando
class _PlayersStatus extends StatelessWidget {
  final RoomState room;
  final String myPlayerId;

  const _PlayersStatus({required this.room, required this.myPlayerId});

  @override
  Widget build(BuildContext context) {
    final others = room.players.entries
        .where((e) => e.key != myPlayerId)
        .toList();

    if (others.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: others.map((e) {
        final answered = e.value.answer != null;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Chip(
            avatar: Icon(
              answered ? Icons.check_circle : Icons.hourglass_empty,
              size: 16,
              color: answered ? Colors.green : Colors.orange,
            ),
            label: Text(e.value.name),
            backgroundColor: answered
                ? Colors.green.shade50
                : Colors.orange.shade50,
          ),
        );
      }).toList(),
    );
  }
}

class _Winner extends StatelessWidget {
  final RoomState room;
  const _Winner({required this.room});

  @override
  Widget build(BuildContext context) {
    if (room.players.isEmpty) return const SizedBox.shrink();
    final sorted = room.players.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    final winner = sorted.first;
    final isTie = sorted.length > 1 && sorted[0].score == sorted[1].score;

    return Text(
      isTie ? '🤝 ¡Empate!' : '🥇 Ganador: ${winner.name}',
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }
}

class _Scoreboard extends StatelessWidget {
  final RoomState room;
  final bool showLastPoints;
  const _Scoreboard({required this.room, required this.showLastPoints});

  @override
  Widget build(BuildContext context) {
    final players = room.players.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Puntaje', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (final player in players)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(player.name),
                  Row(children: [
                    if (showLastPoints &&
                        player.lastPoints != null &&
                        player.lastPoints! > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text('+${player.lastPoints}',
                            style: const TextStyle(
                                color: Colors.green, fontSize: 12)),
                      ),
                    Text('${player.score} pts'),
                  ]),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
