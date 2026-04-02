/// Spoken hint included in voice prompts so users know how to go back.
const String kVoiceBackHint = 'To go back to the previous screen, say BACK.';

/// True when the user said they want to go back (e.g. "back", "go back").
bool isVoiceBackCommand(String raw) {
  final input = raw.toLowerCase().trim();
  if (input.isEmpty) return false;
  if (input == 'back' || input == 'go back') return true;
  if (RegExp(r'\bgo\s+back\b').hasMatch(input)) return true;
  if (RegExp(r'\bback\b').hasMatch(input)) return true;
  return false;
}
