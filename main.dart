import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:hoteldetail_dart/models.dart';
import 'package:hoteldetail_dart/objectbox.g.dart';

late Store store;
Future<HttpServer> run(Handler handler, InternetAddress ip, int port) async {
  store = openStore();
  return serve(handler, ip, port);
}
