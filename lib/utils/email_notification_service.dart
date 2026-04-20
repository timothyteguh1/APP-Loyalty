import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class EmailNotificationService {
  static Future<bool> _send({
    required String toEmail,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      final supabaseUrl = dotenv.env['SUPABASE_URL']!;
      final supabaseKey = dotenv.env['SUPABASE_ANON_KEY']!;

      final response = await http.post(
        Uri.parse('$supabaseUrl/functions/v1/send-email'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $supabaseKey',
        },
        body: jsonEncode({
          'to': toEmail,
          'type': type,
          'data': data ?? {},
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('Email sent to $toEmail ($type)');
        return true;
      } else {
        debugPrint('Email failed: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Email error: $e');
      return false;
    }
  }

  // ============================================================
  // ADMIN → USER
  // ============================================================

  static Future<bool> sendApproved({required String toEmail, required String userName}) {
    return _send(toEmail: toEmail, type: 'APPROVED', data: {'userName': userName});
  }

  static Future<bool> sendRejected({required String toEmail, required String userName, required String reason}) {
    return _send(toEmail: toEmail, type: 'REJECTED', data: {'userName': userName, 'reason': reason});
  }

  static Future<bool> sendManualPoints({required String toEmail, required String userName, required int amount, required String reason}) {
    return _send(toEmail: toEmail, type: 'MANUAL_POINTS', data: {'userName': userName, 'amount': amount, 'reason': reason});
  }

  static Future<bool> sendWelcomeNewUser({required String toEmail, required String userName, required String password}) {
    return _send(toEmail: toEmail, type: 'WELCOME_NEW_USER', data: {'userName': userName, 'email': toEmail, 'password': password});
  }

  static Future<bool> sendPointsEarned({required String toEmail, required String userName, required int pointsAmount}) {
    return _send(toEmail: toEmail, type: 'POINTS_EARNED', data: {'userName': userName, 'pointsAmount': pointsAmount});
  }

  static Future<bool> sendAnnualReset({required String toEmail, required String userName, required int pointsLost}) {
    return _send(toEmail: toEmail, type: 'ANNUAL_RESET', data: {'userName': userName, 'pointsLost': pointsLost});
  }

  // ============================================================
  // USER → USER SENDIRI
  // ============================================================

  static Future<bool> sendRewardClaimed({required String toEmail, required String userName, required String rewardName}) {
    return _send(toEmail: toEmail, type: 'REWARD_CLAIMED', data: {'userName': userName, 'rewardName': rewardName});
  }

  static Future<bool> sendQrPoints({required String toEmail, required String userName, required int pointsAmount, required String qrCode}) {
    return _send(toEmail: toEmail, type: 'QR_POINTS', data: {'userName': userName, 'pointsAmount': pointsAmount, 'qrCode': qrCode});
  }

  // ============================================================
  // USER → ADMIN
  // ============================================================

  static Future<bool> sendNewRegistration({required String toEmail, required String userName, required String userPhone}) {
    return _send(toEmail: toEmail, type: 'NEW_REGISTRATION', data: {'userName': userName, 'userPhone': userPhone});
  }

  static Future<bool> sendResubmission({required String toEmail, required String userName}) {
    return _send(toEmail: toEmail, type: 'RESUBMISSION', data: {'userName': userName});
  }

  // ============================================================
  // CUSTOM / BROADCAST
  // ============================================================

  static Future<bool> sendCustom({required String toEmail, required String userName, required String subject, required String body}) {
    return _send(toEmail: toEmail, type: 'CUSTOM', data: {'userName': userName, 'customSubject': subject, 'customBody': body});
  }
}