import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/track.dart';
import 'player_provider.dart';

/// Provider for the search query string.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Provider for search results — automatically fetches when query changes.
/// Includes debouncing so we don't fire a request on every keystroke.
final searchResultsProvider = FutureProvider<List<Track>>((ref) async {
  final query = ref.watch(searchQueryProvider);

  if (query.trim().isEmpty) return [];

  // Debounce: wait 400ms after the user stops typing.
  await Future.delayed(const Duration(milliseconds: 400));

  // If the query has changed during the delay, cancel this request.
  if (ref.read(searchQueryProvider) != query) return [];

  final api = ref.read(apiServiceProvider);
  return api.searchTracks(query);
});
