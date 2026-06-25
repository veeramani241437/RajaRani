import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/card_type.dart';
import '../models/player_model.dart';
import '../models/room_model.dart';
import '../services/supabase_service.dart';
import '../theme/game_theme.dart';
import '../widgets/game_widgets.dart';
import 'game_screen.dart';

class RoundEndScreen extends StatefulWidget {
  final String roomId;
  final String userId;

  const RoundEndScreen({
    super.key,
    required this.roomId,
    required this.userId,
  });

  @override
  State<RoundEndScreen> createState() => _RoundEndScreenState();
}

class _RoundEndScreenState extends State<RoundEndScreen> {
  StreamSubscription<RoomModel>? _roomSubscription;
  bool _isStartingNextRound = false;

  late final Stream<RoomModel> _roomStream;
  late final Stream<List<PlayerModel>> _playersStream;

  @override
  void initState() {
    super.initState();
    _roomStream = SupabaseService.instance.streamRoom(widget.roomId);
    _playersStream = SupabaseService.instance.streamPlayers(widget.roomId);
    _subscribeToRoom();
  }

  void _subscribeToRoom() {
    _roomSubscription = _roomStream.listen(
      (room) {
        if (!mounted) return;
        if (room.gameState == 'PLAYING') {
          _navigateToGame();
        }
      },
    );
  }

  void _navigateToGame() {
    _roomSubscription?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          roomId: widget.roomId,
          userId: widget.userId,
        ),
      ),
    );
  }

  void _handleNextRound() async {
    setState(() => _isStartingNextRound = true);
    try {
      await SupabaseService.instance.startRound(widget.roomId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: GameTheme.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isStartingNextRound = false);
    }
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: EmbersBackground(
        child: SafeArea(
          child: StreamBuilder<RoomModel>(
            stream: _roomStream,
            builder: (context, roomSnapshot) {
              if (!roomSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: GameTheme.woodDark));
              }

              final room = roomSnapshot.data!;
              final isAdmin = room.adminId == widget.userId;

              return StreamBuilder<List<PlayerModel>>(
                stream: _playersStream,
                builder: (context, playersSnapshot) {
                  if (!playersSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: GameTheme.woodDark));
                  }

                  final players = playersSnapshot.data!;
                  
                  // Sort players based on total points (descending)
                  final sortedPlayers = List<PlayerModel>.from(players)
                    ..sort((a, b) => b.points.compareTo(a.points));

                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header info
                        const Center(
                          child: GameShimmerText(
                            text: 'ROUND ENDED',
                            fontSize: 30,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Center(
                          child: Text(
                            'Round Scoreboard & Card Reveal',
                            style: GameTheme.bodyStyle(fontSize: 13, color: GameTheme.woodMedium),
                          ),
                        ),
                        SizedBox(height: 16.h),

                        // Scoreboard List
                        Expanded(
                          child: ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: sortedPlayers.length,
                            separatorBuilder: (_, __) => SizedBox(height: 10.h),
                            itemBuilder: (context, index) {
                              final p = sortedPlayers[index];
                              final card = p.currentCard;
                              final isMe = p.userId == widget.userId;

                              return AnimatedScorePlank(
                                player: p,
                                index: index,
                                isMe: isMe,
                                card: card,
                              );
                            },
                          ),
                        ),
                        SizedBox(height: 16.h),

                        // Admin Play button vs Wait banner
                        if (isAdmin) ...[
                          GameButton3D(
                            onTap: _isStartingNextRound ? null : _handleNextRound,
                            text: _isStartingNextRound ? 'STARTING...' : 'START NEXT ROUND',
                            color: GameTheme.orangeAccent,
                            height: 42,
                          ),
                        ] else ...[
                          Container(
                            padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                            decoration: GameTheme.boardDecoration(
                              bgCol: GameTheme.parchmentCardColor,
                              borderCol: GameTheme.woodMedium,
                              borderWidth: 1.5,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16.w,
                                  height: 16.w,
                                  child: CircularProgressIndicator(color: GameTheme.woodDark, strokeWidth: 2.5.w),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Text(
                                    'Waiting for Admin to start next round...',
                                    textAlign: TextAlign.center,
                                    style: GameTheme.bodyStyle(fontSize: 11, color: GameTheme.woodDark),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class AnimatedScorePlank extends StatefulWidget {
  final PlayerModel player;
  final int index;
  final bool isMe;
  final CardType? card;

  const AnimatedScorePlank({
    super.key,
    required this.player,
    required this.index,
    required this.isMe,
    required this.card,
  });

  @override
  State<AnimatedScorePlank> createState() => _AnimatedScorePlankState();
}

class _AnimatedScorePlankState extends State<AnimatedScorePlank> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _widthAnimation;
  late Animation<double> _scoreAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _widthAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _scoreAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Staggered entry animation based on list index
    Future.delayed(Duration(milliseconds: widget.index * 120), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getRoleAvatar(CardType? card, String gender) {
    if (card != null) {
      switch (card) {
        case CardType.king:
          return GameTheme.kingAvatar;
        case CardType.queen:
          return GameTheme.queenAvatar;
        case CardType.prince:
          return GameTheme.princeAvatar;
        case CardType.commander:
          return GameTheme.commanderAvatar;
        case CardType.minister:
          return GameTheme.ministerAvatar;
        case CardType.soldier:
          return GameTheme.soldierAvatar;
        case CardType.merchant:
          return GameTheme.merchantAvatar;
        case CardType.citizen:
          return GameTheme.citizenAvatar;
        case CardType.police:
          return GameTheme.policeAvatar;
        case CardType.thief:
          return GameTheme.thiefAvatar;
      }
    }
    return gender == 'MALE' ? GameTheme.kingAvatar : GameTheme.queenAvatar;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.player;
    final card = widget.card;
    final isMe = widget.isMe;
    final index = widget.index;

    Color borderCol = GameTheme.woodDark;
    double borderWidth = 1.5;
    Color bgCol = GameTheme.parchmentCardColor;

    if (index == 0) {
      borderCol = GameTheme.goldAccent;
      borderWidth = 2.5;
      bgCol = const Color(0xFFFFE8C5);
    } else if (isMe) {
      borderCol = GameTheme.orangeAccent;
      borderWidth = 2.0;
      bgCol = const Color(0xFFFFF5DF);
    }

    final double maxPoints = 1000.0;
    final double pointsFraction = card != null ? (card.points / maxPoints).clamp(0.0, 1.0) : 0.0;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 0.9 + (0.1 * _scoreAnimation.value);
        final opacity = _scoreAnimation.value;

        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: GameTheme.boardDecoration(
                borderRadius: 14,
                borderCol: borderCol,
                borderWidth: borderWidth,
                bgCol: bgCol,
              ).copyWith(
                boxShadow: index == 0
                    ? [
                        BoxShadow(
                          color: GameTheme.goldAccent.withOpacity(0.25 * _scoreAnimation.value),
                          blurRadius: 10,
                          spreadRadius: 1,
                        )
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
              ),
              child: Row(
                children: [
                  // Rank Shield Badge
                  Container(
                    width: 32.w,
                    height: 32.w,
                    decoration: GameTheme.boardDecoration(
                      borderRadius: 8,
                      borderCol: GameTheme.woodDark,
                      borderWidth: 1.5,
                      bgCol: GameTheme.parchmentBgColor,
                    ),
                    child: Center(
                      child: Text(
                        '#${index + 1}',
                        style: GameTheme.headerStyle(
                          fontSize: 14,
                          color: GameTheme.woodDark,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),

                  // Avatar of Role Held
                  Container(
                    width: 38.w,
                    height: 38.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: GameTheme.woodDark,
                        width: 1.5.w,
                      ),
                      image: DecorationImage(
                        image: AssetImage(
                          _getRoleAvatar(card, p.gender),
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),

                  // Name, Card, and Progress Bar
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                p.name + (isMe ? ' (You)' : ''),
                                style: GameTheme.bodyStyle(
                                  fontSize: 14,
                                  color: GameTheme.woodDark,
                                  weight: isMe ? FontWeight.w900 : FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (card != null && card.points > 0) ...[
                              SizedBox(width: 6.w),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                                decoration: GameTheme.boardDecoration(
                                  bgCol: GameTheme.greenAccent.withOpacity(0.12),
                                  borderCol: GameTheme.greenAccent,
                                  borderRadius: 6,
                                  borderWidth: 1,
                                ),
                                child: Text(
                                  '+${card.points}',
                                  style: GameTheme.headerStyle(
                                    color: GameTheme.greenAccent,
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (card != null) ...[
                          Text(
                            'Role: ${card.englishName}',
                            style: GameTheme.bodyStyle(
                              fontSize: 10,
                              color: card == CardType.thief
                                  ? GameTheme.redAccent
                                  : card == CardType.king
                                      ? GameTheme.goldAccent
                                      : GameTheme.woodMedium,
                              weight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 5.h),
                          // Clash Quest Animated Progress Bar
                          Container(
                            height: 6.h,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: GameTheme.woodDark.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: pointsFraction * _widthAnimation.value,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        GameTheme.orangeAccent,
                                        GameTheme.goldAccent,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(4.r),
                                    boxShadow: [
                                      BoxShadow(
                                        color: GameTheme.orangeAccent.withOpacity(0.3),
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: 12.w),

                  // Total accumulated Score
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Total',
                        style: GameTheme.bodyStyle(
                          fontSize: 9,
                          color: GameTheme.woodLight,
                        ),
                      ),
                      Text(
                        '${p.points} pts',
                        style: GameTheme.headerStyle(
                          fontSize: 14,
                          color: GameTheme.woodDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
