import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_frog/dart_frog.dart';
import 'package:dio/dio.dart' as io;
import 'package:hive/hive.dart';
import 'package:string_similarity/string_similarity.dart';

Future<Response> onRequest(RequestContext context) async {
  // if (!context.request.uri.queryParameters.containsKey("provider")) {
  //   return Response.json(body: {"success": false, "msg": "required parameter: provider"});
  // }
  if (!context.request.uri.queryParameters.containsKey("hotel")) {
    return Response.json(body: {"success": false, "msg": "required parameter: hotel"});
  }
  if (!context.request.uri.queryParameters.containsKey("city")) {
    return Response.json(body: {"success": false, "msg": "required parameter: city"});
  }
  var hashid =
      '${"${context.request.uri.queryParameters['hotel']}-${context.request.uri.queryParameters['city']}-${context.request.uri.queryParameters['addr'] ?? ''}-${context.request.uri.queryParameters['provider'] ?? ''}".toLowerCase().trim().hashCode}';
  var box = Hive.box("hotel");
  // if (box.containsKey(hashid)) {
  //   print("using cache $hashid");
  //   return Response.json(body: json.decode("${box.get(hashid)}"));
  // }

  // if (!context.request.uri.queryParameters.containsKey("addr")) {
  //   return Response.json(body: {"success": false, "msg": "required parameter: addr"});
  // }
  var prov = {
    "trvlk": HotelProvider.trvlk,
    "tiket": HotelProvider.tiket,
    "agoda": HotelProvider.agoda,
    "trip": HotelProvider.trip,
    "expedia": HotelProvider.expedia
  };

  if (context.request.uri.queryParameters.containsKey("provider") &&
      !prov.keys.contains(context.request.uri.queryParameters['provider'])) {
    return Response.json(body: {"success": false, "msg": "invalid provider"});
  }
  if (!context.request.uri.queryParameters.containsKey("provider")) {
    for (final p in [HotelProvider.trvlk, HotelProvider.agoda, HotelProvider.tiket, HotelProvider.expedia, HotelProvider.trip]) {
      var det = await getHotelDetail(
        p,
        context.request.uri.queryParameters['hotel']!,
        context.request.uri.queryParameters['city']!,
        context.request.uri.queryParameters['addr'] ?? '',
      );
      if (det['success'] as bool) {
        box.put(hashid, json.encode(det));
        return Response.json(body: det);
      }
    }
    Response.json(body: {"success": false, "msg": "not found.."});
  } else {
    var r = await getHotelDetail(
      prov["${context.request.uri.queryParameters['provider']}"]!,
      context.request.uri.queryParameters['hotel']!,
      context.request.uri.queryParameters['city']!,
      context.request.uri.queryParameters['addr'] ?? '',
    );
    box.put(hashid, json.encode(r));
    return Response.json(body: r);
  }
  return Response.json(body: {"success": false, "msg": "not found,"});
}

Future<dynamic> getHotelDetail(HotelProvider PROVIDER, String HOTEL, String city, String addr) async {
  var VQD_REGEX = RegExp(r"vqd='(\d+-\d+-\d+)");
  var SEARCH_REGEX = RegExp(r"DDG\.pageLayout\.load\('d',(\[.+\])\);DDG\.duckbar\.load\('images'");
  var UA =
      'Mozilla/5.0 (Linux; Android 12; SM-S906N Build/QP1A.190711.020; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/80.0.3987.119 Mobile Safari/537.36';
  var http = io.Dio(io.BaseOptions(headers: {
    "User-Agent": UA,
    "Accept-Language": "id-id",
  }));
  var SITE = "trip.com";
  var SITE_URL_FILTER = RegExp(r"www.trip.com");
  switch (PROVIDER) {
    case HotelProvider.trip:
      SITE = "trip.com";
      SITE_URL_FILTER = RegExp(r"www.trip.com/hotels/");
      break;
    case HotelProvider.trvlk:
      SITE = "traveloka.com";
      SITE_URL_FILTER = RegExp(r"/id-id/hotel/.*\d+$");
      break;
    case HotelProvider.tiket:
      SITE = "tiket.com";
      SITE_URL_FILTER = RegExp(r"www.tiket.com/hotel/");
      break;
    case HotelProvider.agoda:
      SITE = "agoda.com";
      SITE_URL_FILTER = RegExp(r"/id-id/.*-id\.html");
      break;
    case HotelProvider.expedia:
      SITE = "expedia.co.id";
      SITE_URL_FILTER = RegExp(r"expedia.co.id/.*h\d+.Hotel-Information");
      break;
    default:
  }
//  var HOTEL = "le eminence puncak";
  var QUERY = "site:$SITE hotel $HOTEL di $city jalan $addr";
  var html = await io.Dio().get("https://duckduckgo.com/?q=${Uri.encodeComponent(QUERY)}&ia=web");
  var fqd = VQD_REGEX.firstMatch("${html.data}");
  if (fqd != null) {
    var sr = await io.Dio().get(
        "https://links.duckduckgo.com/d.js?q=${Uri.encodeComponent(QUERY)}&vqd=${fqd.group(1)}&kl=id-id&l=en-us&dl=en&ct=ID&sp=1&df=a&ss_mkt=id&s=0&bpa=1&biaexp=b&msvrtexp=b&nadse=b&eclsexp=b&tjsexp=b");
    if (!"${sr.data}".contains("DDG.deep.is506")) {
      var data = json.decode(SEARCH_REGEX.firstMatch("${sr.data}")?.group(1) ?? "[]") as List<dynamic>;
      data = data
          .where((e) =>
              SITE_URL_FILTER.hasMatch("${e['u']}") && !"${e['u']}".contains("/area/") && !"${e['u']}".contains("/landmark/"))
          .toList();
      // for (var e in data) {
      //   print(e['u']);
      // }
      if (data.isEmpty) return {"success": false, "msg": "not found"};

      var HOTEL_URL = "${data.first['u']}";
      dynamic HOTEL_DATA = {};
      var HOTEL_NAME = "";
      var _errMsg = "";
      var HOTEL_DATA_PARSED = {};
      switch (PROVIDER) {
        case HotelProvider.trip:
          HOTEL_URL = HOTEL_URL.replaceAll("www.trip.com", "id.trip.com");
          try {
            var r = await http.get(HOTEL_URL);
            if ("${r.data}".contains("hotelBaseData")) {
              var jj = json.decode(("${r.data}".split("window.IBU_HOTEL =")[1].split("__webpack_public_path__=")[0]).trim());
              var mydata = {
                "hotelBaseData": jj["initData"]["hotelBaseData"],
                "hotelFacilityPop": jj["initData"]["hotelFacilityPop"],
                "staticHotelInfo": jj["initData"]["staticHotelInfo"]
              };
              var res = await io.Dio().post("https://www.trip.com/restapi/soa2/16708/json/detailMap",
                  data: {"masterHotelId": jj["initData"]["masterHotelId"]});
              HOTEL_NAME = "${mydata["hotelBaseData"]["baseInfo"]["hotelNameLocale"]}";
              HOTEL_DATA = mydata;
              HOTEL_DATA_PARSED = {
                "name": "${HOTEL_DATA['hotelBaseData']['baseInfo']['hotelNameLocale']}",
                "rating": HOTEL_DATA['hotelBaseData']['baseInfo']['star'],
                "desc": "${HOTEL_DATA['staticHotelInfo']['hotelInfo']['basic']['description']}",
                "sort_desc": "",
                "thumb": "https:${HOTEL_DATA['staticHotelInfo']['hotelInfo']['basic']['image'][0]}",
                "addr": {
                  "city": "${HOTEL_DATA['hotelBaseData']['baseInfo']['cityName']}",
                  "country": "",
                  "area": "",
                  "addr": "${HOTEL_DATA['hotelBaseData']['mapInfo']['address']}",
                  "lat": double.parse("${res.data['Response']['hotelDetail']['lat']}"),
                  "lng": double.parse("${res.data['Response']['hotelDetail']['lng']}")
                },
                "poi": (res.data['Response']['placeInfoList'] as List<dynamic>)
                    .expand((e) => (e['tabList'] as List<dynamic>).map((ee) => {
                          "cat": ee['type'],
                          "ic": "",
                          "name": ee['title'],
                          "distanceTxt": ee['subTitle'],
                          "lat": double.parse("${ee['lat']}"),
                          "lng": double.parse("${ee['lng']}"),
                          "photo": ee['imgUrl'] == null ? '' : "https:${ee['imgUrl']}"
                        }))
                    .toList(),
                "photos": (HOTEL_DATA['hotelBaseData']['hotelImg']['imgUrlList'] as List<dynamic>)
                    .map((e) => {"cat": e['imgTitle'], "desc": "", "url": e['imgUrl']})
                    .toList(),
                "facilities": (HOTEL_DATA['hotelFacilityPop']['hotelFacility'] as List<dynamic>)
                    .map((e) => {
                          "title": e['title'],
                          "ic": e['facilityName'],
                          "features": (e['list'] as List<dynamic>)
                              .map((ee) => {
                                    "name": ee['facilityDesc'],
                                    "ic": ee['facilityName'],
                                    "photo": "",
                                  })
                              .toList()
                        })
                    .toList()
              };
            }
          } catch (ee) {
            _errMsg = "$ee";
          }
          break;
        case HotelProvider.agoda:
          try {
            var r = await http.post("https://www.agoda.com/api/gw/property/getProperty",
                data: {"url": "/${HOTEL_URL.split("agoda.com/")[1].split(".html")[0]}.html"},
                options: io.Options(headers: {
                  "User-Agent": UA,
                  "Content-Type": "application/json",
                }));
            HOTEL_DATA = r.data;
            HOTEL_NAME = "${r.data['summary']['propertyName']['displayName']}";
            HOTEL_DATA_PARSED = {
              "name": "${HOTEL_DATA['summary']['propertyName']['displayName']}",
              "rating": double.parse("${HOTEL_DATA['summary']['starRating']['rating']}").toInt(),
              "desc": removeAllHtmlTags("${HOTEL_DATA['description']['long']}"),
              "sort_desc": "${HOTEL_DATA['description']['short']}",
              "thumb": (HOTEL_DATA['images'] as List<dynamic>).isNotEmpty
                  ? "${(HOTEL_DATA['images'] as List<dynamic>).first['urls']['retina']}"
                  : "",
              "addr": {
                "city": "${HOTEL_DATA['summary']['address']['cityName']}",
                "country": "",
                "area": "${HOTEL_DATA['summary']['address']['areaName']}",
                "addr": "${HOTEL_DATA['summary']['address']['address1']}",
                "lat": double.parse("${HOTEL_DATA['summary']['coordinate']['lat']}"),
                "lng": double.parse("${HOTEL_DATA['summary']['coordinate']['lng']}")
              },
              "poi": (HOTEL_DATA['interestPoints'] as List<dynamic>)
                  .map((ee) => {
                        "cat": ee['type'],
                        "ic": "",
                        "name": ee['name'],
                        "distanceTxt": "${ee['distance']['value']} km",
                        "lat": double.parse("${ee['location']['lat']}"),
                        "lng": double.parse("${ee['location']['lng']}"),
                        "photo": ""
                      })
                  .toList(),
              "photos": (HOTEL_DATA['images'] as List<dynamic>)
                  .map((e) => {"cat": e['category'], "desc": e['caption'], "url": e['urls']['superRetina']})
                  .toList(),
              "facilities": (HOTEL_DATA['features']['facilities'] as List<dynamic>)
                  .map((e) => {
                        "title": e['name'],
                        "ic": '',
                        "features": (e['features'] as List<dynamic>)
                            .map((ee) => {
                                  "name": ee['name'],
                                  "ic": ee['symbol'],
                                  "photo": (ee['images'] as List<dynamic>).isNotEmpty
                                      ? "https://${(ee['images'] as List<dynamic>).first['urls']['normal']}"
                                      : '',
                                })
                            .toList()
                      })
                  .toList()
            };
          } catch (ee) {
            _errMsg = "$ee";
          }
          // File("out.json").writeAsStringSync(json.encode(HOTEL_DATA));
          break;
        case HotelProvider.tiket:
          try {
            var r = await http.get(HOTEL_URL);
            var dd = json.decode("${r.data}".split("__NEXT_DATA__\" type=\"application/json\">")[1].split("</script>")[0]);
            HOTEL_DATA = dd['props']['pageProps'];
            HOTEL_NAME = "${dd['props']['pageProps']['hotelDetailData']['name']}";
            HOTEL_DATA_PARSED = {
              "name": "${HOTEL_DATA['hotelDetailData']['name']}",
              "rating": double.parse("${HOTEL_DATA['hotelDetailData']['starRating']}").toInt(),
              "desc": removeAllHtmlTags("${HOTEL_DATA['hotelDetailData']['generalInfo']['description']}")
                  .replaceAll("\n", "")
                  .replaceAll("\n\n", " "),
              "sort_desc": "",
              "thumb": HOTEL_DATA['hotelDetailData']['mainImage']['url'],
              "addr": {
                "city": "${HOTEL_DATA['hotelDetailData']['city']['name']}",
                "country": "${HOTEL_DATA['hotelDetailData']['country']['name']}",
                "area": "${HOTEL_DATA['hotelDetailData']['area']['name']}",
                "addr": "${HOTEL_DATA['hotelDetailData']['address']}",
                "lat": double.parse("${HOTEL_DATA['hotelDetailData']['location']['coordinates']['latitude']}"),
                "lng": double.parse("${HOTEL_DATA['hotelDetailData']['location']['coordinates']['longitude']}")
              },
              "poi": (HOTEL_DATA['hotelDetailData']['nearbyDestination']['items'] as List<dynamic>)
                  .map((ee) => {
                        "cat": ee['category'],
                        "ic": "",
                        "name": ee['title'],
                        "distanceTxt": "${ee['distance']}",
                        "lat": double.parse("${ee['latitude']}"),
                        "lng": double.parse("${ee['longitude']}"),
                        "photo": ""
                      })
                  .toList(),
              "photos": (HOTEL_DATA['hotelDetailData']['images'] as List<dynamic>)
                  .map((e) => {"cat": e['caption'], "desc": e['category'], "url": e['url']})
                  .toList(),
              "facilities": (HOTEL_DATA['hotelDetailData']['groupFacilities'] as List<dynamic>)
                  .map((e) => {
                        "title": e['name'],
                        "ic": e['icon'],
                        "features": (e['detail'] as List<dynamic>)
                            .map((ee) => {
                                  "name": ee,
                                  "ic": '',
                                  "photo": '',
                                })
                            .toList()
                      })
                  .toList()
            };
          } catch (ee) {
            _errMsg = "$ee";
          }
          break;
        case HotelProvider.trvlk:
          try {
            var r = await http.get(HOTEL_URL);
            //print("trvl url: $HOTEL_URL");
            var dd = json.decode("${r.data}".split("window.staticProps = ")[1].split(";\n")[0]);
            //File("outx_test.json").writeAsStringSync(json.encode(dd));
            HOTEL_NAME = "${dd['hotelDetailData']['name']}";
            HOTEL_DATA = dd['hotelDetailData'];
            HOTEL_DATA_PARSED = {
              "name": "${HOTEL_DATA['name']}",
              "rating": double.parse("${HOTEL_DATA['starRating']}").toInt(),
              "desc": removeAllHtmlTags("${HOTEL_DATA['attribute']['description']}").replaceAll("\n", "").replaceAll("\n\n", " "),
              "sort_desc":
                  removeAllHtmlTags("${HOTEL_DATA['attribute']['overview']}").replaceAll("\n", "").replaceAll("\n\n", " "),
              "thumb": (HOTEL_DATA['assets'] as List<dynamic>).isNotEmpty
                  ? "${(HOTEL_DATA['assets'] as List<dynamic>).first['url']}"
                  : "",
              "addr": {
                "city": "${HOTEL_DATA['city']}",
                "country": "${HOTEL_DATA['country']}",
                "area": "${HOTEL_DATA['hotelGeoInfo']}",
                "addr": "${HOTEL_DATA['address']}",
                "lat": double.parse("${HOTEL_DATA['latitude']}"),
                "lng": double.parse("${HOTEL_DATA['longitude']}")
              },
              "poi": (HOTEL_DATA['nearestPointOfInterests'] as List<dynamic>)
                  .map((ee) => {
                        "cat": ee['landmarkType'],
                        "ic": "",
                        "name": ee['name'],
                        "distanceTxt": "${ee['distance']} km",
                        "lat": double.parse("${ee['latitude']}"),
                        "lng": double.parse("${ee['longitude']}"),
                        "photo": ""
                      })
                  .toList(),
              "photos": (HOTEL_DATA['assets'] as List<dynamic>)
                  .map((e) => {"cat": e['caption'] ?? e['category'], "desc": e['category'], "url": e['url']})
                  .toList(),
              "facilities": (HOTEL_DATA['hotelFacilitiesCategoriesDisplay'] as List<dynamic>)
                  .map((e) => {
                        "title": e['name'],
                        "ic": e['iconUrl'],
                        "features": (e['hotelFacilityDisplays'] as List<dynamic>)
                            .map((ee) => {
                                  "name": ee['name'],
                                  "ic": '',
                                  "photo": '',
                                })
                            .toList()
                      })
                  .toList()
            };
          } catch (ee) {
            _errMsg = "$ee";
          }
          break;
        case HotelProvider.expedia:
          //print("exp: $HOTEL_URL");
          var r = await http.get(HOTEL_URL);

          var rr = '{"__typename' +
              ("${r.data}"
                      .split("<script>")[1]
                      .split(RegExp(r'\\"PropertyInfo:\d+\\":{\\"__typename'))[1]
                      .split('},\\"clientInfo\\"')[0]
                      .split(',\\"InlineNotification')[0]
                      .replaceAll('\\\\\\"', '\''))
                  .replaceAll('\\"', '"')
                  .replaceAll('\\u002F', "/");
          //File("outx_test.json").writeAsStringSync(rr);
          var data = json.decode(rr) as Map<String, dynamic>;
          var d = {};
          data.forEach((key, value) {
            d[key.contains("(") ? key.split('(')[0] : key] = value;
          });
          HOTEL_DATA = d;
          HOTEL_NAME = "${d['summary']['name']}";
          var amanitiesKey = (HOTEL_DATA['summary'] as Map<String, dynamic>).keys.firstWhere((e) => "$e".startsWith("amenities"));
          var fcontent = (HOTEL_DATA['summary'][amanitiesKey]['amenities'] as List<dynamic>)
              .expand((e) => e['contents'] as List<dynamic>)
              .toList();
          fcontent.addAll(HOTEL_DATA['summary'][amanitiesKey]['takeover']['highlight'] as List<dynamic>);
          fcontent.addAll(HOTEL_DATA['summary'][amanitiesKey]['takeover']['property'] as List<dynamic>);
          //print(fcontent);
          HOTEL_DATA_PARSED = {
            "name": "${d['summary']['name']}",
            "rating": double.parse("${HOTEL_DATA['summary']['overview']['starRating']}"),
            "desc": removeAllHtmlTags(
                "${(HOTEL_DATA['summary']['location']['whatsAround']['editorial']['content'] as List<dynamic>).join('\n. ')}"),
            "sort_desc": '',
            "thumb": HOTEL_DATA['propertyGallery']['images'][0]['image']['url'],
            "addr": {
              "city": "${HOTEL_DATA['summary']['location']['address']['city']}",
              "country": "${HOTEL_DATA['summary']['location']['address']['countryCode']}",
              "area": "${HOTEL_DATA['summary']['location']['address']['province']}",
              "addr": "${HOTEL_DATA['summary']['location']['address']['firstAddressLine']}",
              "lat": double.parse("${HOTEL_DATA['summary']['location']['coordinates']['latitude']}"),
              "lng": double.parse("${HOTEL_DATA['summary']['location']['coordinates']['longitude']}")
            },
            "poi": (HOTEL_DATA['summary']['location']['whatsAround']['nearbyPOIs'] as List<dynamic>)
                .expand((e) => (e['items'] as List<dynamic>).map((ee) => {
                      "cat": ee['__typename'],
                      "ic": ee['icon'] != null ? ee['icon']['place'] : '',
                      "name": ee['text'],
                      "distanceTxt": "${ee['moreInfo']}",
                      "lat": 0,
                      "lng": 0,
                      "photo": ""
                    }))
                .toList(),
            "photos": (HOTEL_DATA['propertyGallery']['categories'] as List<dynamic>)
                .expand((e) =>
                    (e['images'] as List<dynamic>).map((ee) => {"cat": e['name'], "desc": ee['alt'], "url": ee['image']['url']}))
                .toList(),
            "facilities": fcontent
                .map((e) => {
                      "title": e['heading'] ?? e['header']['text'],
                      "ic": '',
                      "features": e['items']
                          .map((ee) => {
                                "name": ee['text'],
                                "ic": e['icon'] != null ? e['icon']['id'] : '',
                                "photo": '',
                              })
                          .toList()
                    })
                .toList()
          };
          // File("outx_test.json").writeAsStringSync(rr);
          // print(json.decode(rr));
          break;
        default:
      }
      if (HOTEL_NAME.isNotEmpty) {
        // File("outx_$PROVIDER.json").writeAsStringSync(json.encode(HOTEL_DATA_PARSED));
        // print(HOTEL_NAME);
        return {
          "success": true,
          "data": HOTEL_DATA_PARSED,
          "status": {
            "hotel_name": HOTEL_NAME,
            "query": HOTEL,
            "match": HOTEL.toLowerCase().similarityTo(HOTEL_NAME.toLowerCase()),
            "provider": PROVIDER.toString(),
            "hotel_url": HOTEL_URL
          }
        };
      } else {
        if (_errMsg.isNotEmpty) return {"success": false, "msg": _errMsg};
        return {"success": false, "msg": "not found."};
      }
    } else {
      return {"success": false, "msg": "error ddg"};
    }
  } else {
    return {"success": false, "msg": "error ddg, fqd not found"};
  }
}

enum HotelProvider { trip, tiket, trvlk, agoda, expedia }

String removeAllHtmlTags(String htmlText) {
  RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);

  return htmlText.replaceAll(exp, '').replaceAll("&nbsp;", "").replaceAll("&amp;", "");
}
