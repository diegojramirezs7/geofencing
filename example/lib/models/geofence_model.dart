import 'dart:convert';

List<Geofence> geofencesFromRawJson(String str) =>
    List<Geofence>.from(json.decode(str).map((x) => Geofence.fromJson(x)));

List<Geofence> geofencesFromJson(List geofences) =>
    List<Geofence>.from(geofences.map((e) => Geofence.fromJson(e)));

class Geofence {
  double lat;
  double lng;
  int radius;
  String name;
  int id;

  Geofence({this.lat, this.lng, this.radius, this.name, this.id});

  factory Geofence.fromRawJson(String str) =>
      Geofence.fromJson(json.decode(str));

  factory Geofence.fromJson(Map<String, dynamic> json) => Geofence(
        id: json['id'] == null ? null : json['id'],
        lat: json['lat'] == null ? null : json['lat'],
        lng: json['lng'] == null ? null : json['lng'],
        radius: json['radius'] == null ? null : json['radius'],
        name: json['name'] == null ? null : json['name'],
      );

  Map<String, dynamic> toJson() => {
        "lat": lat == null ? null : lat,
        "lng": lng == null ? null : lng,
        "radius": radius == null ? null : radius,
        "name": name == null ? null : name,
        "id": id == null ? null : id
      };
}
