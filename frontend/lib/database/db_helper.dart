import 'package:sqflite/sqflite.dart';
import '../models/track.dart';

/// Local SQLite database helper for favorites and playlists.
///
/// Tables:
///   - favorites (video_id PK, title, artist, thumbnail)
///   - playlists (id INTEGER PK, name TEXT)
///   - playlist_items (playlist_id INTEGER, video_id TEXT)
class DbHelper {
  static final DbHelper instance = DbHelper._();
  DbHelper._();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = '${await getDatabasesPath()}/music_app.db';

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE favorites (
            video_id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            artist TEXT NOT NULL,
            thumbnail TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE playlists (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE playlist_items (
            playlist_id INTEGER NOT NULL,
            video_id TEXT NOT NULL,
            title TEXT NOT NULL,
            artist TEXT NOT NULL,
            thumbnail TEXT,
            PRIMARY KEY (playlist_id, video_id),
            FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE
          )
        ''');
      },
    );
  }

  // ─── Favorites ──────────────────────────────────────────────

  Future<void> addFavorite(Track track) async {
    final db = await database;
    await db.insert(
      'favorites',
      {
        'video_id': track.videoId,
        'title': track.title,
        'artist': track.artist,
        'thumbnail': track.thumbnail,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeFavorite(String videoId) async {
    final db = await database;
    await db.delete('favorites', where: 'video_id = ?', whereArgs: [videoId]);
  }

  Future<bool> isFavorite(String videoId) async {
    final db = await database;
    final result = await db.query(
      'favorites',
      where: 'video_id = ?',
      whereArgs: [videoId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<List<Track>> getFavorites() async {
    final db = await database;
    final results = await db.query('favorites');
    return results
        .map((row) => Track(
              videoId: row['video_id'] as String,
              title: row['title'] as String,
              artist: row['artist'] as String,
              thumbnail: row['thumbnail'] as String?,
            ))
        .toList();
  }

  // ─── Playlists ──────────────────────────────────────────────

  Future<int> createPlaylist(String name) async {
    final db = await database;
    return db.insert('playlists', {'name': name});
  }

  Future<List<Map<String, dynamic>>> getPlaylists() async {
    final db = await database;
    return db.query('playlists');
  }

  Future<void> deletePlaylist(int playlistId) async {
    final db = await database;
    await db.delete('playlists', where: 'id = ?', whereArgs: [playlistId]);
    await db.delete('playlist_items', where: 'playlist_id = ?', whereArgs: [playlistId]);
  }

  Future<void> addToPlaylist(int playlistId, Track track) async {
    final db = await database;
    await db.insert(
      'playlist_items',
      {
        'playlist_id': playlistId,
        'video_id': track.videoId,
        'title': track.title,
        'artist': track.artist,
        'thumbnail': track.thumbnail,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<Track>> getPlaylistItems(int playlistId) async {
    final db = await database;
    final results = await db.query(
      'playlist_items',
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
    );
    return results
        .map((row) => Track(
              videoId: row['video_id'] as String,
              title: row['title'] as String,
              artist: row['artist'] as String,
              thumbnail: row['thumbnail'] as String?,
            ))
        .toList();
  }
}
