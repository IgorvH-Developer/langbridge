class TranscriptionWord {
  final String id;
  String word;
  final double start;
  final double end;

  TranscriptionWord({
    required this.id,
    required this.word,
    required this.start,
    required this.end,
  });

  factory TranscriptionWord.fromJson(Map<String, dynamic> json) {
    return TranscriptionWord(
      id: json['id'],
      word: json['word'],
      start: (json['start'] as num).toDouble(),
      end: (json['end'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'word': word,
      'start': start,
      'end': end,
    };
  }
}

class TranscriptionData {
  String fullText;
  List<TranscriptionWord> words;

  TranscriptionData({
    required this.fullText,
    required this.words,
  });

  factory TranscriptionData.fromJson(Map<String, dynamic> json) {
    var wordsList = json['words'] as List;
    List<TranscriptionWord> words = wordsList.map((i) => TranscriptionWord.fromJson(i)).toList();

    return TranscriptionData(
      fullText: json['full_text'],
      words: words,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'full_text': fullText,
      'words': words.map((w) => w.toJson()).toList(),
    };
  }

  // Метод для регенерации full_text после редактирования
  void regenerateFullText() {
    fullText = words.map((w) => w.word.trim()).join(' ');
  }
}
