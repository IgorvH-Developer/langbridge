import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:LangBridge/models/user_profile.dart';
import 'package:LangBridge/services/api_service.dart';

class EditProfileScreen extends StatefulWidget {
  final UserProfile profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  bool _isLoading = false;

  // Контроллеры для всех полей
  late TextEditingController _fullNameController;
  late TextEditingController _ageController;
  late TextEditingController _countryController;
  late TextEditingController _heightController;
  late TextEditingController _bioController;
  late TextEditingController _interestsController;

  @override
  void initState() {
    super.initState();
    // Инициализируем контроллеры текущими значениями из профиля
    _fullNameController = TextEditingController(text: widget.profile.fullName);
    _ageController = TextEditingController(text: widget.profile.age?.toString() ?? '');
    _countryController = TextEditingController(text: widget.profile.country);
    _heightController = TextEditingController(text: widget.profile.height?.toString() ?? '');
    _bioController = TextEditingController(text: widget.profile.bio);
    _interestsController = TextEditingController(text: widget.profile.interests);
  }

  @override
  void dispose() {
    // Не забываем очищать контроллеры
    _fullNameController.dispose();
    _ageController.dispose();
    _countryController.dispose();
    _heightController.dispose();
    _bioController.dispose();
    _interestsController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return; // Если форма не валидна, ничего не делаем
    }

    setState(() => _isLoading = true);

    // Собираем данные из контроллеров в Map
    final Map<String, dynamic> dataToUpdate = {
      'full_name': _fullNameController.text.trim(),
      'country': _countryController.text.trim(),
      'bio': _bioController.text.trim(),
      'interests': _interestsController.text.trim(),
      // Для числовых полей делаем проверку и парсинг
      'age': int.tryParse(_ageController.text.trim()),
      'height': int.tryParse(_heightController.text.trim()),
    };

    // Удаляем ключи с null значениями, чтобы не отправлять их на сервер, если поля пустые
    dataToUpdate.removeWhere((key, value) => value == null && (key == 'age' || key == 'height'));


    final updatedProfile = await _apiService.updateUserProfile(widget.profile.id, dataToUpdate);

    setState(() => _isLoading = false);

    if (mounted) {
      if (updatedProfile != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Профиль успешно обновлен!"), backgroundColor: Colors.green),
        );
        // Возвращаемся на предыдущий экран и передаем обновленный профиль
        Navigator.of(context).pop(updatedProfile);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ошибка обновления профиля"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Редактирование профиля"),
        actions: [
          // Кнопка сохранения в AppBar
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveProfile,
            tooltip: "Сохранить",
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildTextField(
              controller: _fullNameController,
              labelText: "Полное имя",
              icon: Icons.person,
            ),
            _buildTextField(
              controller: _countryController,
              labelText: "Страна",
              icon: Icons.flag,
            ),
            _buildTextField(
                controller: _ageController,
                labelText: "Возраст",
                icon: Icons.cake,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly]
            ),
            _buildTextField(
                controller: _heightController,
                labelText: "Рост (см)",
                icon: Icons.height,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly]
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _bioController,
              labelText: "О себе",
              icon: Icons.description,
              maxLines: 4,
            ),
            _buildTextField(
              controller: _interestsController,
              labelText: "Интересы (через запятую)",
              icon: Icons.favorite,
              maxLines: 2,
            ),
            // TODO: Добавить редактирование языков
            // Это более сложный UI, который требует отдельной реализации
            // (добавление, удаление, выбор уровня)
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveProfile,
              child: const Text("Сохранить изменения"),
            ),
          ],
        ),
      ),
    );
  }

  // Вспомогательный метод для создания текстовых полей
  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
      ),
    );
  }
}
