import 'package:flutter/material.dart';
import 'package:LangBridge/models/user_profile.dart';
import 'package:LangBridge/services/api_service.dart';
import 'package:LangBridge/repositories/auth_repository.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _apiService = ApiService();
  final _authRepository = AuthRepository();
  UserProfile? _profile;
  bool _isLoading = true;
  bool _isMyProfile = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    String? targetUserId = widget.userId;

    if (targetUserId == null) {
      targetUserId = await AuthRepository.getCurrentUserId();
      if (targetUserId != null) {
        _isMyProfile = true;
      }
    }

    if (targetUserId == null) {
      // Не смогли определить пользователя
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // Запрос остается прежним, так как он уже использует ID
    final data = await _apiService.getUserProfile(targetUserId);
    if (mounted) {
      setState(() {
        _profile = data;
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

    // Переходим на экран редактирования и ждем результат (обновленный профиль)
    final result = await Navigator.of(context).push<UserProfile>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(profile: _profile!),
      ),
    );

    // Если мы получили обновленный профиль, обновляем состояние этого экрана
    if (result != null) {
      setState(() {
        _profile = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isMyProfile ? "Мой профиль" : (_profile?.username ?? "Профиль")),
        actions: [
          if (_isMyProfile)
            IconButton(onPressed: _editProfile, icon: const Icon(Icons.edit), tooltip: 'Редактировать'),
          if (_isMyProfile)
            IconButton(onPressed: _logout, icon: const Icon(Icons.logout), tooltip: 'Выйти'),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_profile == null) {
      return const Center(child: Text("Не удалось загрузить профиль."));
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
        _buildProfileInfoRow(Icons.person_outline, "Возраст", profile.age?.toString() ?? "Не указан"),
        _buildProfileInfoRow(Icons.flag_outlined, "Страна", profile.country ?? "Не указана"),
        _buildProfileInfoRow(Icons.height, "Рост", profile.height != null ? "${profile.height} см" : "Не указан"),

        const Divider(height: 32),
        Text("О себе", style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(profile.bio ?? "Нет информации."),

        const Divider(height: 32),
        Text("Языки", style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ...profile.languages.map((lang) => ListTile(
          leading: const Icon(Icons.language),
          title: Text(lang.name),
          subtitle: Text(lang.type == 'native' ? 'Родной' : 'Изучаю (${lang.level})'),
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
