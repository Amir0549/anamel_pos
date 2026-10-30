import 'dart:io';

import 'package:flutter/material.dart';

import '../anamel_colors.dart';

Widget buildProductThumbnail(String path,
    {double size = 42, double iconSize = 22}) {
  if (path.isEmpty) {
    return Icon(Icons.checkroom_rounded,
        color: AnamelColors.sageDark, size: iconSize);
  }
  try {
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(
        file,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(Icons.checkroom_rounded,
            color: AnamelColors.sageDark, size: iconSize),
      );
    }
  } catch (_) {}

  return Image.asset(
    path,
    width: size,
    height: size,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => Icon(Icons.checkroom_rounded,
        color: AnamelColors.sageDark, size: iconSize),
  );
}
