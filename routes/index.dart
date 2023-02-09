import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dart_frog/dart_frog.dart';
import 'package:dio/dio.dart' as io;
import 'package:hoteldetail_dart/models.dart';
import 'package:hoteldetail_dart/objectbox.g.dart';
import 'package:string_similarity/string_similarity.dart';

import '../main.dart' show store;

Future<Response> onRequest(RequestContext context) async {
  final hotelBox = store.box<HotelCache>();
  var lastdata = hotelBox.query().order(HotelCache_.date, flags: Order.descending).build().findFirst();
  var data = {
    "title": "Hotel Metadata",
    "author": "Agus Ibrahim",
    "cache": {
      "total": hotelBox.count(),
      "server_time": DateTime.now().toIso8601String(),
      "last_insert": lastdata?.date?.toIso8601String(),
      "last_hotel": lastdata?.hotel.target!.name,
      "cache_size": await getFileSize("objectbox/data.mdb", 1),
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
