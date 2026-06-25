import 'card_type.dart';

class RoomModel {
  final String id;
  final String roomCode;
  final String adminId; // UUID
  final int totalRounds;
  final int currentRound;
  final String gameState; // 'LOBBY', 'PLAYING', 'ROUND_END', 'FINISHED'
  final CardType? searcherCard;
  final CardType? targetCard;
  final DateTime createdAt;

  RoomModel({
    required this.id,
    required this.roomCode,
    required this.adminId,
    required this.totalRounds,
    required this.currentRound,
    required this.gameState,
    this.searcherCard,
    this.targetCard,
    required this.createdAt,
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      id: json['id'] as String,
      roomCode: json['room_code'] as String,
      adminId: json['admin_id'] as String,
      totalRounds: json['total_rounds'] as int? ?? 5,
      currentRound: json['current_round'] as int? ?? 1,
      gameState: json['game_state'] as String? ?? 'LOBBY',
      searcherCard: json['searcher_card'] != null
          ? CardType.fromDbValue(json['searcher_card'] as String)
          : null,
      targetCard: json['target_card'] != null
          ? CardType.fromDbValue(json['target_card'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_code': roomCode,
      'admin_id': adminId,
      'total_rounds': totalRounds,
      'current_round': currentRound,
      'game_state': gameState,
      'searcher_card': searcherCard?.dbValue,
      'target_card': targetCard?.dbValue,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
