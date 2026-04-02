import 'upi_validation.dart';

/// Result of parsing a voice utterance for payee id.
enum PayeeParseKind { mobile, vpa, invalid }

class PayeeParseResult {
  const PayeeParseResult({
    required this.kind,
    this.normalized,
    this.rawSpeech = '',
  });

  final PayeeParseKind kind;
  /// Canonical form: 10-digit mobile or lowercase VPA.
  final String? normalized;
  final String rawSpeech;

  bool get isValid =>
      normalized != null &&
      (kind == PayeeParseKind.mobile || kind == PayeeParseKind.vpa);
}

/// Maps common English/Hinglish number words to digits (single-token).
const Map<String, String> _wordDigit = {
  'zero': '0',
  'oh': '0',
  'o': '0',
  'one': '1',
  'won': '1',
  'two': '2',
  'to': '2',
  'too': '2',
  'three': '3',
  'tree': '3',
  'four': '4',
  'for': '4',
  'fore': '4',
  'five': '5',
  'six': '6',
  'seven': '7',
  'eight': '8',
  'ate': '8',
  'nine': '9',
};

String _collapseWordDigits(String speech) {
  final buf = StringBuffer();
  final cleaned = speech
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s@.+]'), ' ')
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty);

  for (final t in cleaned) {
    if (RegExp(r'^\d+$').hasMatch(t)) {
      buf.write(t);
      continue;
    }
    if (t.length == 1 && RegExp(r'\d').hasMatch(t)) {
      buf.write(t);
      continue;
    }
    final mapped = _wordDigit[t];
    if (mapped != null) {
      buf.write(mapped);
    }
  }
  return buf.toString();
}

/// Removes common confirmation / filler words for parsing.
String stripConfirmationTokens(String speech) {
  var s = speech.toLowerCase().trim();
  s = s.replaceAll(
    RegExp(
      r'\b(confirm|confirmed|confirmation|yes|yeah|yep|ok|okay|correct|right|please|thanks|thank\s+you)\b',
    ),
    ' ',
  );
  s = s.replaceAll(
    RegExp(
      r'\b(my|the|a|an|is|are|it|its|upi|i\s*d|id|ids?|number|mobile|phone|contact|payee|recipient|to|for)\b',
    ),
    ' ',
  );
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s;
}

/// Replaces spoken "at" / "dot" before stripping spaces for VPA.
String _spokenAliasesToSymbols(String speech) {
  var s = speech.toLowerCase();
  s = s.replaceAll(RegExp(r'\s+dot\s+'), '.');
  s = s.replaceAll(RegExp(r'\s+at\s+'), '@');
  s = s.replaceAll(" d ", '.'); // rare STT for "dot"
  return s;
}

/// Parses [speech] into a valid Indian mobile (10 digits) or UPI VPA.
PayeeParseResult parsePayeeFromSpeech(String speech) {
  final raw = speech.trim();
  if (raw.isEmpty) {
    return const PayeeParseResult(kind: PayeeParseKind.invalid, normalized: null);
  }

  final forDigits = stripConfirmationTokens(raw);
  final fromLiterals = UpiValidation.normalizeIndianMobile(
    UpiValidation.digitsOnly(forDigits),
  );
  if (fromLiterals != null) {
    return PayeeParseResult(
      kind: PayeeParseKind.mobile,
      normalized: fromLiterals,
      rawSpeech: raw,
    );
  }

  final fromWords = UpiValidation.normalizeIndianMobile(_collapseWordDigits(forDigits));
  if (fromWords != null) {
    return PayeeParseResult(
      kind: PayeeParseKind.mobile,
      normalized: fromWords,
      rawSpeech: raw,
    );
  }

  var vpaCandidate = _spokenAliasesToSymbols(stripConfirmationTokens(raw));
  vpaCandidate = vpaCandidate.replaceAll(RegExp(r'\s+'), '');
  final vpa = UpiValidation.normalizeVpa(vpaCandidate);
  if (vpa != null) {
    return PayeeParseResult(
      kind: PayeeParseKind.vpa,
      normalized: vpa,
      rawSpeech: raw,
    );
  }

  // Retry VPA: only replace "at", keep single spaces for patterns like "user at okaxis"
  var alt = speech.toLowerCase().trim();
  alt = stripConfirmationTokens(alt);
  alt = alt.replaceAll(RegExp(r'\s+at\s+'), '@');
  alt = alt.replaceAll(RegExp(r'\s+dot\s+'), '.');
  alt = alt.replaceAll(RegExp(r'\s+'), '');
  final vpa2 = UpiValidation.normalizeVpa(alt);
  if (vpa2 != null) {
    return PayeeParseResult(
      kind: PayeeParseKind.vpa,
      normalized: vpa2,
      rawSpeech: raw,
    );
  }

  return PayeeParseResult(
    kind: PayeeParseKind.invalid,
    normalized: null,
    rawSpeech: raw,
  );
}

/// Typed entry (no spoken-word expansion).
PayeeParseResult? parseTypedPayee(String input) {
  final raw = input.trim();
  if (raw.isEmpty) return null;
  final mob = UpiValidation.normalizeIndianMobile(
    UpiValidation.digitsOnly(raw),
  );
  if (mob != null) {
    return PayeeParseResult(
      kind: PayeeParseKind.mobile,
      normalized: mob,
      rawSpeech: raw,
    );
  }
  final vpa = UpiValidation.normalizeVpa(raw.replaceAll(RegExp(r'\s+'), ''));
  if (vpa != null) {
    return PayeeParseResult(
      kind: PayeeParseKind.vpa,
      normalized: vpa,
      rawSpeech: raw,
    );
  }
  return null;
}

/// True if the utterance is only confirmation intent (no new id).
bool isConfirmUtterance(String speech) {
  final t = speech.toLowerCase().trim();
  if (t.isEmpty) return false;
  final hasConfirmWord = RegExp(
    r'\b(confirm|confirmed|yes|yeah|yep|ok|okay|correct|right|proceed)\b',
  ).hasMatch(t);
  if (!hasConfirmWord) return false;
  final rest = t
      .replaceAll(
        RegExp(
          r'\b(confirm|confirmed|yes|yeah|yep|ok|okay|correct|right|proceed|please|thanks|thank\s+you)\b',
        ),
        ' ',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return rest.isEmpty;
}

/// Speak phone as spaced digits for TTS clarity.
String formatMobileForTts(String tenDigits) =>
    tenDigits.split('').join(' ');

/// Speak VPA with " at " instead of @ for TTS.
String formatVpaForTts(String vpa) {
  final at = vpa.indexOf('@');
  if (at <= 0) return vpa;
  final user = vpa.substring(0, at);
  final psp = vpa.substring(at + 1);
  return '$user at $psp';
}
