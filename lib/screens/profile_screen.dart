import 'package:flutter/material.dart';
import 'package:LangBridge/services/api_service.dart';
import 'package:LangBridge/repositories/auth_repository.dart'; // Импортируем AuthRepository
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _apiService = ApiService();
  final _authRepository = AuthRepository(); // Создаем экземпляр AuthRepository
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final data = await _apiService.getMyProfile();
    setState(() {
      _profileData = data;
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    await _authRepository.logout(); // Вызываем logout из AuthRepository
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Профиль"),
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout), tooltip: 'Выйти'),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profileData == null
          ? const Center(child: Text("Не удалось загрузить профиль"))
          : ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Тут будет UI для отображения и редактирования данных
          CircleAvatar(
            radius: 50,
            backgroundImage: _profileData!['avatar_url'] != null
                ? NetworkImage(_profileData!['avatar_url'])
                : null,
            child: _profileData!['avatar_url'] == null
                ? const Icon(Icons.person, size: 50)
                : null,
          ),
          const SizedBox(height: 16),
          Text('Имя пользователя: ${_profileData!['username']}', style: Theme.of(context).textTheme.headlineSmall),
          Text('Имя: ${_profileData!['full_name'] ?? 'Не указано'}'),
          Text('Возраст: ${_profileData!['age'] ?? 'Не указан'}'),
          const SizedBox(height: 16),
          const Text('О себе:', style: TextStyle(fontWeight: FontWeight.bold)),
          Text(_profileData!['bio'] ?? 'Нет информации'),
          const SizedBox(height: 16),
          const Text('Интересы:', style: TextStyle(fontWeight: FontWeight.bold)),
          Text(_profileData!['interests'] ?? 'Не указаны'),
        ],
      ),
    );
  }
}
