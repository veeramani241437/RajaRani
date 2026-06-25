import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/room_model.dart';
import '../models/player_model.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://tvgruqjxmgisgifipxuh.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR2Z3J1cWp4bWdpc2dpZmlweHVoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIxODExMDMsImV4cCI6MjA5Nzc1NzEwM30.qfcIUscAClc-FO-AN-WGc3FrhddKZfhEA7VZfo2Uep4';

  static final SupabaseService instance = SupabaseService._internal();

  SupabaseService._internal();

  final SupabaseClient client = Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  // Generate a random 6-character room code
  String _generateRoomCode() {
    final rand = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(6, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  // Create a new game room
  Future<RoomModel> createRoom({
    required String adminUserId,
    required String adminName,
    required String adminGender,
    required int totalRounds,
  }) async {
    // 1. Generate unique room code
    final roomCode = _generateRoomCode();

    // 2. Perform fallback cleanup of rooms > 24 hours old
    try {
      await client.rpc('cleanup_old_rooms');
    } catch (_) {
      // Ignore if function fails or is missing
    }

    // 3. Create room in DB
    final roomResponse = await client.from('rooms').insert({
      'room_code': roomCode,
      'admin_id': adminUserId,
      'total_rounds': totalRounds,
      'game_state': 'LOBBY',
    }).select().single();

    final room = RoomModel.fromJson(roomResponse);

    // 4. Create the admin player in the room
    await client.from('players').insert({
      'room_id': room.id,
      'user_id': adminUserId,
      'name': adminName,
      'gender': adminGender,
      'points': 0,
      'is_revealed': false,
      'is_locked': false,
    });

    return room;
  }

  // Join an existing game room
  Future<RoomModel> joinRoom({
    required String roomCode,
    required String userId,
    required String name,
    required String gender,
  }) async {
    final cleanedCode = roomCode.trim().toUpperCase();

    // 1. Fetch room
    final roomData = await client
        .from('rooms')
        .select()
        .eq('room_code', cleanedCode)
        .maybeSingle();

    if (roomData == null) {
      throw Exception('Room not found. Please check the code.');
    }

    final room = RoomModel.fromJson(roomData);

    // 2. Check if player already exists in the room
    final existingPlayer = await client
        .from('players')
        .select()
        .eq('room_id', room.id)
        .eq('user_id', userId)
        .maybeSingle();

    if (existingPlayer == null) {
      if (room.gameState != 'LOBBY') {
        throw Exception('Game has already started in this room.');
      }

      // Check player count
      final playersList = await client
          .from('players')
          .select('id')
          .eq('room_id', room.id);
      
      if (playersList.length >= 10) {
        throw Exception('Room is full (maximum 10 players).');
      }

      // Insert new player
      await client.from('players').insert({
        'room_id': room.id,
        'user_id': userId,
        'name': name,
        'gender': gender,
        'points': 0,
        'is_revealed': false,
        'is_locked': false,
      });
    }

    return room;
  }

  // Leave room
  Future<void> leaveRoom(String roomId, String userId) async {
    await client
        .from('players')
        .delete()
        .eq('room_id', roomId)
        .eq('user_id', userId);
  }

  // Stream room updates
  Stream<RoomModel> streamRoom(String roomId) {
    return client
        .from('rooms')
        .stream(primaryKey: ['id'])
        .eq('id', roomId)
        .map((event) {
          if (event.isEmpty) {
            throw Exception('Room was deleted.');
          }
          return RoomModel.fromJson(event.first);
        });
  }

  // Stream players list sorted in ascending order of join order
  Stream<List<PlayerModel>> streamPlayers(String roomId) {
    return client
        .from('players')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .map((event) {
          final list = event.map((json) => PlayerModel.fromJson(json)).toList();
          list.sort((a, b) => a.joinOrder.compareTo(b.joinOrder));
          return list;
        });
  }

  // Reveal own card
  Future<void> revealCard(String playerId) async {
    await client
        .from('players')
        .update({'is_revealed': true})
        .eq('id', playerId);
  }

  // Start the round (shuffles and deals cards)
  Future<void> startRound(String roomId) async {
    await client.rpc('start_round', params: {'p_room_id': roomId});
  }

  // Make a suspect guess
  Future<Map<String, dynamic>> guessCard({
    required String roomId,
    required String searcherPlayerId,
    required String suspectPlayerId,
  }) async {
    final response = await client.rpc('guess_card', params: {
      'p_room_id': roomId,
      'p_searcher_player_id': searcherPlayerId,
      'p_suspect_player_id': suspectPlayerId,
    });
    return response as Map<String, dynamic>;
  }
}
