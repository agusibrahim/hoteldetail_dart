import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dart_frog/dart_frog.dart';
import 'package:dio/dio.dart' as io;
import 'package:hive/hive.dart';
import 'package:string_similarity/string_similarity.dart';

Future<Response> onRequest(RequestContext context) async {
  var box = Hive.box("hotel");
  var data = {
    "title": "Hotel Metadata",
    "author": "Agus Ibrahim",
    "cache": {
      "total": box.length,
      "server_time": DateTime.now().toIso8601String(),
      "last_key_insert": box.keyAt(0),
      "cache_size": await getFileSize("cache.db/hotel.hive", 1)
    }
  };
  return Response.json(body: data);
}

Future<dynamic> getFileSize(String filepath, int decimals) async {
  var file = File(filepath);
  int bytes = await file.length();
  if (bytes <= 0) return "0 B";
  const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
  var i = (log(bytes) / log(1024)).floor();
  return ((bytes / pow(1024, i)).toStringAsFixed(decimals)) + ' ' + suffixes[i];
}
