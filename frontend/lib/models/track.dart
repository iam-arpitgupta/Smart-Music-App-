/// Track data model — maps directly to the backend's SearchResult schema.
class Track {
  final String videoId;
  final String title;
  final String artist;
  final String? thumbnail;
  final String? duration;

  const Track({
    required this.videoId,
    required this.title,
    required this.artist,
    this.thumbnail,
    this.duration,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      videoId: json['video_id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      thumbnail: json['thumbnail'] as String?,
      duration: json['duration'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'video_id': videoId,
      'title': title,
      'artist': artist,
      'thumbnail': thumbnail,
      'duration': duration,
    };
  }
}
