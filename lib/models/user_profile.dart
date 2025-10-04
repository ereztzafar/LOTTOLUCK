class UserProfile {
  final String name;
  final String cityName;
  final String country;
  final double lat;
  final double lon;
  final String birthDate; // yyyy-MM-dd
  final String birthTime; // HH:mm
  final String tz;        // IANA או +HH:MM
  final String houseSystem; // "placidus" | "whole_sign" | "equal"

  UserProfile({
    required this.name,
    required this.cityName,
    required this.country,
    required this.lat,
    required this.lon,
    required this.birthDate,
    required this.birthTime,
    required this.tz,
    required this.houseSystem,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'cityName': cityName,
        'country': country,
        'lat': lat,
        'lon': lon,
        'birthDate': birthDate,
        'birthTime': birthTime,
        'tz': tz,
        'houseSystem': houseSystem,
      };

  factory UserProfile.fromJson(Map<String, dynamic> m) => UserProfile(
        name: m['name'] ?? '',
        cityName: m['cityName'] ?? '',
        country: m['country'] ?? '',
        lat: (m['lat'] as num?)?.toDouble() ?? 0.0,
        lon: (m['lon'] as num?)?.toDouble() ?? 0.0,
        birthDate: m['birthDate'] ?? '',
        birthTime: m['birthTime'] ?? '',
        tz: m['tz'] ?? 'UTC',
        houseSystem: m['houseSystem'] ?? 'placidus',
      );
}
