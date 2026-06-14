class Song {
  final String deezerId;
  final String title;
  final String artist;
  final String previewUrl;
  final String coverUrl;

  const Song({
    required this.deezerId,
    required this.title,
    required this.artist,
    required this.previewUrl,
    required this.coverUrl,
  });

  factory Song.fromDeezerJson(Map<String, dynamic> json) {
    final artist = json['artist'] as Map<String, dynamic>? ?? {};
    final album = json['album'] as Map<String, dynamic>? ?? {};
    return Song(
      deezerId: '${json['id']}',
      title: '${json['title'] ?? ''}',
      artist: '${artist['name'] ?? ''}',
      previewUrl: '${json['preview'] ?? ''}',
      coverUrl: '${album['cover_medium'] ?? ''}',
    );
  }

  Map<String, dynamic> toMap() => {
        'deezerId': deezerId,
        'title': title,
        'artist': artist,
        'previewUrl': previewUrl,
        'coverUrl': coverUrl,
      };

  factory Song.fromMap(Map<String, dynamic> map) => Song(
        deezerId: '${map['deezerId']}',
        title: '${map['title']}',
        artist: '${map['artist']}',
        previewUrl: '${map['previewUrl']}',
        coverUrl: '${map['coverUrl'] ?? ''}',
      );
}
