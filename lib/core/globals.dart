import 'package:flutter/material.dart';

/// 全局 ScaffoldMessengerKey，用于在无 Context 的地方显示 SnackBar
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
