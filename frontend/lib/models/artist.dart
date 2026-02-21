/// Model for an artist from YouTube Music.
class Artist {
  final String browseId;
  final String name;
  final String? thumbnail;
  final String? subscribers;

  const Artist({
    required this.browseId,
    required this.name,
    this.thumbnail,
    this.subscribers,
  });

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(
      browseId: json['browse_id'] ?? '',
      name: json['name'] ?? '',
      thumbnail: json['thumbnail'],
      subscribers: json['subscribers'],
    );
  }
}
