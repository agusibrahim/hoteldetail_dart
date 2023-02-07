import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:dio/dio.dart' as io;
import 'package:string_similarity/string_similarity.dart';

Response onRequest(RequestContext context) {
  return Response(body: 'Welcome to Dart Frog!');
}
