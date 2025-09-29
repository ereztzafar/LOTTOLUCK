import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:lottoluck/models/city.dart'; // ✅ שימוש במחלקת City המקורית

class CitySearchWidget extends StatefulWidget {
  final Function(City) onCitySelected;

  const CitySearchWidget({super.key, required this.onCitySelected});

  @override
  _CitySearchWidgetState createState() => _CitySearchWidgetState();
}

class _CitySearchWidgetState extends State<CitySearchWidget> {
  List<City> _cities = [];
  List<City> _filteredCities = [];
  final TextEditingController _controller = TextEditingController();
  bool _showSuggestions = true; // ✅ משתנה חדש לשליטה על התצוגה

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  Future<void> _loadCities() async {
    final rawData = await rootBundle.loadString('assets/worldcities.csv');
    List<List<dynamic>> csvTable = const CsvToListConverter().convert(rawData);

    List<City> cities = [];
    for (int i = 1; i < csvTable.length; i++) {
      try {
        final row = csvTable[i];
        final name = row[0].toString();
        final country = row[4].toString();
        final lat = double.parse(row[2].toString());
        final lon = double.parse(row[3].toString());
        cities.add(City(name: name, country: country, latitude: lat, longitude: lon));
      } catch (_) {
        // שורות לא תקינות יידחו
      }
    }

    setState(() {
      _cities = cities;
      _filteredCities = cities;
    });
  }

  void _filterCities(String query) {
    setState(() {
      _showSuggestions = true; // ✅ בכל שינוי טקסט – מציג את הרשימה שוב
      _filteredCities = _cities
          .where((city) => city.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300, // גובה קבוע
      child: Column(
        children: [
          TextField(
            controller: _controller,
            onChanged: _filterCities,
            decoration: const InputDecoration(
              labelText: 'הכנס שם עיר',
              prefixIcon: Icon(Icons.location_city),
            ),
          ),
          const SizedBox(height: 10),
          if (_showSuggestions)
            Expanded(
              child: ListView.builder(
                itemCount: _filteredCities.length,
                itemBuilder: (context, index) {
                  final city = _filteredCities[index];
                  return ListTile(
                    title: Text('${city.name}, ${city.country}'),
                    subtitle: Text('Lat: ${city.latitude}, Lon: ${city.longitude}'),
                    onTap: () {
                      widget.onCitySelected(city);
                      _controller.text = city.name;
                      FocusScope.of(context).unfocus();
                      setState(() {
                        _showSuggestions = false; // ✅ הסתרה לאחר בחירה
                      });
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
