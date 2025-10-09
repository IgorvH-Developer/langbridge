import 'package:flutter/material.dart';
import 'package:LangBridge/models/user_profile.dart';
import 'package:LangBridge/services/api_service.dart';
import 'package:LangBridge/screens/profile_screen.dart'; // Для перехода на профиль

class PartnerSearchScreen extends StatefulWidget {
  const PartnerSearchScreen({super.key});

  @override
  State<PartnerSearchScreen> createState() => _PartnerSearchScreenState();
}

class _PartnerSearchScreenState extends State<PartnerSearchScreen> {
  final _apiService = ApiService();
  List<UserProfile> _foundUsers = [];
  bool _isLoading = false;

  // Для фильтров
  String? _selectedNativeLang; // 'ru', 'en'
  String? _selectedLearningLang;

  Future<void> _searchUsers() async {
    setState(() => _isLoading = true);
    final result = await _apiService.findUsers(
      nativeLangCode: _selectedNativeLang,
      learningLangCode: _selectedLearningLang,
    );
    if (mounted) {
      setState(() {
        _foundUsers = result ?? [];
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _searchUsers(); // Первоначальный поиск без фильтров
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Поиск собеседников"),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _foundUsers.isEmpty
                ? const Center(child: Text("Пользователи не найдены. Попробуйте изменить фильтры."))
                : ListView.builder(
              itemCount: _foundUsers.length,
              itemBuilder: (context, index) {
                final user = _foundUsers[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                      child: user.avatarUrl == null ? const Icon(Icons.person) : null,
                    ),
                    title: Text(user.username),
                    subtitle: Text(user.country ?? "Страна не указана"),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ProfileScreen(userId: user.id)
                      ));
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    // В реальном приложении здесь будут выпадающие списки,
    // которые загружают языки с эндпоинта /api/users/languages/all
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(labelText: "Их родной язык (en, ru...)"),
              onChanged: (value) => _selectedNativeLang = value.trim().toLowerCase(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              decoration: const InputDecoration(labelText: "Их изучаемый язык"),
              onChanged: (value) => _selectedLearningLang = value.trim().toLowerCase(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _searchUsers,
          ),
        ],
      ),
    );
  }
}
