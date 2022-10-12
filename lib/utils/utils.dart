import 'package:flutter/material.dart';

class Snack {
  final BuildContext context;

  Snack({
    required this.context,
  });

  show(String msg) {
    var snackBar = SnackBar(content: Text(msg));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}

class Utils {
  static snack(BuildContext context, String msg) {
    var snackBar = SnackBar(content: Text(msg));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}
