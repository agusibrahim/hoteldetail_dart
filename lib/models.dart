// Annotate a Dart class to create a box
import 'package:objectbox/objectbox.dart';

import 'dart:convert';

T? asT<T>(dynamic value) {
  if (value is T) {
    return value;
  }
  return null;
}

@Entity()
class HotelCache {
  HotelCache(this.hotel, this.status, this.hashId, {this.externalId = "", this.date});
  @Id()
  int id = 0;
  String externalId = "";
  String hashId = "";
  @Property(type: PropertyType.date) // Store as int in milliseconds
  DateTime? date;
  var hotel = ToOne<HotelItem>();
  var status = ToOne<HotelResultStatus>();
}

@Entity()
class HotelItem {
  HotelItem({
    required this.name,
    required this.rating,
    required this.desc,
    required this.sortDesc,
    required this.thumb,
    required this.addr,
    required this.poi,
    required this.photos,
    required this.facilities,
  });

  factory HotelItem.fromJson(Map<String, dynamic> json) {
    final List<HotelPoi>? poi = json['poi'] is List ? <HotelPoi>[] : null;
    if (poi != null) {
      for (final dynamic item in json['poi'] as List<dynamic>) {
        if (item != null) {
          poi.add(HotelPoi.fromJson(asT<Map<String, dynamic>>(item)!));
        }
      }
    }

    final List<HotelPhotos>? photos = json['photos'] is List ? <HotelPhotos>[] : null;
    if (photos != null) {
      for (final dynamic item in json['photos'] as List<dynamic>) {
        if (item != null) {
          photos.add(HotelPhotos.fromJson(asT<Map<String, dynamic>>(item)!));
        }
      }
    }

    final List<HotelFacilities>? facilities = json['facilities'] is List ? <HotelFacilities>[] : null;
    if (facilities != null) {
      for (final dynamic item in json['facilities'] as List<dynamic>) {
        if (item != null) {
          facilities.add(HotelFacilities.fromJson(asT<Map<String, dynamic>>(item)!));
        }
      }
    }
    return HotelItem(
      name: asT<String>(json['name'])!,
      rating: asT<int>(json['rating']) ?? 0,
      desc: asT<String>(json['desc'])!,
      sortDesc: asT<String>(json['sort_desc']) ?? '',
      thumb: asT<String>(json['thumb'])!,
      addr: ToOne(target: Addr.fromJson(asT<Map<String, dynamic>>(json['addr'])!)),
      poi: ToMany<HotelPoi>(items: poi ?? []),
      photos: ToMany(items: photos ?? []),
      facilities: ToMany(items: facilities ?? []),
    );
  }
  @Id()
  int id = 0;

  String name;
  int rating;
  String desc;
  String sortDesc;
  String thumb;
  var addr = ToOne<Addr>();
  var poi = ToMany<HotelPoi>();
  var photos = ToMany<HotelPhotos>();
  var facilities = ToMany<HotelFacilities>();

  @override
  String toString() {
    return jsonEncode(this);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'rating': rating,
        'desc': desc,
        'sort_desc': sortDesc,
        'thumb': thumb,
        'addr': addr.target,
        'poi': poi.toList(),
        'photos': photos.toList(),
        'facilities': facilities.toList(),
      };

  HotelItem copy() {
    return HotelItem(
      name: name,
      rating: rating,
      desc: desc,
      sortDesc: sortDesc,
      thumb: thumb,
      addr: ToOne(target: addr.target!.copy()),
      poi: ToMany(items: poi.map((HotelPoi e) => e.copy()).toList()),
      photos: ToMany(items: photos.map((HotelPhotos e) => e.copy()).toList()),
      facilities: ToMany(items: facilities.map((HotelFacilities e) => e.copy()).toList()),
    );
  }
}

@Entity()
class Addr {
  Addr({
    required this.city,
    required this.country,
    required this.area,
    required this.addr,
    required this.lat,
    required this.lng,
  });

  factory Addr.fromJson(Map<String, dynamic> json) => Addr(
        city: asT<String>(json['city'])!,
        country: asT<String>(json['country'])!,
        area: asT<String>(json['area'])!,
        addr: asT<String>(json['addr'])!,
        lat: asT<double>(json['lat']) ?? 0,
        lng: asT<double>(json['lng']) ?? 0,
      );
  @Id()
  int id = 0;
  String city;
  String country;
  String area;
  String addr;
  double lat;
  double lng;

  @override
  String toString() {
    return jsonEncode(this);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'city': city,
        'country': country,
        'area': area,
        'addr': addr,
        'lat': lat,
        'lng': lng,
      };

  Addr copy() {
    return Addr(
      city: city,
      country: country,
      area: area,
      addr: addr,
      lat: lat,
      lng: lng,
    );
  }
}

@Entity()
class HotelPoi {
  HotelPoi({
    required this.cat,
    required this.ic,
    required this.name,
    required this.distanceTxt,
    required this.lat,
    required this.lng,
    required this.photo,
  });

  factory HotelPoi.fromJson(Map<String, dynamic> json) => HotelPoi(
        cat: asT<String>(json['cat']) ?? '',
        ic: asT<String>(json['ic']) ?? '',
        name: asT<String>(json['name']) ?? '',
        distanceTxt: asT<String>(json['distanceTxt']) ?? '',
        lat: asT<double>(json['lat']) ?? 0,
        lng: asT<double>(json['lng']) ?? 0,
        photo: asT<String>(json['photo']) ?? '',
      );

  @Id()
  int id = 0;
  String cat;
  String ic;
  String name;
  String distanceTxt;
  double lat;
  double lng;
  String photo;

  @override
  String toString() {
    return jsonEncode(this);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'cat': cat,
        'ic': ic,
        'name': name,
        'distanceTxt': distanceTxt,
        'lat': lat,
        'lng': lng,
        'photo': photo,
      };

  HotelPoi copy() {
    return HotelPoi(
      cat: cat,
      ic: ic,
      name: name,
      distanceTxt: distanceTxt,
      lat: lat,
      lng: lng,
      photo: photo,
    );
  }
}

@Entity()
class HotelPhotos {
  HotelPhotos({
    required this.cat,
    required this.desc,
    required this.url,
  });

  factory HotelPhotos.fromJson(Map<String, dynamic> json) => HotelPhotos(
        cat: asT<String>(json['cat']) ?? '',
        desc: asT<String>(json['desc']) ?? '',
        url: asT<String>(json['url']) ?? '',
      );
  @Id()
  int id = 0;
  String cat;
  String desc;
  String url;

  @override
  String toString() {
    return jsonEncode(this);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'cat': cat,
        'desc': desc,
        'url': url,
      };

  HotelPhotos copy() {
    return HotelPhotos(
      cat: cat,
      desc: desc,
      url: url,
    );
  }
}

@Entity()
class HotelFacilities {
  HotelFacilities({
    required this.title,
    required this.ic,
    required this.features,
  });

  factory HotelFacilities.fromJson(Map<String, dynamic> json) {
    final List<HotelFeatures>? features = json['features'] is List ? <HotelFeatures>[] : null;
    if (features != null) {
      for (final dynamic item in json['features'] as List<dynamic>) {
        if (item != null) {
          features.add(HotelFeatures.fromJson(asT<Map<String, dynamic>>(item)!));
        }
      }
    }
    return HotelFacilities(
      title: asT<String>(json['title']) ?? '',
      ic: asT<String>(json['ic']) ?? '',
      features: ToMany(items: features ?? []),
    );
  }
  @Id()
  int id = 0;
  String title;
  String ic;
  var features = ToMany<HotelFeatures>();

  @override
  String toString() {
    return jsonEncode(this);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'ic': ic,
        'features': features.toList(),
      };

  HotelFacilities copy() {
    return HotelFacilities(
      title: title,
      ic: ic,
      features: ToMany(items: features.map((HotelFeatures e) => e.copy()).toList()),
    );
  }
}

@Entity()
class HotelFeatures {
  HotelFeatures({
    required this.name,
    required this.ic,
    required this.photo,
  });

  factory HotelFeatures.fromJson(Map<String, dynamic> json) => HotelFeatures(
        name: asT<String>(json['name'])!,
        ic: asT<String>(json['ic'])!,
        photo: asT<String>(json['photo'])!,
      );
  @Id()
  int id = 0;
  String name;
  String ic;
  String photo;

  @override
  String toString() {
    return jsonEncode(this);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'ic': ic,
        'photo': photo,
      };

  HotelFeatures copy() {
    return HotelFeatures(
      name: name,
      ic: ic,
      photo: photo,
    );
  }
}

@Entity()
class HotelResultStatus {
  HotelResultStatus({
    required this.hotelName,
    required this.query,
    required this.match,
    required this.provider,
    required this.hotelUrl,
  });

  factory HotelResultStatus.fromJson(Map<String, dynamic> json) => HotelResultStatus(
        hotelName: asT<String>(json['hotel_name'])!,
        query: asT<String>(json['query'])!,
        match: asT<double>(json['match'])!,
        provider: asT<String>(json['provider'])!,
        hotelUrl: asT<String>(json['hotel_url'])!,
      );
  @Id()
  int id = 0;
  String hotelName;
  String query;
  double match;
  String provider;
  String hotelUrl;

  @override
  String toString() {
    return jsonEncode(this);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'hotel_name': hotelName,
        'query': query,
        'match': match,
        'provider': provider,
        'hotel_url': hotelUrl,
      };

  HotelResultStatus copy() {
    return HotelResultStatus(
      hotelName: hotelName,
      query: query,
      match: match,
      provider: provider,
      hotelUrl: hotelUrl,
    );
  }
}
