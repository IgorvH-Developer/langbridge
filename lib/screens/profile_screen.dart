import 'package:flutter/material.dart';
import 'package:LangBridge/models/user_profile.dart';
import 'package:LangBridge/screens/chat_screen.dart';
import 'package:LangBridge/services/api_service.dart';
import 'package:LangBridge/repositories/auth_repository.dart';
import 'package:LangBridge/repositories/chat_repository.dart';
import 'package:LangBridge/screens/settings_screen.dart';
import 'package:LangBridge/l10n/app_localizations.dart';
import 'package:LangBridge/screens/edit_profile_screen.dart';
import 'package:LangBridge/screens/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _apiService = ApiService();
  final _authRepository = AuthRepository();
  final _chatRepository = ChatRepository();

  UserProfile? _profile;
  bool _isLoading = true;
  bool _isMyProfile = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _startChat() async {
    final l10n = AppLocalizations.of(context)!;

    if (_profile == null) return;

    // Показываем индикатор загрузки
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator())
    );

    // Запрашиваем чат с этим пользователем
    final chat = await _chatRepository.getOrCreatePrivateChat(_profile!.id);

    Navigator.of(context).pop(); // Закрываем диалог загрузки

    if (chat != null && mounted) {
      // Переходим на экран чата
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatScreen(
          chat: chat,
          chatRepository: _chatRepository,
        ),
      ));
    } else {
      // Показываем ошибку
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToLoadChat))
      );
    }
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    String? targetUserId = widget.userId;

    // 1. Определяем, чей ID нам нужен.
    if (targetUserId == null) {
      // Если ID не передан в виджет, значит, это наш собственный профиль.
      targetUserId = await AuthRepository.getCurrentUserId();
      if (mounted) { // Проверяем, существует ли еще виджет
        setState(() {
          _isMyProfile = true;
        });
      }
    }

    // 2. Если ID все еще не определен (например, пользователь не залогинен), выходим.
    if (targetUserId == null) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Можно показать сообщение об ошибке
      }
      print("Ошибка: не удалось определить ID пользователя для загрузки профиля.");
      return;
    }

    // 3. Загружаем профиль по найденному ID.
    final userProfileData = await _apiService.getUserProfile(targetUserId);

    // 4. Обновляем состояние с полученными данными.
    if (mounted) {
      setState(() {
        _profile = userProfileData;
        _isLoading = false;
      });
    }
  }


  Future<void> _logout() async {
    await _authRepository.logout();
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  void _editProfile() async {
    if (_profile == null) return;

    final result = await Navigator.of(context).push<UserProfile>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(profile: _profile!),
      ),
    );

    if (result != null) {
      setState(() {
        _profile = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isMyProfile ? l10n.settings /* Можно создать отдельную строку "Мой профиль" */ : (_profile?.username ?? "Профиль")),
        actions: [
          if (_isMyProfile)
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: l10n.settings,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
            ),

          if (_isMyProfile)
            IconButton(onPressed: _editProfile, icon: const Icon(Icons.edit), tooltip: 'Редактировать'),
          if (_isMyProfile)
            IconButton(onPressed: _logout, icon: const Icon(Icons.logout), tooltip: 'Выйти'),
          if (!_isMyProfile)
            IconButton(
              icon: const Icon(Icons.message),
              onPressed: _startChat,
              tooltip: "Написать сообщение",
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_profile == null) {
      return Center(child: Text(l10n.failedToLoadProfile));
    }

    final profile = _profile!;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Center(
          child: CircleAvatar(
            radius: 50,
            backgroundImage: profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
            child: profile.avatarUrl == null ? const Icon(Icons.person, size: 50) : null,
          ),
        ),
        const SizedBox(height: 16),
        Text(profile.username, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
        if (profile.fullName != null)
          Text(profile.fullName!, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),

        const SizedBox(height: 24),
        _buildProfileInfoRow(Icons.person_outline, l10n.age, profile.age?.toString() ?? l10n.notSpecified),
        _buildProfileInfoRow(Icons.flag_outlined, l10n.country, profile.country ?? l10n.notSpecified),
        _buildProfileInfoRow(Icons.height, l10n.heigh, profile.height != null ? "${profile.height} ${l10n.centimeters}" : l10n.notSpecified),

        const Divider(height: 32),
        Text(l10n.aboutMyself, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(profile.bio ?? l10n.noInformation),

        const Divider(height: 32),
        Text(l10n.languages, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ...profile.languages.map((lang) => ListTile(
          leading: const Icon(Icons.language),
          title: Text(lang.name),
          subtitle: Text(lang.type == 'native' ? l10n.native : '${l10n.learn} (${lang.level})'),
        )),
      ],
    );
  }

  Widget _buildProfileInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600),
          const SizedBox(width: 16),
          Text("$label:", style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Text(value),
        ],
      ),
    );
  }
}
