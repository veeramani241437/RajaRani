import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/card_type.dart';
import '../models/player_model.dart';
import '../models/room_model.dart';
import '../services/supabase_service.dart';
import '../theme/game_theme.dart';
import '../widgets/game_widgets.dart';
import 'round_end_screen.dart';
import 'leaderboard_screen.dart';

class GameScreen extends StatefulWidget {
  final String roomId;
  final String userId;

  const GameScreen({
    super.key,
    required this.roomId,
    required this.userId,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  // Flip & Squash/Stretch Animation Controller
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _tiltAnimation;
  late Animation<double> _liftAnimation;

  // Specular Sheen Animation
  late AnimationController _sheenController;
  late Animation<double> _sheenAnimation;

  // Reveal Particles
  final List<GuessParticle> _revealParticles = [];
  AnimationController? _revealParticleController;

  // Pulse Glow Animation (For Mystery Card)
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Screen entrance animations
  late AnimationController _entranceController;
  late Animation<double> _entranceFadeAnimation;
  late Animation<Offset> _entranceSlideAnimation;

  StreamSubscription<RoomModel>? _roomSubscription;
  bool _isGuessing = false;
  bool _localRevealed = false;

  late final Stream<RoomModel> _roomStream;
  late final Stream<List<PlayerModel>> _playersStream;

  @override
  void initState() {
    super.initState();
    _roomStream = SupabaseService.instance.streamRoom(widget.roomId);
    _playersStream = SupabaseService.instance.streamPlayers(widget.roomId);

    // 3D Card Flip + Squash/Stretch setup
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _flipController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeInOut),
      ),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.93).chain(CurveTween(curve: Curves.easeOut)),
        weight: 25.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.93, end: 1.08).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 55.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 20.0,
      ),
    ]).animate(_flipController);

    // Z-rotation tilt during flip
    _tiltAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 0.06).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.06, end: -0.04).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.04, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 25.0,
      ),
    ]).animate(_flipController);

    // Y offset lift off table with slight bounce landing
    _liftAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -16.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -16.0, end: 0.0).chain(CurveTween(curve: Curves.bounceOut)),
        weight: 60.0,
      ),
    ]).animate(_flipController);

    // Specular Sheen setup
    _sheenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _sheenAnimation = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _sheenController, curve: Curves.easeInOut),
    );

    // Pulse Glow setup
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 4, end: 12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Screen entrance animations
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _entranceFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
    );
    _entranceSlideAnimation = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutBack),
    );
    _entranceController.forward();

    _subscribeToRoomState();
  }

  void _subscribeToRoomState() {
    _roomSubscription = _roomStream.listen(
      (room) {
        if (!mounted) return;
        if (room.gameState == 'ROUND_END') {
          _roomSubscription?.cancel();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => RoundEndScreen(
                roomId: widget.roomId,
                userId: widget.userId,
              ),
            ),
          );
        } else if (room.gameState == 'FINISHED') {
          _roomSubscription?.cancel();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => LeaderboardScreen(
                roomId: widget.roomId,
                userId: widget.userId,
              ),
            ),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    _pulseController.dispose();
    _sheenController.dispose();
    _entranceController.dispose();
    _revealParticleController?.dispose();
    _roomSubscription?.cancel();
    super.dispose();
  }

  void _handleRevealCard(String playerId) async {
    if (_localRevealed) return;
    
    // Trigger local flip animation first for instant tactile response
    setState(() => _localRevealed = true);
    _flipController.forward(from: 0.0).then((_) {
      _sheenController.forward(from: 0.0);
      _triggerRevealParticles();
    });

    try {
      await SupabaseService.instance.revealCard(playerId);
    } catch (e) {
      // Backout on error
      if (mounted) {
        setState(() => _localRevealed = false);
        _flipController.reverse();
      }
    }
  }

  void _triggerRevealParticles() {
    _revealParticles.clear();
    final random = Random();
    final List<Color> colors = [
      const Color(0xFFFFD700), // Royal Gold
      const Color(0xFFE5A623), // Warm Gold
      const Color(0xFFD35400), // Rust Orange
      Colors.white,
    ];
    for (int i = 0; i < 20; i++) {
      final angle = random.nextDouble() * pi * 2;
      final speed = random.nextDouble() * 5 + 3;
      _revealParticles.add(GuessParticle(
        x: 0,
        y: 0,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed - 1.5, // initial upward tendency
        size: random.nextDouble() * 7 + 4,
        rotation: random.nextDouble() * pi * 2,
        rotationSpeed: (random.nextDouble() - 0.5) * 5,
        color: colors[random.nextInt(colors.length)],
        isStar: random.nextBool(),
      ));
    }

    _revealParticleController?.dispose();
    _revealParticleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addListener(() {
        for (var p in _revealParticles) {
          p.x += p.vx;
          p.y += p.vy;
          p.vy += 0.12; // gravity
          p.vx *= 0.95; // drag
          p.rotation += p.rotationSpeed * 0.05;
        }
        if (mounted) setState(() {});
      });
    _revealParticleController!.forward();
  }

  void _confirmGuess(PlayerModel me, PlayerModel suspect, RoomModel room) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: EdgeInsets.all(20.w),
            decoration: GameTheme.boardDecoration(
              borderRadius: 20,
              borderCol: GameTheme.woodDark,
              borderWidth: 3.5,
              bgCol: GameTheme.parchmentCardColor,
            ).copyWith(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 15,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Accusation Hammer Icon
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: GameTheme.orangeAccent.withOpacity(0.12),
                    border: Border.all(color: GameTheme.orangeAccent, width: 2.w),
                  ),
                  child: Icon(Icons.gavel, color: GameTheme.orangeAccent, size: 28.sp),
                ),
                SizedBox(height: 14.h),
                // Title
                Text(
                  'Accuse Player',
                  style: GameTheme.headerStyle(fontSize: 18, color: GameTheme.woodDark),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12.h),
                // Dialogue content
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: GameTheme.bodyStyle(fontSize: 13, color: GameTheme.woodMedium, weight: FontWeight.normal),
                    children: [
                      const TextSpan(text: 'Are you sure you want to suspect that '),
                      TextSpan(
                        text: suspect.name,
                        style: GameTheme.bodyStyle(fontSize: 13, color: GameTheme.woodDark, weight: FontWeight.bold),
                      ),
                      const TextSpan(text: ' holds the '),
                      TextSpan(
                        text: '${room.targetCard?.englishName}',
                        style: GameTheme.bodyStyle(fontSize: 13, color: GameTheme.orangeAccent, weight: FontWeight.bold),
                      ),
                      const TextSpan(text: '?\n\nSuspect: '),
                      TextSpan(
                        text: suspect.name,
                        style: GameTheme.bodyStyle(fontSize: 13, color: GameTheme.woodDark, weight: FontWeight.bold),
                      ),
                      const TextSpan(text: '\nTarget Card: '),
                      TextSpan(
                        text: room.targetCard?.englishName ?? '',
                        style: GameTheme.bodyStyle(fontSize: 13, color: GameTheme.orangeAccent, weight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20.h),
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: GameBounce(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          decoration: GameTheme.boardDecoration(
                            bgCol: Colors.grey.shade300,
                            borderCol: Colors.grey.shade400,
                            borderRadius: 10,
                            borderWidth: 1.5,
                          ),
                          child: Center(
                            child: Text(
                              'CANCEL',
                              style: GameTheme.headerStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: GameBounce(
                        onTap: () {
                          Navigator.pop(context);
                          _submitGuess(me.id, suspect.id);
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          decoration: GameTheme.buttonDecoration(
                            color: GameTheme.orangeAccent,
                            borderRadius: 10,
                            shadowOffset: 2,
                          ),
                          child: Center(
                            child: Text(
                              'CONFIRM',
                              style: GameTheme.headerStyle(fontSize: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _submitGuess(String meId, String suspectId) async {
    setState(() => _isGuessing = true);
    try {
      final res = await SupabaseService.instance.guessCard(
        roomId: widget.roomId,
        searcherPlayerId: meId,
        suspectPlayerId: suspectId,
      );

      final isCorrect = res['correct'] as bool? ?? false;
      final msg = res['message'] as String? ?? '';

      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          return GuessResultDialog(
            isCorrect: isCorrect,
            message: msg,
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: GameTheme.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isGuessing = false);
    }
  }

  String _getPlayerAvatar(PlayerModel player) {
    final isRevealedPublicly = player.isLocked || player.currentCard == CardType.king;
    if (isRevealedPublicly && player.currentCard != null) {
      switch (player.currentCard!) {
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
    return GameTheme.mysteryAvatar;
  }

  Widget _buildCardEmblem(CardType card) {
    String imageAsset;

    switch (card) {
      case CardType.king:
        imageAsset = GameTheme.kingAvatar;
        break;
      case CardType.queen:
        imageAsset = GameTheme.queenAvatar;
        break;
      case CardType.police:
        imageAsset = GameTheme.policeAvatar;
        break;
      case CardType.thief:
        imageAsset = GameTheme.thiefAvatar;
        break;
      case CardType.prince:
        imageAsset = GameTheme.princeAvatar;
        break;
      case CardType.commander:
        imageAsset = GameTheme.commanderAvatar;
        break;
      case CardType.minister:
        imageAsset = GameTheme.ministerAvatar;
        break;
      case CardType.soldier:
        imageAsset = GameTheme.soldierAvatar;
        break;
      case CardType.merchant:
        imageAsset = GameTheme.merchantAvatar;
        break;
      case CardType.citizen:
        imageAsset = GameTheme.citizenAvatar;
        break;
    }

    return Container(
      width: 72.w,
      height: 72.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: GameTheme.woodDark, width: 2.5.w),
        image: DecorationImage(
          image: AssetImage(imageAsset),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  // Large landscape card display for own player card
  Widget _buildOwnCard(PlayerModel me) {
    final isCardFlipped = me.isRevealed || me.isLocked || _localRevealed;
    if (isCardFlipped && !_flipController.isCompleted && !_flipController.isAnimating) {
      _flipController.forward(from: _flipController.value).then((_) {
        _sheenController.forward(from: 0.0);
        _triggerRevealParticles();
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        final cardHeight = cardWidth * 0.42;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedBuilder(
              animation: _flipController,
              builder: (context, child) {
                final angle = _flipAnimation.value * pi;
                final scale = _scaleAnimation.value;
                final tilt = _tiltAnimation.value;
                final lift = _liftAnimation.value;
                final isFront = angle >= pi / 2;

                return Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001) // perspective
                    ..translate(0.0, lift, 0.0) // lift vertical offset
                    ..scale(scale, scale)
                    ..rotateY(angle)
                    ..rotateZ(tilt), // Z tilt
                  alignment: Alignment.center,
                  child: isFront
                      ? Transform(
                          transform: Matrix4.identity()..rotateY(pi),
                          alignment: Alignment.center,
                          child: _buildCardFront(me, cardWidth, cardHeight),
                        )
                      : _buildCardBack(me, cardWidth, cardHeight),
                );
              },
            ),
            // Floating star/diamond particles overlay
            if (_revealParticles.isNotEmpty && _revealParticleController != null)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: GuessParticlePainter(
                      particles: _revealParticles,
                      center: Offset(cardWidth / 2, cardHeight / 2),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // Front of Card
  Widget _buildCardFront(PlayerModel me, double width, double height) {
    final card = me.currentCard ?? CardType.thief;

    return Stack(
      children: [
        Container(
          width: width,
          height: height,
          decoration: GameTheme.boardDecoration(
            borderCol: GameTheme.woodDark,
            borderWidth: 3.0,
            bgCol: GameTheme.parchmentCardColor,
          ),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'YOUR CARD',
                      style: GameTheme.bodyStyle(
                        fontSize: 11,
                        color: GameTheme.woodMedium,
                        weight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      card.englishName,
                      style: GameTheme.headerStyle(
                        fontSize: 26,
                        color: GameTheme.woodDark,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildCardEmblem(card),
                  SizedBox(height: 6.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: GameTheme.boardDecoration(
                      borderRadius: 8,
                      borderWidth: 1.5,
                      bgCol: GameTheme.goldAccent.withOpacity(0.1),
                      borderCol: GameTheme.goldAccent,
                    ),
                    child: Text(
                      '${card.points} pts',
                      style: GameTheme.headerStyle(
                        fontSize: 11,
                        color: GameTheme.woodDark,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Specular gold-white sheen sweep overlay
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.r),
              child: AnimatedBuilder(
                animation: _sheenAnimation,
                builder: (context, child) {
                  final stops = [
                    0.0,
                    max(0.0, _sheenAnimation.value - 0.2),
                    min(1.0, max(0.0, _sheenAnimation.value)),
                    min(1.0, _sheenAnimation.value + 0.2),
                    1.0,
                  ];
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.0),
                          Colors.white.withOpacity(0.0),
                          Colors.white.withOpacity(0.4),
                          Colors.white.withOpacity(0.0),
                          Colors.white.withOpacity(0.0),
                        ],
                        stops: stops,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Back of Card (Face Down Card)
  Widget _buildCardBack(PlayerModel me, double width, double height) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return GestureDetector(
          onTap: () => _handleRevealCard(me.id),
          child: Container(
            width: width,
            height: height,
            decoration: GameTheme.boardDecoration(
              borderCol: GameTheme.goldAccent,
              borderWidth: 3.0,
              bgCol: GameTheme.woodDark,
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.08,
                    child: Image.asset(
                      GameTheme.parchmentBg,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: GameTheme.goldAccent.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: GameTheme.goldAccent, width: 2.w),
                          boxShadow: [
                            BoxShadow(
                              color: GameTheme.goldAccent.withOpacity(0.3),
                              blurRadius: _pulseAnimation.value,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Icon(Icons.lock, color: GameTheme.goldAccent, size: 28.sp),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'TAP TO OPEN',
                        style: GameTheme.headerStyle(
                          fontSize: 14,
                          color: GameTheme.goldAccent,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'Keep it secret!',
                        style: GameTheme.bodyStyle(
                          fontSize: 11,
                          color: Colors.white54,
                          weight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOtherPlayersGrid(List<PlayerModel> otherPlayers, RoomModel room, PlayerModel me) {
    final totalPlayers = otherPlayers.length + 1; // Including "me"
    
    // Dynamic columns and rows based on player count
    final int crossAxisCount;
    final int rowCount;
    if (totalPlayers <= 6) {
      crossAxisCount = 3;
      rowCount = 2;
    } else {
      crossAxisCount = 3;
      rowCount = 3;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double spacingX = 8.w;
        final double spacingY = 8.h;
        final double maxWidth = constraints.maxWidth;
        final double maxHeight = constraints.maxHeight;

        // Calculate size per cell to fit constraints perfectly
        final double cellWidth = (maxWidth - (crossAxisCount - 1) * spacingX) / crossAxisCount;
        final double cellHeight = (maxHeight - (rowCount - 1) * spacingY) / rowCount;
        
        // Prevent division by zero or negative values
        final double childAspectRatio = (cellWidth > 0 && cellHeight > 0) ? (cellWidth / cellHeight) : 1.0;

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(), // Disable scrolling
          itemCount: otherPlayers.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: spacingY,
            crossAxisSpacing: spacingX,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, idx) {
            final isCompact = totalPlayers > 6;
            return _buildPlayerTile(otherPlayers[idx], room, me, isCompact, cellHeight);
          },
        );
      },
    );
  }

  Widget _buildPlayerTile(PlayerModel player, RoomModel room, PlayerModel me, bool isCompact, double cellHeight) {
    final isMeActiveSearcher = room.searcherCard != null && 
                               me.currentCard == room.searcherCard;

    final canSuspect = isMeActiveSearcher && !player.isLocked && player.userId != me.userId;
    final isSuspectKing = player.currentCard == CardType.king;

    // Active searcher check (for this player card tile)
    final isPlayerSearcher = room.searcherCard != null && 
                             player.currentCard == room.searcherCard;

    final fontSizePoints = isCompact ? 10.0 : 11.0;
    final fontSizeName = isCompact ? 11.0 : 12.0;
    
    // Scale avatar size dynamically based on cellHeight
    final avatarSize = cellHeight * 0.46; // Target around 46% of cellHeight for avatar size

    return GameBounce(
      onTap: canSuspect && !_isGuessing
          ? () => _confirmGuess(me, player, room)
          : null,
      child: Container(
        color: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '${player.points} pts',
              style: GameTheme.bodyStyle(
                fontSize: fontSizePoints,
                color: GameTheme.goldAccent,
                weight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2.h),

            Expanded(
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Status-based radial aura behind the transparent avatar
                  if (isPlayerSearcher)
                    Container(
                      width: avatarSize * 1.1,
                      height: avatarSize * 1.1,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: GameTheme.goldAccent.withOpacity(0.55),
                            blurRadius: (avatarSize * 0.25).r,
                            spreadRadius: (avatarSize * 0.03).w,
                          ),
                        ],
                      ),
                    )
                  else if (player.isLocked)
                    Container(
                      width: avatarSize * 1.1,
                      height: avatarSize * 1.1,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: GameTheme.greenAccent.withOpacity(0.4),
                            blurRadius: (avatarSize * 0.25).r,
                            spreadRadius: (avatarSize * 0.03).w,
                          ),
                        ],
                      ),
                    )
                  else if (canSuspect)
                    Container(
                      width: avatarSize * 1.1,
                      height: avatarSize * 1.1,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: GameTheme.orangeAccent.withOpacity(0.4),
                            blurRadius: (avatarSize * 0.25).r,
                            spreadRadius: (avatarSize * 0.03).w,
                          ),
                        ],
                      ),
                    ),

                  // Large transparent avatar image (no circle frame)
                  SizedBox(
                    width: avatarSize * 1.25,
                    height: avatarSize * 1.25,
                    child: Image.asset(
                      _getPlayerAvatar(player),
                      fit: BoxFit.contain,
                    ),
                  ),

                  // Check badge for locked players
                  if (player.isLocked)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.all(2.5.w),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: GameTheme.greenAccent,
                          border: Border.all(color: Colors.white, width: 1.2.w),
                        ),
                        child: Icon(Icons.check, size: 9.sp, color: Colors.white),
                      ),
                    ),

                  // Crown for King
                  if (isSuspectKing && player.isLocked)
                    Positioned(
                      top: -6.h,
                      right: -4.w,
                      child: Transform.rotate(
                        angle: 0.2,
                        child: Text('👑', style: TextStyle(fontSize: 14.sp)),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 2.h),

            Text(
              player.name,
              style: GameTheme.bodyStyle(
                fontSize: fontSizeName,
                color: GameTheme.woodDark,
                weight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),

            if ((player.isLocked || player.currentCard == CardType.king) && player.currentCard != null)
              Container(
                margin: EdgeInsets.only(top: 2.h),
                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                decoration: GameTheme.boardDecoration(
                  borderRadius: 4,
                  borderWidth: 1,
                  bgCol: isPlayerSearcher
                      ? GameTheme.goldAccent.withOpacity(0.2)
                      : GameTheme.greenAccent.withOpacity(0.15),
                  borderCol: isPlayerSearcher ? GameTheme.goldAccent : GameTheme.greenAccent,
                ),
                child: Text(
                  player.currentCard!.points > 0
                      ? '${player.currentCard!.englishName} (+${player.currentCard!.points})'
                      : player.currentCard!.englishName,
                  style: GameTheme.headerStyle(color: GameTheme.woodDark, fontSize: 8),
                  overflow: TextOverflow.ellipsis,
                ),
              )
            else if (canSuspect)
              Container(
                margin: EdgeInsets.only(top: 2.h),
                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                decoration: GameTheme.boardDecoration(
                  borderRadius: 4,
                  borderWidth: 1,
                  bgCol: GameTheme.orangeAccent.withOpacity(0.15),
                  borderCol: GameTheme.orangeAccent,
                ),
                child: Text(
                  'ACCUSE?',
                  style: GameTheme.headerStyle(color: GameTheme.woodDark, fontSize: 8),
                  overflow: TextOverflow.ellipsis,
                ),
              )
            else
              // Spacer container to maintain consistent height for layout
              SizedBox(height: 14.h),
          ],
        ),
      ),
    );
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

              return StreamBuilder<List<PlayerModel>>(
                stream: _playersStream,
                builder: (context, playersSnapshot) {
                  if (!playersSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: GameTheme.woodDark));
                  }

                  final players = playersSnapshot.data!;
                  
                  // Guard: user's player record may be momentarily absent during
                  // reconnect, hot restart, or a rapid real-time update burst.
                  final me = players.cast<PlayerModel?>().firstWhere(
                    (p) => p!.userId == widget.userId,
                    orElse: () => null,
                  );

                  if (me == null) {
                    return const Center(
                      child: CircularProgressIndicator(color: GameTheme.woodDark),
                    );
                  }

                  final otherPlayers = players.where((p) => p.userId != widget.userId).toList();

                  PlayerModel? activeSearcherPlayer;
                  for (final p in players) {
                    if (p.currentCard == room.searcherCard) {
                      activeSearcherPlayer = p;
                      break;
                    }
                  }
                  final isMeActiveSearcher = activeSearcherPlayer != null && activeSearcherPlayer.userId == widget.userId;

                  return FadeTransition(
                    opacity: _entranceFadeAnimation,
                    child: SlideTransition(
                      position: _entranceSlideAnimation,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header Bar (Round Status)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'ROUND ${room.currentRound} OF ${room.totalRounds}',
                              style: GameTheme.headerStyle(fontSize: 16, color: GameTheme.orangeAccent),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                              decoration: GameTheme.boardDecoration(
                                borderRadius: 8,
                                borderWidth: 1.5,
                              ),
                              child: Text(
                                '${players.length} Players',
                                style: GameTheme.bodyStyle(color: GameTheme.woodDark, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10.h),

                        // Large Game Interrogation Status Banner
                        Container(
                          padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
                          decoration: GameTheme.boardDecoration(
                            borderCol: isMeActiveSearcher ? GameTheme.orangeAccent : GameTheme.woodDark,
                            borderWidth: 2.0,
                            bgCol: isMeActiveSearcher ? GameTheme.orangeAccent.withOpacity(0.08) : GameTheme.parchmentCardColor,
                          ),
                          child: Column(
                            children: [
                              Text(
                                isMeActiveSearcher
                                    ? 'YOUR TURN!'
                                    : '${(activeSearcherPlayer?.name ?? "Someone").toUpperCase()} IS SEARCHING',
                                style: GameTheme.headerStyle(
                                  fontSize: 16,
                                  color: isMeActiveSearcher ? GameTheme.orangeAccent : GameTheme.woodDark,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 4.h),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Finding target: ',
                                    style: GameTheme.bodyStyle(fontSize: 13, color: GameTheme.woodMedium),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                    decoration: BoxDecoration(
                                      color: GameTheme.woodDark,
                                      borderRadius: BorderRadius.circular(6.r),
                                      border: Border.all(color: GameTheme.goldAccent, width: 1.w),
                                    ),
                                    child: Text(
                                      '${room.targetCard?.englishName}',
                                      style: GameTheme.headerStyle(
                                        fontSize: 12,
                                        color: GameTheme.goldAccent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 12.h),

                        // Optimized Grid for other players
                        Expanded(
                          child: _buildOtherPlayersGrid(otherPlayers, room, me),
                        ),
                        SizedBox(height: 12.h),

                        // Current player own card block (Large landscape bottom card)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(bottom: 6.h, left: 4.w),
                              child: Row(
                                children: [
                                  Icon(Icons.person_pin, color: GameTheme.goldAccent, size: 16.sp),
                                  SizedBox(width: 4.w),
                                  Text(
                                    '${me.name} (You)',
                                    style: GameTheme.headerStyle(
                                      fontSize: 13,
                                      color: GameTheme.goldAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildOwnCard(me),
                          ],
                        ),
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
    );
  }
}

class GuessResultDialog extends StatefulWidget {
  final bool isCorrect;
  final String message;

  const GuessResultDialog({
    super.key,
    required this.isCorrect,
    required this.message,
  });

  @override
  State<GuessResultDialog> createState() => _GuessResultDialogState();
}

class _GuessResultDialogState extends State<GuessResultDialog> with TickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  // Particle variables
  final List<GuessParticle> _particles = [];
  AnimationController? _particleController;

  // Shake variables
  AnimationController? _shakeController;

  // Swap variables
  AnimationController? _swapController;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeIn),
    );

    _entryController.forward();

    if (widget.isCorrect) {
      // Wow/Great: Generate stars and confetti particles
      final random = Random();
      final List<Color> colors = [
        const Color(0xFFFFD54F), // Gold
        const Color(0xFFFF9800), // Orange
        const Color(0xFF4CAF50), // Green
        const Color(0xFF2196F3), // Blue
        const Color(0xFFE91E63), // Pink
        const Color(0xFFFFEB3B), // Yellow
      ];
      for (int i = 0; i < 45; i++) {
        final angle = random.nextDouble() * pi * 2;
        final speed = random.nextDouble() * 5 + 4;
        _particles.add(GuessParticle(
          x: 0,
          y: -20,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed - 3.0, // initial upward push
          size: random.nextDouble() * 10 + 6,
          rotation: random.nextDouble() * pi * 2,
          rotationSpeed: (random.nextDouble() - 0.5) * 6,
          color: colors[random.nextInt(colors.length)],
          isStar: random.nextBool(),
        ));
      }

      _particleController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 3000),
      )..addListener(() {
          for (var p in _particles) {
            p.x += p.vx;
            p.y += p.vy;
            p.vy += 0.16; // gravity
            p.vx *= 0.97; // drag
            p.rotation += p.rotationSpeed * 0.06;
          }
          if (mounted) setState(() {});
        });
      _particleController!.forward();
    } else {
      // Shaking animation
      _shakeController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 550),
      );
      _shakeController!.forward();

      // Card Swap animation
      _swapController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      );
      _swapController!.forward();
    }

    // Auto-dismiss dialog after 4.5 seconds
    Future.delayed(const Duration(milliseconds: 4500), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _particleController?.dispose();
    _shakeController?.dispose();
    _swapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: AnimatedBuilder(
        animation: _entryController,
        builder: (context, child) {
          Widget mainCard = ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _buildDialogContent(),
            ),
          );

          if (!widget.isCorrect && _shakeController != null) {
            return AnimatedBuilder(
              animation: _shakeController!,
              builder: (context, child) {
                // Horizontal shake translation using a sine wave
                final offsetVal = sin(_shakeController!.value * 2 * pi * 4.5) * 10.0 * (1.0 - _shakeController!.value);
                return Transform.translate(
                  offset: Offset(offsetVal, 0),
                  child: mainCard,
                );
              },
            );
          }

          if (widget.isCorrect && _particles.isNotEmpty) {
            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                mainCard,
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: GuessParticlePainter(
                        particles: _particles,
                        center: Offset(MediaQuery.of(context).size.width / 2.6, MediaQuery.of(context).size.height / 3.0),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return mainCard;
        },
      ),
    );
  }

  Widget _buildDialogContent() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      decoration: GameTheme.boardDecoration(
        borderRadius: 20,
        borderCol: widget.isCorrect ? GameTheme.goldAccent : GameTheme.woodDark,
        borderWidth: 4.0,
        bgCol: GameTheme.parchmentCardColor,
      ).copyWith(
        boxShadow: [
          BoxShadow(
            color: (widget.isCorrect ? GameTheme.goldAccent : Colors.black).withOpacity(0.35),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isCorrect) ...[
            // Star burst vertical header
            Text('⭐', style: TextStyle(fontSize: 26.sp)),
            SizedBox(height: 4.h),
            const GameShimmerText(text: 'GREAT!', fontSize: 24),
            SizedBox(height: 10.h),
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GameTheme.goldAccent.withOpacity(0.12),
                border: Border.all(color: GameTheme.goldAccent, width: 2.w),
              ),
              child: Icon(Icons.stars, color: GameTheme.goldAccent, size: 40.sp),
            ),
          ] else ...[
            // Sad / swap vertical header
            Text('😢', style: TextStyle(fontSize: 26.sp)),
            SizedBox(height: 4.h),
            Text(
              'WRONG SUSPECT',
              style: GameTheme.headerStyle(fontSize: 18, color: GameTheme.redAccent),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10.h),
            // Card swapping visual
            if (_swapController != null)
              AnimatedBuilder(
                animation: _swapController!,
                builder: (context, child) {
                  final val = _swapController!.value;
                  // Left card translation (goes left-to-right)
                  final leftCardX = -40.w + (80.w * val);
                  final leftCardScale = 1.0 + 0.12 * sin(val * pi);
                  // Right card translation (goes right-to-left)
                  final rightCardX = 40.w - (80.w * val);
                  final rightCardScale = 1.0 - 0.12 * sin(val * pi);

                  return SizedBox(
                    height: 52.h,
                    width: 160.w,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Left card
                        Transform.translate(
                          offset: Offset(leftCardX, 0),
                          child: Transform.scale(
                            scale: leftCardScale,
                            child: Container(
                              width: 32.w,
                              height: 42.h,
                              decoration: GameTheme.boardDecoration(
                                borderRadius: 5,
                                borderWidth: 1.2,
                                bgCol: const Color(0xFFFFCC80),
                                borderCol: GameTheme.woodDark,
                              ),
                              child: Center(
                                child: Icon(Icons.person, color: GameTheme.woodDark, size: 14.sp),
                              ),
                            ),
                          ),
                        ),
                        // Right card
                        Transform.translate(
                          offset: Offset(rightCardX, 0),
                          child: Transform.scale(
                            scale: rightCardScale,
                            child: Container(
                              width: 32.w,
                              height: 42.h,
                              decoration: GameTheme.boardDecoration(
                                borderRadius: 5,
                                borderWidth: 1.2,
                                bgCol: const Color(0xFF90CAF9),
                                borderCol: GameTheme.woodDark,
                              ),
                              child: Center(
                                child: Icon(Icons.person_outline, color: GameTheme.woodDark, size: 14.sp),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
          SizedBox(height: 12.h),
          Text(
            widget.message,
            textAlign: TextAlign.center,
            style: GameTheme.bodyStyle(
              fontSize: 13,
              color: GameTheme.woodDark,
              weight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16.h),
          GameButton3D(
            onTap: () => Navigator.of(context).pop(),
            text: 'CONTINUE',
            color: widget.isCorrect ? GameTheme.greenAccent : GameTheme.orangeAccent,
            height: 38,
          ),
        ],
      ),
    );
  }
}

class GuessParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double rotation;
  double rotationSpeed;
  Color color;
  bool isStar;

  GuessParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    required this.color,
    required this.isStar,
  });
}

class GuessParticlePainter extends CustomPainter {
  final List<GuessParticle> particles;
  final Offset center;

  GuessParticlePainter({required this.particles, required this.center});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      canvas.save();
      canvas.translate(center.dx + p.x, center.dy + p.y);
      canvas.rotate(p.rotation);
      paint.color = p.color;

      if (p.isStar) {
        final path = Path();
        final double radius = p.size;
        final double innerRadius = p.size / 2.5;
        const int points = 5;
        final double angle = pi / points;

        for (int i = 0; i < points * 2; i++) {
          final r = i.isEven ? radius : innerRadius;
          final double currAngle = i * angle - pi / 2;
          final double x = r * cos(currAngle);
          final double y = r * sin(currAngle);
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
      } else {
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

