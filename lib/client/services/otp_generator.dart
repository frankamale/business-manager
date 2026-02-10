import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

String generateTOTP({
  required String uuid,
  int digits = 6,
  int stepSeconds = 30,
}) {
  // Current Unix time in seconds
  final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  // Time counter (changes every 30s)
  final counter = timestamp ~/ stepSeconds;

  // Convert UUID to bytes (secret key)
  final key = utf8.encode(uuid.replaceAll("-", ""));

  // Convert counter to 8-byte buffer (big endian)
  final counterBytes = ByteData(8)..setInt64(0, counter);

  // Generate HMAC-SHA1 hash
  final hmacSha1 = Hmac(sha1, key);
  final hash = hmacSha1.convert(counterBytes.buffer.asUint8List()).bytes;

  // Dynamic truncation
  final offset = hash.last & 0x0F;

  final binaryCode =
  ((hash[offset] & 0x7F) << 24) |
  ((hash[offset + 1] & 0xFF) << 16) |
  ((hash[offset + 2] & 0xFF) << 8) |
  (hash[offset + 3] & 0xFF);

  // OTP value
  final otp = binaryCode % (pow10(digits));

  return otp.toString().padLeft(digits, '0');
}

// Helper: 10^digits
int pow10(int n) => List.filled(n, 0).fold(1, (a, b) => a * 10);
