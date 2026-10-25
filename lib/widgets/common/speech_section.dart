import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../app_colors.dart';

/// A single piece of guided content shown inside [SpeechReader].
class SpeechText {
  final String title;
  final String text;
  final IconData icon;
  final Color color;

  const SpeechText({
    required this.title,
    required this.text,
    required this.icon,
    required this.color,
  });
}

/// Renders a list of [SpeechText] sections with one shared "Text to Speech"
/// button at the top. Tapping the button reads every section top-to-bottom with
/// word-by-word highlighting (the current word is shown with a blue background
/// with white text). Each section [SpeechText.title] is mentioned first, then
/// its text is read before moving on to the next section.
class SpeechReader extends StatefulWidget {
  final List<SpeechText> sections;

  const SpeechReader({super.key, required this.sections});

  @override
  State<SpeechReader> createState() => _SpeechReaderState();
}

class _SpeechReaderState extends State<SpeechReader> {
  final FlutterTts _tts = FlutterTts();

  bool _ready = false;
  bool _speaking = false;
  int _activeSection = 0;
  int _highlightedWord = -1;
  int _contentOffset = 0;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      _tts.setProgressHandler(_onProgress);
      _tts.setCompletionHandler(_onUtteranceDone);
      _tts.setCancelHandler(_onStop);
      _tts.setErrorHandler((_) => _onStop());
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  void _onProgress(String text, int start, int end, String word) {
    if (!mounted || widget.sections.isEmpty) return;
    final local = start - _contentOffset;
    if (local < 0) return;

    final section = widget.sections[_activeSection];
    final words = section.text.trim().split(RegExp(r'\s+'));
    int cursor = 0;
    int index = -1;
    for (var i = 0; i < words.length; i++) {
      final wordEnd = cursor + words[i].length;
      if (local >= cursor && local < wordEnd) {
        index = i;
        break;
      }
      cursor = wordEnd + 1;
    }
    if (index != -1 && index != _highlightedWord) {
      setState(() => _highlightedWord = index);
    }
  }

  void _onStop() {
    if (!mounted) return;
    setState(() {
      _speaking = false;
      _activeSection = 0;
      _highlightedWord = -1;
    });
  }

  Future<void> _speakSection(int index) async {
    if (index >= widget.sections.length) {
      _onStop();
      return;
    }
    final section = widget.sections[index];
    final text = section.text.trim();
    _contentOffset = '${section.title}. '.length;

    setState(() {
      _activeSection = index;
      _highlightedWord = -1;
      _speaking = true;
    });
    await _tts.speak('${section.title}. $text');
  }

  Future<void> _onUtteranceDone() async {
    if (!mounted || !_speaking) return;
    await _speakSection(_activeSection + 1);
  }

  Future<void> _toggleSpeech() async {
    if (!_ready) await _initTts();
    if (!_ready) return;

    if (_speaking) {
      await _tts.stop();
      _onStop();
      return;
    }
    await _speakSection(0);
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sections.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSpeakerButton(),
        const SizedBox(height: 12),
        for (var i = 0; i < widget.sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _buildSectionCard(i),
        ],
      ],
    );
  }

  Widget _buildSpeakerButton() {
    final speaking = _speaking;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: _toggleSpeech,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: speaking ? null : AppColors.primaryGradient,
            color: speaking ? AppColors.error : null,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: AppColors.shadowMedium, blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                speaking ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
                size: 18,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                speaking ? 'Stop Reading' : 'Text to Speech',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(int sectionIndex) {
    final section = widget.sections[sectionIndex];
    final isActive = sectionIndex == _activeSection;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: AppColors.shadowMedium, blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: section.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(section.icon, size: 16, color: section.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  section.title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSectionText(section, isActive),
        ],
      ),
    );
  }

  Widget _buildSectionText(SpeechText section, bool isActive) {
    final text = section.text.trim();
    if (text.isEmpty) {
      return const Text('', style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textPrimary));
    }

    final words = text.split(RegExp(r'\s+'));
    final spans = <TextSpan>[];
    for (var i = 0; i < words.length; i++) {
      final isCurrent = isActive && i == _highlightedWord;
      spans.add(
        TextSpan(
          text: words[i],
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: isCurrent ? Colors.white : AppColors.textPrimary,
            backgroundColor: isCurrent ? AppColors.primary : Colors.transparent,
          ),
        ),
      );
      if (i < words.length - 1) {
        spans.add(const TextSpan(text: ' '));
      }
    }
    return Text.rich(TextSpan(children: spans));
  }
}