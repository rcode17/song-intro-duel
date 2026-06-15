import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/song.dart';

class DeezerService {
  final http.Client _client;
  final Random _random = Random();

  DeezerService({http.Client? client}) : _client = client ?? http.Client();

  static const List<String> genres = [
    'Salsa',
    'Reggaetón',
    'Bachata',
    'Vallenato',
    'Rock en español',
    'Pop latino',
    'Champeta y Africanos',
    'Crossover',
  ];

  static Map<String, String> get genreQueries => {
        for (final g in genres) g: g,
      };

  static const Map<String, List<String>> _genreArtists = {
    'Salsa': [
      // Clásicos y legendarios NY/Fania
      'Celia Cruz', 'Rubén Blades', 'Willie Colon', 'Hector Lavoe',
      'Ismael Rivera', 'Cheo Feliciano', 'Pete Rodriguez', 'Bobby Cruz',
      'Ricardo Ray', 'Tito Puente', 'Eddie Palmieri', 'Larry Harlow',
      'Johnny Pacheco', 'Ray Barreto', 'La Lupe',
      // Salsa dura / orquestas clásicas
      'Charanga 76', 'Tipica 73', 'Sonora Ponceña', 'Bobby Valentin',
      'Orquesta Broadway', 'Conjunto Libre', 'Willie Rosario',
      // Orquestas colombianas
      'Grupo Niche', 'Guayacan Orquesta', 'Fruko y Sus Tesos',
      'La Sonora Carruseles', 'Los Graduados',
      // Románticos y modernos
      'Gilberto Santa Rosa', 'Marc Anthony', 'Victor Manuelle',
      'Maelo Ruiz', 'Tito Rojas', 'David Pabón', 'Yiyo Sarante',
      'Jerry Rivera', 'Luis Enrique', 'La India', 'Tony Vega',
      'Frankie Ruiz', 'Eddie Santiago', 'Lalo Rodriguez',
      'Willie Gonzalez', 'Hansel y Raul',
      // Venezuela
      'Oscar D Leon', 'Dimension Latina',
      // Puertorriqueños y neoyorquinos
      'El Gran Combo', 'Puerto Rican Power', 'Roberto Roena',
      'Tito Gomez', 'Pedro Conga',
    ],
    'Reggaetón': [
      'Bad Bunny', 'J Balvin', 'Daddy Yankee', 'Maluma', 'Ozuna',
      'Anuel AA', 'Nicky Jam', 'Don Omar', 'Wisin', 'Farruko',
      'Myke Towers', 'Sech', 'Jhay Cortez', 'Rauw Alejandro', 'Karol G',
    ],
    'Bachata': [
      'Romeo Santos', 'Prince Royce', 'Aventura', 'Juan Luis Guerra',
      'Frank Reyes', 'Xtreme', 'Zacarias Ferreira', 'Luis Vargas',
      'Anthony Santos', 'Monchy y Alexandra',
    ],
    'Vallenato': [
      'Carlos Vives', 'Silvestre Dangond', 'Jorge Celedón',
      'Diomedes Díaz', 'Carlos Huertas', 'Kaleth Morales',
      'Jean Carlos Centeno', 'Iván Villazón',
      'Los Inquietos del Vallenato', 'Los Diablitos',
      'Los Betos', 'Los Zuleta', 'Farid Ortiz',
      'El Binomio de Oro de America', 'Elder Dayán Díaz',
      'Felipe Pelaez', 'Martin Elias Diaz',
    ],
    'Rock en español': [
      'Soda Stereo', 'Maná', 'Café Tacuba', 'Los Fabulosos Cadillacs',
      'Gustavo Cerati', 'Divididos', 'Caifanes', 'La Renga',
      'Rata Blanca', 'Bersuit Vergarabat',
    ],
    'Champeta y Africanos': [
      // Champeta africana (artista en Deezer con nombres picoteros costeños)
      'Champetas Africanas',
      'DJ Demoledor',
      'TheKingDeejay',
      'Champeta & Mas Naa',
      // Champeta colombiana clásica
      'Alvaro El Barbaro',
      'Elio Boom',
      'El Afinao',
      'Tom Barranquilla',
      'Charles King',
      'Louis Towers',
      'Mr. Black',
      'El Sayayin del Amor',
      // Champeta urbana / nueva generación
      'Kevin Florez',
      'Twister El Rey',
      'Young F',
      'Rey Three Latino',
      'Zaider',
      'Koffee El Kafetero',
      'Luister La Voz',
      'Keivin Ce',
      // Soukous / Rumba Congolesa (raíces africanas de la champeta)
      'Papa Wemba',
      'Koffi Olomide',
      'Tabu Ley Rochereau',
      'Diblo Dibala',
      'Awilo Longomba',
      'Mbilia Bel',
      'Sam Mangwana',
      'Orchestra Baobab',
      'Bopol Mansiamina',
      'Aurlus Mabele',
      'Franco Luambo',
      'Loketo',
      'Zaiko Langa Langa',
      'Wenge Musica',
      'Tshala Muana',
      'Fally Ipupa',
    ],
    'Pop latino': [
      'Shakira', 'Enrique Iglesias', 'Ricky Martin', 'Luis Fonsi',
      'Alejandro Sanz', 'Juanes', 'Laura Pausini', 'Thalía',
      'Gloria Estefan', 'Jennifer Lopez',
    ],
    'Crossover': [
      // Salsa
      'Grupo Niche', 'Marc Anthony', 'Gilberto Santa Rosa', 'Frankie Ruiz',
      'Jerry Rivera', 'Celia Cruz', 'Willie Colon', 'Rubén Blades',
      // Reggaetón
      'Bad Bunny', 'J Balvin', 'Daddy Yankee', 'Karol G', 'Maluma',
      'Ozuna', 'Rauw Alejandro', 'Myke Towers',
      // Bachata
      'Romeo Santos', 'Prince Royce', 'Juan Luis Guerra', 'Aventura',
      // Vallenato
      'Carlos Vives', 'Silvestre Dangond', 'Diomedes Díaz',
      'Jorge Celedón', 'Felipe Pelaez', 'Los Inquietos del Vallenato',
      // Champeta
      'Kevin Florez', 'Twister El Rey', 'Champetas Africanas',
      'Elio Boom', 'Mr. Black',
      // Rock en español
      'Soda Stereo', 'Maná', 'Café Tacuba', 'Gustavo Cerati',
      // Pop latino
      'Shakira', 'Enrique Iglesias', 'Juanes', 'Luis Fonsi',
    ],
  };

  Future<List<Song>> searchSongsByGenre(String genre) async {
    final artists = _genreArtists[genre] ?? [];
    if (artists.isEmpty) throw Exception('Género no reconocido: $genre');

    final selected = List<String>.from(artists)..shuffle(_random);
    final pool = selected.take(5).toList();

    final futures = pool.map((artist) => _fetchByArtist(artist));
    final results = await Future.wait(futures);

    final songs = results
        .expand((list) => list)
        .where((s) => s.previewUrl.isNotEmpty && !_isBadTrack(s.title))
        .toList();

    final seen = <String>{};
    final unique = songs.where((s) => seen.add(s.deezerId)).toList();

    if (unique.length < 4) {
      throw Exception('No hay suficientes canciones para $genre');
    }

    unique.shuffle(_random);
    return unique;
  }

  Future<List<Song>> _fetchByArtist(String artistName) async {
    final q = Uri.encodeQueryComponent('artist:"$artistName"');
    final uri = Uri.parse(
      'https://api.deezer.com/search?q=$q&limit=15&order=RANKING',
    );
    try {
      final response = await _client.get(uri);
      if (response.statusCode != 200) return [];
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] as List<dynamic>? ?? [];
      return data
          .map((item) => Song.fromDeezerJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  bool _isBadTrack(String title) {
    final lower = title.toLowerCase();
    return lower.contains('karaoke') ||
        lower.contains('en vivo') ||
        lower.contains('live') ||
        lower.contains('cover') ||
        lower.contains('tribute') ||
        lower.contains('instrumental') ||
        lower.contains('backing track') ||
        lower.contains('originally performed');
  }
}
