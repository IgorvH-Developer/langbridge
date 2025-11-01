import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:LangBridge/models/user_profile.dart';
import 'package:LangBridge/models/language.dart'; // <<< Убедитесь, что эта модель создана
import 'package:LangBridge/services/api_service.dart';
import 'package:LangBridge/config/app_config.dart';

import '../l10n/app_localizations.dart'; // <<< Импортируем для сборки URL аватара

class EditProfileScreen extends StatefulWidget {
  final UserProfile profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  final _picker = ImagePicker();

  // Состояния
  bool _isSaving = false; // Состояние для индикатора сохранения
  bool _isLoadingInitialData = true; // Для первоначальной загрузки языков

  // Контроллеры для полей
  late TextEditingController _fullNameController;
  late TextEditingController _ageController;
  late TextEditingController _countryController;
  late TextEditingController _heightController;
  late TextEditingController _bioController;
  late TextEditingController _interestsController;

  // Данные для аватара
  String? _avatarUrl; // Относительный URL с сервера, например /uploads/avatar.jpg
  File? _avatarFile; // Локальный файл для предпросмотра нового аватара

  // Данные для языков
  List<Language> _allLanguages = [];
  UserLanguage? _nativeLanguage;
  List<UserLanguage> _learningLanguages = [];

  @override
  void initState() {
    super.initState();
    // Инициализируем контроллеры данными из профиля
    _fullNameController = TextEditingController(text: widget.profile.fullName);
    _ageController = TextEditingController(text: widget.profile.age?.toString() ?? '');
    _countryController = TextEditingController(text: widget.profile.country);
    _heightController = TextEditingController(text: widget.profile.height?.toString() ?? '');
    _bioController = TextEditingController(text: widget.profile.bio);
    _interestsController = TextEditingController(text: widget.profile.interests);
    _avatarUrl = widget.profile.avatarUrl;

    _loadInitialData();
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

  Future<void> _loadInitialData() async {
    final languages = await _apiService.getAllLanguages();
    if (mounted) {
      setState(() {
        _allLanguages = languages ?? [];
        // Распределяем языки пользователя по категориям
        for (var lang in widget.profile.languages) {
          if (lang.type == 'native') {
            _nativeLanguage = lang;
          } else {
            _learningLanguages.add(lang);
          }
        }
        _isLoadingInitialData = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 800);
    if (pickedFile != null) {
      setState(() {
        _avatarFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    final l10n = AppLocalizations.of(context)!;

    if (!_formKey.currentState!.validate() || _isSaving) return;

    setState(() => _isSaving = true);

    String? newRelativeAvatarUrl;

    // 1. Если есть новый аватар, загружаем его и получаем относительный URL
    if (_avatarFile != null) {
      newRelativeAvatarUrl = await _apiService.uploadAvatar(widget.profile.id, _avatarFile!.path);
    }

    // 2. Обновляем текстовые поля профиля и URL аватара
    final Map<String, dynamic> dataToUpdate = {
      'full_name': _fullNameController.text.trim(),
      'country': _countryController.text.trim(),
      'bio': _bioController.text.trim(),
      'interests': _interestsController.text.trim(),
      'age': int.tryParse(_ageController.text.trim()),
      'height': int.tryParse(_heightController.text.trim()),
      // Если загрузили новый аватар, используем его URL, иначе оставляем старый
      'avatar_url': newRelativeAvatarUrl ?? _avatarUrl
    };
    dataToUpdate.removeWhere((key, value) => value == null && (key == 'age' || key == 'height'));

    // Вместо вызова двух методов API по отдельности, можно было бы сделать один эндпоинт на бэке,
    // но текущий подход тоже рабочий.
    await _apiService.updateUserProfile(widget.profile.id, dataToUpdate);


    // 3. Собираем и обновляем языки
    List<Map<String, dynamic>> languagesToSave = [];
    if (_nativeLanguage != null) {
      languagesToSave.add({
        'language_id': _nativeLanguage!.id,
        'level': 'Native', // Уровень для родного языка всегда Native
        'type': 'native'
      });
    }
    for (var lang in _learningLanguages) {
      languagesToSave.add({
        'language_id': lang.id,
        'level': lang.level,
        'type': 'learning'
      });
    }
    await _apiService.updateUserLanguages(widget.profile.id, languagesToSave);

    // 4. Получаем финальный обновленный профиль, чтобы вернуть его на предыдущий экран
    final updatedProfile = await _apiService.getUserProfile(widget.profile.id);

    if (mounted) {
      setState(() => _isSaving = false);
      if (updatedProfile != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.profileSaved), backgroundColor: Colors.green));
        Navigator.of(context).pop(updatedProfile); // Возвращаем результат
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.saveErrorTryAgain), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.editProfile),
        actions: [
          if (_isSaving) const Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: Colors.white)),
          if (!_isSaving) IconButton(onPressed: _saveProfile, icon: const Icon(Icons.save), tooltip: "Сохранить"),
        ],
      ),
      body: _isLoadingInitialData
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildAvatar(),
            const SizedBox(height: 24),
            _buildTextField(controller: _fullNameController, labelText: "Полное имя", icon: Icons.person),
            _buildTextField(controller: _countryController, labelText: "Страна", icon: Icons.flag),
            _buildTextField(controller: _ageController, labelText: "Возраст", icon: Icons.cake, keyboardType: TextInputType.number),
            _buildTextField(controller: _heightController, labelText: "Рост (см)", icon: Icons.height, keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            _buildTextField(controller: _bioController, labelText: "О себе", icon: Icons.description, maxLines: 4),
            _buildTextField(controller: _interestsController, labelText: "Интересы (через запятую)", icon: Icons.favorite, maxLines: 2),

            const Divider(height: 40, thickness: 1),
            _buildNativeLanguageSelector(),
            const SizedBox(height: 24),
            _buildLearningLanguagesSection(),

            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: _isSaving ? null : _saveProfile,
              child: Text(l10n.saveChanges),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    ImageProvider? image;
    // Сначала проверяем, выбран ли новый локальный файл
    if (_avatarFile != null) {
      image = FileImage(_avatarFile!);
    }
    // Если нет, проверяем, есть ли URL с сервера
    else if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      // Собираем полный URL для отображения
      final fullUrl = _avatarUrl!.startsWith('http') ? _avatarUrl! : "https://${AppConfig.serverAddr}$_avatarUrl";
      image = NetworkImage(fullUrl);
    }

    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundImage: image,
            backgroundColor: Colors.grey.shade200,
            child: image == null ? const Icon(Icons.person, size: 60, color: Colors.grey) : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: IconButton(
              icon: const CircleAvatar(radius: 20, child: Icon(Icons.camera_alt)),
              onPressed: _pickImage,
              tooltip: "Выбрать фото",
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNativeLanguageSelector() {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.nativeLanguage, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<int?>(
          value: _nativeLanguage?.id,
          isExpanded: true,
          decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12)),
          hint: Text(l10n.chooseNativeLanguage),
          items: _allLanguages.map((lang) => DropdownMenuItem(value: lang.id, child: Text(lang.name))).toList(),
          onChanged: (langId) {
            if (langId != null) {
              final selected = _allLanguages.firstWhere((l) => l.id == langId);
              setState(() {
                _nativeLanguage = UserLanguage(id: selected.id, name: selected.name, code: selected.code, level: 'Native', type: 'native');
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildLearningLanguagesSection() {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.learningLanguages, style: Theme.of(context).textTheme.titleMedium),
            IconButton(icon: const Icon(Icons.add_circle, color: Colors.green, size: 30), onPressed: () => _showAddLearningLanguageDialog(), tooltip: "Добавить язык"),
          ],
        ),
        if (_learningLanguages.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(l10n.youDidntAddAnyLanguage, style: TextStyle(color: Colors.grey)),
          ),
        ..._learningLanguages.map((lang) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: CircleAvatar(child: Text(lang.code.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold))),
              title: Text(lang.name),
              subtitle: Text("${l10n.level}: ${lang.level}"),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => setState(() => _learningLanguages.remove(lang)),
              ),
            ),
          );
        }),
      ],
    );
  }

  void _showAddLearningLanguageDialog() {
    Language? selectedLang;
    String selectedLevel = 'A1';
    final levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
    final l10n = AppLocalizations.of(context)!;

    // Фильтруем языки, которые уже выбраны (как родной или изучаемый)
    final availableLangs = _allLanguages.where((l) => l.id != _nativeLanguage?.id && !_learningLanguages.any((learnLang) => learnLang.id == l.id)).toList();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.addLearningLanguage),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<Language>(
                    value: selectedLang,
                    isExpanded: true,
                    hint: Text(l10n.chooseLanguage),
                    items: availableLangs.map((lang) => DropdownMenuItem(value: lang, child: Text(lang.name))).toList(),
                    onChanged: (lang) => setDialogState(() => selectedLang = lang),
                  ),
                  DropdownButton<String>(
                    value: selectedLevel,
                    isExpanded: true,
                    hint: Text(l10n.knowledgeLevel),
                    items: levels.map((level) => DropdownMenuItem(value: level, child: Text(level))).toList(),
                    onChanged: (level) => setDialogState(() => selectedLevel = level!),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
                ElevatedButton(
                  onPressed: () {
                    if (selectedLang != null) {
                      setState(() {
                        _learningLanguages.add(UserLanguage(id: selectedLang!.id, name: selectedLang!.name, code: selectedLang!.code, level: selectedLevel, type: 'learning'));
                      });
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text(l10n.add),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Вспомогательный метод для создания текстовых полей
  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.grey.shade100,
        ),
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: keyboardType == TextInputType.number ? [FilteringTextInputFormatter.digitsOnly] : null,
      ),
    );
  }
}

