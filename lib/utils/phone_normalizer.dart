/// Mirrors backend smsGatewayService.normalizePhoneNumber for Indian numbers.
String normalizePhoneNumber(String? rawPhone) {
  if (rawPhone == null || rawPhone.trim().isEmpty) return '';

  var cleaned = rawPhone.replaceAll(RegExp(r'[\s\-\(\)]'), '').trim();

  if (cleaned.startsWith('+')) {
    return cleaned;
  }
  if (cleaned.startsWith('00')) {
    return '+${cleaned.substring(2)}';
  }
  if (cleaned.length == 11 && cleaned.startsWith('0')) {
    return '+91${cleaned.substring(1)}';
  }
  if (cleaned.length == 10 && RegExp(r'^[6-9]\d{9}$').hasMatch(cleaned)) {
    return '+91$cleaned';
  }
  return cleaned.startsWith('+') ? cleaned : '+$cleaned';
}

/// SmsManager accepts E.164; strip leading + for some carriers if needed — keep + by default.
String phoneForSmsDispatch(String normalizedE164) {
  return normalizedE164;
}
