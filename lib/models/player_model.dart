import 'card_type.dart';

class PlayerModel {
  final String id;
  final String roomId;
  final String userId;
  final String name;
  final String gender; // 'MALE' or 'FEMALE'
  final int points;
  final CardType? currentCard;
  final bool isRevealed;
  final bool isLocked;
  final int joinOrder;
  final DateTime joinedAt;

  PlayerModel({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.name,
    required this.gender,
    required this.points,
    this.currentCard,
    required this.isRevealed,
    required this.isLocked,
    required this.joinOrder,
    required this.joinedAt,
  });

  factory PlayerModel.fromJson(Map<String, dynamic> json) {
    return PlayerModel(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      gender: json['gender'] as String,
      points: json['points'] as int? ?? 0,
      currentCard: json['current_card'] != null
          ? CardType.fromDbValue(json['current_card'] as String)
          : null,
      isRevealed: json['is_revealed'] as bool? ?? false,
      isLocked: json['is_locked'] as bool? ?? false,
      joinOrder: json['join_order'] as int? ?? 0,
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_id': roomId,
      'user_id': userId,
      'name': name,
      'gender': gender,
      'points': points,
      'current_card': currentCard?.dbValue,
      'is_revealed': isRevealed,
      'is_locked': isLocked,
      'join_order': joinOrder,
      'joined_at': joinedAt.toIso8601String(),
    };
  }
}
