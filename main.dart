import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:hive/hive.dart';

Future<HttpServer> run(Handler handler, InternetAddress ip, int port) async {
  Hive.init("cache.db");
  Hive.openBox("hotel");
  return serve(handler, ip, port);
}
