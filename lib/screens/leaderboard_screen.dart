import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/player_model.dart';
import '../services/supabase_service.dart';
import '../theme/game_theme.dart';
import '../widgets/game_widgets.dart';

class ConfettiParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double speed;
  Color color;
  double rotation;
  double rotationSpeed;
  double alpha;
  double decay;
  bool isExplosion;
  bool isStar;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.speed,
    required this.color,
    required this.rotation,
    required this.rotationSpeed,
    required this.alpha,
    required this.decay,
    required this.isExplosion,
    required this.isStar,
  });
}

class LeaderboardScreen extends StatefulWidget {
  final String roomId;
  final String userId;

  const LeaderboardScreen({
    super.key,
    required this.roomId,
    required this.userId,
  });

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  late AnimationController _confettiController;
  final List<ConfettiParticle> _confetti = [];
  final Random _random = Random();
  int _frameCount = 0;

  final List<Color> _confettiColors = [
    Colors.redAccent,
    Colors.blueAccent,
    Colors.greenAccent,
    Colors.yellowAccent,
    Colors.pinkAccent,
    Colors.orangeAccent,
    GameTheme.goldAccent,
  ];

  late final Stream<List<PlayerModel>> _playersStream;

  @override
  void initState() {
    super.initState();
    _playersStream = SupabaseService.instance.streamPlayers(widget.roomId);
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    // Generate initial falling confetti particles
    for (int i = 0; i < 40; i++) {
      _confetti.add(_createConfetti(isInitial: true));
    }
  }

  ConfettiParticle _createConfetti({bool isInitial = false}) {
    return ConfettiParticle(
      x: _random.nextDouble(),
      y: isInitial ? _random.nextDouble() * -1.0 : -0.1,
      vx: 0.0,
      vy: _random.nextDouble() * 0.01 + 0.005,
      size: _random.nextDouble() * 6 + 5,
      speed: _random.nextDouble() * 0.05 + 0.02,
      color: _confettiColors[_random.nextInt(_confettiColors.length)],
      rotation: _random.nextDouble() * pi * 2,
      rotationSpeed: (_random.nextDouble() - 0.5) * 2.0,
      alpha: 1.0,
      decay: 0.0,
      isExplosion: false,
      isStar: _random.nextBool(),
    );
  }

  void _triggerExplosion(double centerX, double centerY) {
    final List<Color> colors = [
      const Color(0xFFFFD700), // Royal Gold
      const Color(0xFFFF5722), // Orange
      const Color(0xFFE91E63), // Pink
      const Color(0xFF4CAF50), // Green
      const Color(0xFF00BCD4), // Cyan
      Colors.white,
    ];
    for (int i = 0; i < 25; i++) {
      final angle = _random.nextDouble() * pi * 2;
      final speed = _random.nextDouble() * 0.015 + 0.008;
      _confetti.add(ConfettiParticle(
        x: centerX,
        y: centerY,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed - 0.003, // slight upward push
        size: _random.nextDouble() * 8 + 5,
        speed: speed,
        color: colors[_random.nextInt(colors.length)],
        rotation: _random.nextDouble() * pi * 2,
        rotationSpeed: (_random.nextDouble() - 0.5) * 6.0,
        alpha: 1.0,
        decay: _random.nextDouble() * 0.015 + 0.01,
        isExplosion: true,
        isStar: _random.nextBool(),
      ));
    }
  }

  void _updateConfetti() {
    _frameCount++;
    if (_frameCount % 45 == 0) {
      // Trigger a cracker explosion in the upper 60% of the screen
      _triggerExplosion(
        _random.nextDouble() * 0.8 + 0.1,
        _random.nextDouble() * 0.4 + 0.1,
      );
    }

    final toRemove = <ConfettiParticle>[];
    for (int i = 0; i < _confetti.length; i++) {
      final c = _confetti[i];
      if (c.isExplosion) {
        c.x += c.vx;
        c.y += c.vy;
        c.vy += 0.0003; // gravity
        c.vx *= 0.95; // drag
        c.alpha -= c.decay;
        c.rotation += c.rotationSpeed * 0.02;
        if (c.alpha <= 0) {
          toRemove.add(c);
        }
      } else {
        c.y += c.speed * 0.003; // slowly falling down
        c.rotation += c.rotationSpeed * 0.005;
        // Recycle offscreen
        if (c.y > 1.1) {
          _confetti[i] = _createConfetti();
        }
      }
    }
    _confetti.removeWhere((p) => toRemove.contains(p));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Widget _buildPodiumPillar({
    required PlayerModel player,
    required int rank,
    required double height,
    required Color pillarColor,
    required String badge,
  }) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Avatar Stack
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: rank == 1 ? 52.w : 44.w,
                height: rank == 1 ? 52.w : 44.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: pillarColor, width: 2.5.w),
                  image: DecorationImage(
                    image: AssetImage(
                      player.gender == 'MALE' ? GameTheme.kingAvatar : GameTheme.queenAvatar,
                    ),
                    fit: BoxFit.cover,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: pillarColor.withOpacity(0.3),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              Positioned(
                top: rank == 1 ? -22.h : -16.h,
                child: Text(
                  badge,
                  style: TextStyle(fontSize: rank == 1 ? 24.sp : 18.sp),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),

          // Player identity info
          Text(
            player.name,
            style: GameTheme.headerStyle(
              fontSize: rank == 1 ? 13 : 11,
              color: GameTheme.woodDark,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          Text(
            '${player.points} pts',
            style: GameTheme.bodyStyle(
              fontSize: rank == 1 ? 11 : 9,
              color: GameTheme.orangeAccent,
              weight: FontWeight.w900,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 6.h),

          // Pillar Base
          Container(
            width: 72.w,
            height: height,
            decoration: GameTheme.boardDecoration(
              borderRadius: 8,
              borderCol: GameTheme.woodDark,
              borderWidth: 2.w,
              bgCol: pillarColor.withOpacity(0.18),
            ).copyWith(
              boxShadow: [
                BoxShadow(
                  color: pillarColor.withOpacity(0.08),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: GameTheme.headerStyle(
                  fontSize: rank == 1 ? 22 : 16,
                  color: GameTheme.woodDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodium(List<PlayerModel> sortedPlayers) {
    final count = sortedPlayers.length;
    final player1 = count > 0 ? sortedPlayers[0] : null;
    final player2 = count > 1 ? sortedPlayers[1] : null;
    final player3 = count > 2 ? sortedPlayers[2] : null;

    return Container(
      height: 230.h,
      padding: EdgeInsets.symmetric(horizontal: 6.w),
      decoration: GameTheme.boardDecoration(
        borderRadius: 16,
        borderWidth: 2.w,
        borderCol: GameTheme.woodMedium.withOpacity(0.5),
        bgCol: GameTheme.parchmentCardColor.withOpacity(0.6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 2nd Place Silver (Left)
          if (player2 != null)
            _buildPodiumPillar(
              player: player2,
              rank: 2,
              height: 68.h,
              pillarColor: Colors.grey.shade400,
              badge: '🥈',
            )
          else
            const Spacer(),

          // 1st Place Gold (Center - Tallest)
          if (player1 != null)
            _buildPodiumPillar(
              player: player1,
              rank: 1,
              height: 92.h,
              pillarColor: GameTheme.goldAccent,
              badge: '👑',
            )
          else
            const Spacer(),

          // 3rd Place Bronze (Right)
          if (player3 != null)
            _buildPodiumPillar(
              player: player3,
              rank: 3,
              height: 48.h,
              pillarColor: Colors.orange.shade300,
              badge: '🥉',
            )
          else
            const Spacer(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Standard Embers & Parchment Background
          Positioned.fill(
            child: EmbersBackground(
              child: const SizedBox.shrink(),
            ),
          ),
          // Falling Confetti Animation Layer
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _confettiController,
              builder: (context, child) {
                _updateConfetti();
                return CustomPaint(
                  painter: ConfettiPainter(particles: _confetti),
                );
              },
            ),
          ),
          // Interactive Foreground Content
          Positioned.fill(
            child: SafeArea(
              child: StreamBuilder<List<PlayerModel>>(
                stream: _playersStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: GameTheme.woodDark));
                  }

                  final players = snapshot.data!;
                  
                  // Sort players by final points descending
                  final sortedPlayers = List<PlayerModel>.from(players)
                    ..sort((a, b) => b.points.compareTo(a.points));

                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: 10.h),
                        const Center(
                          child: GameShimmerText(
                            text: 'VICTORY BANNER',
                            fontSize: 30,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Center(
                          child: Text(
                            'Here is the final champion podium standings!',
                            style: GameTheme.bodyStyle(fontSize: 12, color: GameTheme.woodMedium),
                          ),
                        ),
                        SizedBox(height: 16.h),

                        // Animated Podium Layout
                        _buildPodium(sortedPlayers),
                        SizedBox(height: 16.h),

                        // Scrollable standings list for all other ranks
                        Expanded(
                          child: ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: sortedPlayers.length,
                            separatorBuilder: (_, __) => SizedBox(height: 8.h),
                            itemBuilder: (context, index) {
                              final p = sortedPlayers[index];
                              final isMe = p.userId == widget.userId;

                              // Decide rank-specific wood panel highlights
                              Color borderCol = GameTheme.woodDark;
                              double borderWidth = 1.5;
                              Color bgCol = GameTheme.parchmentCardColor;
                              String rankBadgeText = '#${index + 1}';

                              if (index == 0) {
                                borderCol = GameTheme.goldAccent;
                                borderWidth = 2.5;
                                bgCol = const Color(0xFFFFE8C5);
                                rankBadgeText = '🥇';
                              } else if (index == 1) {
                                borderCol = Colors.grey.shade400;
                                borderWidth = 2.0;
                                bgCol = Colors.grey.shade400.withOpacity(0.06);
                                rankBadgeText = '🥈';
                              } else if (index == 2) {
                                borderCol = Colors.orange.shade300;
                                borderWidth = 2.0;
                                bgCol = Colors.orange.shade300.withOpacity(0.06);
                                rankBadgeText = '🥉';
                              } else if (isMe) {
                                borderCol = GameTheme.orangeAccent;
                                borderWidth = 2.0;
                                bgCol = const Color(0xFFFFF5DF);
                              }

                              return Container(
                                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                                decoration: GameTheme.boardDecoration(
                                  borderRadius: 12,
                                  borderCol: borderCol,
                                  borderWidth: borderWidth,
                                  bgCol: bgCol,
                                ),
                                child: Row(
                                  children: [
                                    // Placement rank
                                    Container(
                                      width: 32.w,
                                      height: 32.w,
                                      alignment: Alignment.center,
                                      child: Text(
                                        rankBadgeText,
                                        style: TextStyle(fontSize: 16.sp),
                                      ),
                                    ),
                                    SizedBox(width: 8.w),

                                    // Avatar gender
                                    Container(
                                      width: 32.w,
                                      height: 32.w,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: GameTheme.woodDark, width: 1.5.w),
                                        image: DecorationImage(
                                          image: AssetImage(
                                            p.gender == 'MALE' ? GameTheme.kingAvatar : GameTheme.queenAvatar,
                                          ),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12.w),

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

                                    // Accumulated Points
                                    Text(
                                      '${p.points} pts',
                                      style: GameTheme.headerStyle(
                                        fontSize: 14,
                                        color: GameTheme.woodDark,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: 16.h),

                        // Back to Home Button
                        GameButton3D(
                          onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
                          text: 'RETURN TO HOME',
                          color: GameTheme.orangeAccent,
                          height: 42,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;
  ConfettiPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final posX = p.x * size.width;
      final posY = p.y * size.height;

      canvas.save();
      canvas.translate(posX, posY);
      canvas.rotate(p.rotation);

      paint.color = p.color.withOpacity(p.alpha.clamp(0.0, 1.0));

      if (p.isStar) {
        // Draw star path
        final path = Path();
        final double outerRadius = p.size;
        final double innerRadius = p.size * 0.4;
        final int points = 5;
        double angle = -pi / 2;
        final double increment = pi / points;

        path.moveTo(cos(angle) * outerRadius, sin(angle) * outerRadius);
        for (int i = 0; i < points * 2; i++) {
          angle += increment;
          final double r = i.isEven ? innerRadius : outerRadius;
          path.lineTo(cos(angle) * r, sin(angle) * r);
        }
        path.close();
        canvas.drawPath(path, paint);
      } else if (p.isExplosion) {
        // Draw circular cracker sparkle
        canvas.drawCircle(Offset.zero, p.size * 0.4, paint);
      } else {
        // Draw rectangular confetti piece
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6), paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
