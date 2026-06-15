import 'package:flutter/material.dart';

import '../services/deezer_service.dart';
import '../services/room_service.dart';
import 'room_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final RoomService _roomService = RoomService();
  final TextEditingController _nameController = TextEditingController(text: 'Jugador');
  final TextEditingController _codeController = TextEditingController();
  String _genre = DeezerService.genreQueries.keys.first;
  int _maxRounds = 5;
  int _roundDuration = 5; // segundos de fragmento
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    setState(() => _loading = true);
    try {
      final playerId = _roomService.createLocalPlayerId();
      final code = await _roomService.createRoom(
        playerId: playerId,
        playerName: _nameController.text.trim().isEmpty ? 'Host' : _nameController.text.trim(),
        genre: _genre,
        maxRounds: _maxRounds,
        roundDuration: _roundDuration,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RoomScreen(code: code, playerId: playerId),
        ),
      );
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinRoom() async {
    setState(() => _loading = true);
    try {
      final playerId = _roomService.createLocalPlayerId();
      final code = _codeController.text.trim().toUpperCase();
      await _roomService.joinRoom(
        code: code,
        playerId: playerId,
        playerName: _nameController.text.trim().isEmpty ? 'Invitado' : _nameController.text.trim(),
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RoomScreen(code: code, playerId: playerId),
        ),
      );
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('R-Song')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),

                // Logo
                Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 110,
                    height: 110,
                  ),
                ),
                const SizedBox(height: 16),

                // Título
                const Text(
                  'Adivina el song!!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 28),

                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                      labelText: 'Tu nombre', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _genre,
                  decoration: const InputDecoration(
                      labelText: 'Género', border: OutlineInputBorder()),
                  items: DeezerService.genreQueries.keys
                      .map((genre) => DropdownMenuItem(value: genre, child: Text(genre)))
                      .toList(),
                  onChanged: (value) => setState(() => _genre = value ?? _genre),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _maxRounds,
                  decoration: const InputDecoration(
                      labelText: 'Número de rondas', border: OutlineInputBorder()),
                  items: [3, 5, 7, 10, 15]
                      .map((n) => DropdownMenuItem(value: n, child: Text('$n rondas')))
                      .toList(),
                  onChanged: (v) => setState(() => _maxRounds = v ?? _maxRounds),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _roundDuration,
                  decoration: const InputDecoration(
                      labelText: 'Duración del fragmento', border: OutlineInputBorder()),
                  items: [3, 5, 7, 10, 15, 20]
                      .map((n) => DropdownMenuItem(value: n, child: Text('$n segundos')))
                      .toList(),
                  onChanged: (v) => setState(() => _roundDuration = v ?? _roundDuration),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _loading ? null : _createRoom,
                  icon: const Icon(Icons.add),
                  label: const Text('Crear sala'),
                ),
                const Divider(height: 36),
                TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                      labelText: 'Código de sala', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _joinRoom,
                  icon: const Icon(Icons.login),
                  label: const Text('Unirme'),
                ),

                const Spacer(),

                // Pie de página
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'RickyZA - Code - Developer',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
