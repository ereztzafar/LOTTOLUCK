class City {
  final String name;
  final String country;
  final double latitude;
  final double longitude;

  City({
    required this.name,
    required this.country,
    required this.latitude,
    required this.longitude,
  });

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      name: json['name'],
      country: json['country'],
      latitude: double.tryParse(json['lat'].toString()) ?? 0.0,
      longitude: double.tryParse(json['lng'].toString()) ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'country': country,
      'lat': latitude,
      'lng': longitude,
    };
  }

  @override
  String toString() {
    return '$name, $country';
  }
}
