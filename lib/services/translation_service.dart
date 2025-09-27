class TranslationService {
  // Заглушка — потом подключишь Google Translate API / DeepL / свой backend
  Future<String> translate(String text, String targetLang) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return "[Перевод] $text";
  }
}
