import 'dart:convert';
import 'package:crypto/crypto.dart';

const String _secretKey = '9350286c-9fe9-4907-a70a-77442095ccbb';

String generateTOTP({required String clientName}) {
  final now = DateTime.now();

  // Round to 30-minute interval: 0 if minutes < 31, 30 otherwise
  final roundedMinute = now.minute < 31 ? 0 : 30;
  final rounded = DateTime(now.year, now.month, now.day, now.hour, roundedMinute);

  // Format as "yyyy-MM-dd HH:mm"
  final formatted =
      '${rounded.year.toString().padLeft(4, '0')}-'
      '${rounded.month.toString().padLeft(2, '0')}-'
      '${rounded.day.toString().padLeft(2, '0')} '
      '${rounded.hour.toString().padLeft(2, '0')}:'
      '${rounded.minute.toString().padLeft(2, '0')}';

  // Concatenate: clientName + secretKey + formattedTime
  final input = '$clientName$_secretKey$formatted';

  // MD5 hash
  final hash = md5.convert(utf8.encode(input)).toString();

  // First 4 characters of the hex hash
  return hash.substring(0, 4).toUpperCase();
}
