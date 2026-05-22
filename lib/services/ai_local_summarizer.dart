import 'package:study_hub/services/ai_text_utils.dart';

class AiLocalSummarizer {
  const AiLocalSummarizer();

  String summarize(String input, {int maxSentences = 4}) {
    final text = input.trim();
    if (text.isEmpty) return 'Envie um texto para eu resumir localmente.';
    final sentences = text
        .split(RegExp(r'(?<=[.!?])\s+|\n+'))
        .map((sentence) => sentence.trim())
        .where((sentence) => sentence.length > 24)
        .toList();
    if (sentences.isEmpty) return text;

    final frequencies = <String, int>{};
    for (final token in AiTextUtils.tokens(text)) {
      frequencies[token] = (frequencies[token] ?? 0) + 1;
    }

    final scored = <_ScoredSentence>[];
    for (var i = 0; i < sentences.length; i++) {
      final tokens = AiTextUtils.tokens(sentences[i]);
      final score = tokens.fold<int>(
        0,
        (sum, token) => sum + (frequencies[token] ?? 0),
      );
      scored.add(_ScoredSentence(i, sentences[i], score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    final chosen = scored.take(maxSentences).toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return chosen.map((item) => '- ${item.text}').join('\n');
  }
}

class _ScoredSentence {
  final int index;
  final String text;
  final int score;

  const _ScoredSentence(this.index, this.text, this.score);
}
