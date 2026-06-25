import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../services/supabase_service.dart';
import '../theme/game_theme.dart';
import '../widgets/game_widgets.dart';
import 'lobby_screen.dart';
import 'game_screen.dart';
import 'round_end_screen.dart';
import 'leaderboard_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _roomCodeController = TextEditingController();
  
  String _gender = 'MALE'; // 'MALE' or 'FEMALE'
  int _totalRounds = 5;
  bool _isCreating = true; // true = Create Room, false = Join Room
  bool _isLoading = false;

  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _loadSavedProfile();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.elasticOut),
    );

    _entranceController.forward();
  }

  Future<void> _loadSavedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('player_name') ?? '';
      _gender = prefs.getString('player_gender') ?? 'MALE';
    });
  }

  Future<void> _saveProfile(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);
    await prefs.setString('player_name', _nameController.text.trim());
    await prefs.setString('player_gender', _gender);
  }

  Future<String> _getOrCreateUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('user_id');
    if (userId == null) {
      userId = const Uuid().v4();
      await prefs.setString('user_id', userId);
    }
    return userId;
  }

  void _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final userId = await _getOrCreateUserId();
      await _saveProfile(userId);

      final name = _nameController.text.trim();
      final supabase = SupabaseService.instance;

      if (_isCreating) {
        final room = await supabase.createRoom(
          adminUserId: userId,
          adminName: name,
          adminGender: _gender,
          totalRounds: _totalRounds,
        );

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LobbyScreen(roomId: room.id, roomCode: room.roomCode, userId: userId),
          ),
        );
      } else {
        final roomCode = _roomCodeController.text.trim();
        final room = await supabase.joinRoom(
          roomCode: roomCode,
          userId: userId,
          name: name,
          gender: _gender,
        );

        if (!mounted) return;
        
        if (room.gameState == 'PLAYING') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GameScreen(roomId: room.id, userId: userId),
            ),
          );
        } else if (room.gameState == 'ROUND_END') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RoundEndScreen(roomId: room.id, userId: userId),
            ),
          );
        } else if (room.gameState == 'FINISHED') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LeaderboardScreen(roomId: room.id, userId: userId),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LobbyScreen(roomId: room.id, roomCode: room.roomCode, userId: userId),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: GameTheme.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roomCodeController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  Widget _buildCharacterCard(String genderType, String titleEnglish, String asset) {
    final isSelected = _gender == genderType;
    return Expanded(
      child: GameBounce(
        onTap: () => setState(() => _gender = genderType),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 6.w),
          decoration: GameTheme.boardDecoration(
            borderRadius: 12,
            borderCol: isSelected ? GameTheme.goldAccent : GameTheme.woodDark,
            borderWidth: isSelected ? 2.5 : 1.5,
            bgCol: isSelected ? const Color(0xFFFFE8C5) : GameTheme.parchmentCardColor,
          ).copyWith(
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: GameTheme.goldAccent.withOpacity(0.25),
                      blurRadius: 6,
                      spreadRadius: 1,
                      offset: const Offset(0, 3),
                    )
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 3,
                      offset: const Offset(0, 1.5),
                    )
                  ],
          ),
          child: Column(
            children: [
              Text(
                titleEnglish,
                style: GameTheme.headerStyle(
                  fontSize: 12,
                  color: isSelected ? GameTheme.orangeAccent : GameTheme.woodDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 6.h),
              Container(
                width: 44.w, // Shrunk size (was 64.w) to ensure zero horizontal overflows
                height: 44.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? GameTheme.goldAccent : GameTheme.woodDark,
                    width: 2.w,
                  ),
                  image: DecorationImage(
                    image: AssetImage(asset),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: EmbersBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h), // Shrunk padding
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Majestic Title Header (English Only)
                        const GameShimmerText(
                          text: 'RAJA RANI',
                          fontSize: 36, // Shrunk font size
                        ),
                        SizedBox(height: 1.h),
                        Text(
                          'MULTIPLAYER BOARD GAME',
                          style: GameTheme.bodyStyle(
                            fontSize: 12,
                            color: GameTheme.orangeAccent,
                            weight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 18.h),

                        // Avatar & Profile Card
                        Container(
                          padding: EdgeInsets.all(14.w), // Shrunk inner padding
                          decoration: GameTheme.boardDecoration(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PROFILE SETUP',
                                style: GameTheme.headerStyle(fontSize: 11, color: GameTheme.woodMedium),
                              ),
                              SizedBox(height: 8.h),
                              GameTextField(
                                controller: _nameController,
                                labelText: 'Your Name',
                                prefixIcon: Icons.person,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Please enter your name';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 12.h),
                              Text(
                                'CHOOSE CHARACTER',
                                style: GameTheme.headerStyle(fontSize: 11, color: GameTheme.woodMedium),
                              ),
                              SizedBox(height: 8.h),
                              Row(
                                children: [
                                  _buildCharacterCard('MALE', 'KING', GameTheme.kingAvatar),
                                  SizedBox(width: 10.w),
                                  _buildCharacterCard('FEMALE', 'QUEEN', GameTheme.queenAvatar),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16.h),

                        // Game Room Action Card
                        Container(
                          padding: EdgeInsets.all(14.w), // Shrunk inner padding
                          decoration: GameTheme.boardDecoration(),
                          child: Column(
                            children: [
                              // Toggle Mode Tabs
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _isCreating = true),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(vertical: 10.h),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: _isCreating ? GameTheme.orangeAccent : Colors.transparent,
                                              width: 3.h,
                                            ),
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'Create Room',
                                            style: GameTheme.headerStyle(
                                              fontSize: 14,
                                              color: _isCreating ? GameTheme.woodDark : GameTheme.woodMedium,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _isCreating = false),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(vertical: 10.h),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: !_isCreating ? GameTheme.orangeAccent : Colors.transparent,
                                              width: 3.h,
                                            ),
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'Join Room',
                                            style: GameTheme.headerStyle(
                                              fontSize: 14,
                                              color: !_isCreating ? GameTheme.woodDark : GameTheme.woodMedium,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16.h),

                              // Dynamic Action Settings
                              if (_isCreating) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Total Rounds:', style: GameTheme.bodyStyle(fontSize: 13, color: GameTheme.woodDark)),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                      decoration: GameTheme.boardDecoration(
                                        borderRadius: 6,
                                        borderWidth: 1.2,
                                        bgCol: GameTheme.orangeAccent.withOpacity(0.1),
                                        borderCol: GameTheme.orangeAccent,
                                      ),
                                      child: Text(
                                        '$_totalRounds Rounds',
                                        style: GameTheme.headerStyle(fontSize: 13, color: GameTheme.woodDark),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 6.h),
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: GameTheme.orangeAccent,
                                    inactiveTrackColor: GameTheme.woodLight.withOpacity(0.2),
                                    thumbColor: GameTheme.goldAccent,
                                    overlayColor: GameTheme.goldAccent.withOpacity(0.2),
                                    trackHeight: 5.h,
                                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8.r),
                                  ),
                                  child: Slider(
                                    value: _totalRounds.toDouble(),
                                    min: 1,
                                    max: 10,
                                    divisions: 9,
                                    onChanged: (val) => setState(() => _totalRounds = val.toInt()),
                                  ),
                                ),
                              ] else ...[
                                GameTextField(
                                  controller: _roomCodeController,
                                  labelText: 'Enter 6-Digit Room Code',
                                  prefixIcon: Icons.vpn_key,
                                  textAlign: TextAlign.center,
                                  textCapitalization: TextCapitalization.characters,
                                  maxLength: 6,
                                  validator: (val) {
                                    if (!_isCreating) {
                                      if (val == null || val.trim().length != 6) {
                                        return 'Room code must be 6 characters';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                              ],
                              SizedBox(height: 16.h),

                              // Submit CTA Button
                              GameButton3D(
                                onTap: _isLoading ? null : _handleSubmit,
                                text: _isLoading
                                    ? 'PLEASE WAIT...'
                                    : (_isCreating ? 'CREATE ROOM' : 'JOIN ROOM'),
                                color: GameTheme.orangeAccent,
                                height: 42,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
