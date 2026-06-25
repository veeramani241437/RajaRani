import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/player_model.dart';
import '../models/room_model.dart';
import '../services/supabase_service.dart';
import '../theme/game_theme.dart';
import '../widgets/game_widgets.dart';
import 'game_screen.dart';

class LobbyScreen extends StatefulWidget {
  final String roomId;
  final String roomCode;
  final String userId;

  const LobbyScreen({
    super.key,
    required this.roomId,
    required this.roomCode,
    required this.userId,
  });

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> with TickerProviderStateMixin {
  StreamSubscription<RoomModel>? _roomSubscription;
  bool _isStarting = false;

  late final Stream<RoomModel> _roomStream;
  late final Stream<List<PlayerModel>> _playersStream;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _roomStream = SupabaseService.instance.streamRoom(widget.roomId);
    _playersStream = SupabaseService.instance.streamPlayers(widget.roomId);
    _subscribeToRoom();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutBack),
    );

    _entranceController.forward();
  }

  void _subscribeToRoom() {
    _roomSubscription = _roomStream.listen(
      (room) {
        if (!mounted) return;
        if (room.gameState == 'PLAYING') {
          _navigateToGame();
        }
      },
      onError: (err) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection error: $err'),
            backgroundColor: GameTheme.redAccent,
          ),
        );
        Navigator.pop(context);
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

  void _handleStartGame() async {
    setState(() => _isStarting = true);
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
      if (mounted) setState(() => _isStarting = false);
    }
  }

  void _handleQuit() async {
    try {
      await SupabaseService.instance.leaveRoom(widget.roomId, widget.userId);
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _pulseController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  Widget _buildLobbyPlayerRow(PlayerModel p, int index, bool isMe, bool isPlayerAdmin) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: GameTheme.boardDecoration(
        borderRadius: 12,
        borderWidth: 1.5,
        bgCol: isMe ? GameTheme.goldAccent.withOpacity(0.08) : GameTheme.parchmentCardColor,
        borderCol: isMe ? GameTheme.goldAccent : GameTheme.woodDark.withOpacity(0.5),
      ),
      child: Row(
        children: [
          // Avatar with Admin crown
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (isMe)
                Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: GameTheme.goldAccent.withOpacity(0.35),
                        blurRadius: 8.r,
                        spreadRadius: 1.w,
                      ),
                    ],
                  ),
                ),
              SizedBox(
                width: 48.w,
                height: 48.w,
                child: Image.asset(
                  p.gender == 'MALE' ? GameTheme.kingAvatar : GameTheme.queenAvatar,
                  fit: BoxFit.contain,
                ),
              ),
              if (isPlayerAdmin)
                Positioned(
                  top: -8.h,
                  left: -4.w,
                  child: Transform.rotate(
                    angle: -0.15,
                    child: Text('👑', style: TextStyle(fontSize: 14.sp)),
                  ),
                ),
            ],
          ),
          SizedBox(width: 14.w),

          // Player Name
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

          // Status Badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: GameTheme.boardDecoration(
              bgCol: isPlayerAdmin ? const Color(0xFFFFF9C4) : const Color(0xFFE8F5E9),
              borderCol: isPlayerAdmin ? GameTheme.goldAccent : GameTheme.greenAccent,
              borderRadius: 8,
              borderWidth: 1.2,
            ),
            child: Text(
              isPlayerAdmin ? 'HOST' : 'READY',
              style: GameTheme.headerStyle(
                color: isPlayerAdmin ? GameTheme.woodDark : GameTheme.greenAccent,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _handleQuit();
        return false;
      },
      child: Scaffold(
        body: EmbersBackground(
          child: SafeArea(
            child: StreamBuilder<RoomModel>(
              stream: _roomStream,
              builder: (context, roomSnapshot) {
                if (roomSnapshot.hasError) {
                  return Center(
                    child: Container(
                      padding: EdgeInsets.all(12.w),
                      margin: EdgeInsets.all(20.w),
                      decoration: GameTheme.boardDecoration(bgCol: GameTheme.parchmentCardColor),
                      child: Text(
                        'Error: ${roomSnapshot.error}',
                        style: GameTheme.bodyStyle(fontSize: 14, color: GameTheme.redAccent),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
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

                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h), // Shrunk padding
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Navigation bar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GameBounce(
                                onTap: _handleQuit,
                                child: Container(
                                  padding: EdgeInsets.all(6.w),
                                  decoration: GameTheme.boardDecoration(
                                    borderRadius: 8,
                                    borderWidth: 1.2,
                                  ),
                                  child: Icon(Icons.arrow_back, color: GameTheme.woodDark, size: 18.sp),
                                ),
                              ),
                              const GameShimmerText(
                                text: 'LOBBY ROOM',
                                fontSize: 22, // Shrunk font size
                              ),
                              SizedBox(width: 32.w),
                            ],
                          ),
                          SizedBox(height: 14.h),

                          // Wooden Room Code Display Plate
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                            decoration: GameTheme.boardDecoration(),
                            child: Column(
                              children: [
                                Text(
                                  'ROOM CODE',
                                  style: GameTheme.bodyStyle(fontSize: 12, color: GameTheme.woodMedium),
                                ),
                                SizedBox(height: 4.h),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      widget.roomCode,
                                      style: GameTheme.headerStyle(
                                        fontSize: 28, // Shrunk size
                                        color: GameTheme.orangeAccent,
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    GameBounce(
                                      onTap: () {
                                        Clipboard.setData(ClipboardData(text: widget.roomCode));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Room code copied to clipboard!',
                                              style: GameTheme.bodyStyle(fontSize: 13, color: Colors.white),
                                            ),
                                            backgroundColor: GameTheme.woodDark,
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: EdgeInsets.all(6.w),
                                        decoration: GameTheme.buttonDecoration(
                                          color: GameTheme.goldAccent,
                                          borderRadius: 6,
                                          shadowOffset: 1.5,
                                        ),
                                        child: Icon(Icons.copy, color: GameTheme.woodDark, size: 16.sp),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 14.h),

                          // Player Count Indicator Bar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Players List',
                                style: GameTheme.headerStyle(fontSize: 14, color: GameTheme.woodDark),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                decoration: GameTheme.boardDecoration(
                                  borderRadius: 6,
                                  borderWidth: 1.2,
                                  bgCol: players.length >= 4
                                      ? GameTheme.greenAccent.withOpacity(0.1)
                                      : GameTheme.orangeAccent.withOpacity(0.1),
                                  borderCol: players.length >= 4 ? GameTheme.greenAccent : GameTheme.orangeAccent,
                                ),
                                child: Text(
                                  '${players.length}/10 Players',
                                  style: GameTheme.headerStyle(
                                    fontSize: 11,
                                    color: players.length >= 4 ? GameTheme.greenAccent : GameTheme.orangeAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),

                          // Scrollable Row-wise List of players
                          Expanded(
                            child: ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              itemCount: players.length,
                              itemBuilder: (context, index) {
                                final p = players[index];
                                final isPlayerAdmin = room.adminId == p.userId;
                                final isMe = p.userId == widget.userId;

                                return _buildLobbyPlayerRow(p, index, isMe, isPlayerAdmin);
                              },
                            ),
                          ),
                          SizedBox(height: 12.h),

                          // Bottom CTA Panel
                          if (isAdmin) ...[
                            if (players.length < 4)
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(8.w),
                                decoration: GameTheme.boardDecoration(
                                  bgCol: GameTheme.orangeAccent.withOpacity(0.1),
                                  borderCol: GameTheme.orangeAccent,
                                  borderWidth: 1.0,
                                  borderRadius: 8,
                                ),
                                child: Text(
                                  'Min 4 players needed to start the game',
                                  textAlign: TextAlign.center,
                                  style: GameTheme.bodyStyle(fontSize: 11, color: GameTheme.orangeAccent),
                                ),
                              )
                            else
                              ScaleTransition(
                                scale: _pulseAnimation,
                                child: Text(
                                  '👉 START GAME IS READY! 👈',
                                  style: GameTheme.headerStyle(color: GameTheme.greenAccent, fontSize: 12),
                                ),
                              ),
                            SizedBox(height: 8.h),
                            GameButton3D(
                              onTap: players.length >= 4 && !_isStarting ? _handleStartGame : null,
                              text: _isStarting ? 'STARTING...' : 'START GAME',
                              color: GameTheme.greenAccent,
                              height: 42, // Shorter button height
                            ),
                          ] else ...[
                            Container(
                              padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
                              decoration: GameTheme.boardDecoration(
                                bgCol: GameTheme.parchmentCardColor,
                                borderCol: GameTheme.woodMedium,
                                borderWidth: 1.2,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 14.w,
                                    height: 14.w,
                                    child: CircularProgressIndicator(color: GameTheme.woodDark, strokeWidth: 2.0.w),
                                  ),
                                  SizedBox(width: 10.w),
                                  Expanded(
                                    child: Text(
                                      'Waiting for Host to start game...',
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
                    ),
                  ),
                );
              },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
