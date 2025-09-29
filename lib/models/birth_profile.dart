class BirthProfile {
  final String cityName;
  final double lat;
  final double lon;
  final String tzId;          // למשל: "Asia/Jerusalem"
  final String birthDateDmy;  // "22/11/1970"
  final String birthTimeHm;   // "06:00"

  const BirthProfile({
    required this.cityName,
    required this.lat,
    required this.lon,
    required this.tzId,
    required this.birthDateDmy,
    required this.birthTimeHm,
  });

  Map<String, dynamic> toJson() => {
        'cityName': cityName,
        'lat': lat,
        'lon': lon,
        'tzId': tzId,
        'birthDateDmy': birthDateDmy,
        'birthTimeHm': birthTimeHm,
      };

  factory BirthProfile.fromJson(Map<String, dynamic> j) => BirthProfile(
        cityName: j['cityName'],
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        tzId: j['tzId'],
        birthDateDmy: j['birthDateDmy'],
        birthTimeHm: j['birthTimeHm'],
      );
}
