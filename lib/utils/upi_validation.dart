/// Validation helpers for Indian mobile numbers and UPI VPAs.
abstract final class UpiValidation {
  /// 10-digit Indian mobile (starts with 6–9).
  static final RegExp _indianMobile = RegExp(r'^[6-9]\d{9}$');

  /// Typical UPI VPA: user@psp (PSP segment allows dots e.g. @okaxis.bank).
  static final RegExp _vpa = RegExp(r'^[a-zA-Z0-9._-]{2,256}@[a-zA-Z][a-zA-Z0-9.-]{1,63}$');

  static String digitsOnly(String s) =>
      RegExp(r'\d').allMatches(s).map((m) => m.group(0)!).join();

  /// Strips +91 / leading 0; returns null if not exactly 10 valid digits.
  static String? normalizeIndianMobile(String raw) {
    var d = digitsOnly(raw);
    if (d.length == 12 && d.startsWith('91')) {
      d = d.substring(2);
    } else if (d.length == 11 && d.startsWith('0')) {
      d = d.substring(1);
    }
    if (d.length != 10) return null;
    return _indianMobile.hasMatch(d) ? d : null;
  }

  static bool isValidIndianMobile(String tenDigits) =>
      _indianMobile.hasMatch(tenDigits);

  static bool isValidVpa(String vpa) {
    final t = vpa.trim().toLowerCase();
    if (t.length < 5 || !t.contains('@')) return false;
    return _vpa.hasMatch(t);
  }

  static String? normalizeVpa(String raw) {
    var t = raw.trim().toLowerCase();
    t = t.replaceAll(RegExp(r'\s+'), '');
    if (!t.contains('@')) return null;
    return isValidVpa(t) ? t : null;
  }
}
