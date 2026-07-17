import 'package:flutter/material.dart';

/// 플로팅 스낵바 — 기존 화면별 `_snack` 과 동일 동작.
void showTtmSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
}
