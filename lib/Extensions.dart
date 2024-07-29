
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:localization/localization.dart';

extension StringExt on String {
  void log() {
    debugPrint(this);
  }

  String base64UrlDecode() {
    Codec<String, String> stringToBase64Url = utf8.fuse(base64Url);
    return stringToBase64Url.decode(const Base64Codec().normalize(this));
  }

  String base64UrlEncode() {
    Codec<String, String> stringToBase64Url = utf8.fuse(base64Url);
    return stringToBase64Url.encode(this).replaceAll('=', '');
  }

  void asAlert(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(25))),
          content: Text(this, textAlign: TextAlign.center),
          contentPadding: const EdgeInsets.only(left: 20, right: 20, top: 30),
          actions: [
            TextButton(
              child: Text('ok'.i18n()),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  void asToast() {
    Fluttertoast.showToast(
      msg: this,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.grey,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  bool isValidEmail() {
    return RegExp(
        r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$')
        .hasMatch(this);
  }

  Digest toSha256() {
    return sha256.convert(utf8.encode(this));
  }

  Function() asLoadingIndicator({required BuildContext context}) {
    BuildContext dialogContext = context;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        dialogContext = context;
        final message = this;
        return AlertDialog(
          title: message.isNotEmpty ? Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ) : null,
          //shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
          //shape: const StadiumBorder(),
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          content: const SizedBox(
            width: 50,
            height: 50,
            child: Center(child: CircularProgressIndicator(color: Colors.white)),
          ),
          contentPadding: const EdgeInsets.all(20),
        );
      },
    );
    dismiss() => Navigator.of(dialogContext).pop();
    return dismiss;
  }

}

extension DigestExt on Digest {

  String toBase64() {
    return base64.encode(bytes);
  }

}

extension PlatformExt on Platform {

  static Future<String> get osVersion async {
    var os = Platform.isAndroid ? "Android" : Platform.isIOS ? "iOS" : "unknown".i18n();
    var version = 'unknown'.i18n();
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      version = androidInfo.version.release;
    }
    else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      version = iosInfo.systemVersion ?? "";
    }
    return '$os $version';
  }

}

extension ResponseExt on Response {

  Map get json {
    return jsonDecode(utf8.decode(bodyBytes)) as Map;
  }

}
