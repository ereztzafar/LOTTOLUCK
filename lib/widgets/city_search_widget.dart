// lib/widgets/city_search_widget.dart
import 'package:flutter/material.dart';
import '../services/city_service.dart';
import '../models/city.dart'; // המודל שלך שבו יש name, latitude, longitude

class CitySearchWidget extends StatefulWidget {
  final void Function(City city) onCitySelected;
  const CitySearchWidget({super.key, required this.onCitySelected});

  @override
  State<CitySearchWidget> createState() => _CitySearchWidgetState();
}

class _CitySearchWidgetState extends State<CitySearchWidget> {
  final TextEditingController _ctrl = TextEditingController();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    CityService.I.warmUp().then((_) {
      if (mounted) setState(() => _ready = true);
    }).catchError((e) {
      if (mounted) {
        setState(() => _ready = true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('שגיאה בטעינת ערים: $e')));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      );
    }

    return Autocomplete<CityRow>(
      displayStringForOption: (c) => '${c.city}, ${c.country}',
      optionsBuilder: (TextEditingValue te) async {
        return await CityService.I.search(te.text);
      },
      onSelected: (CityRow row) {
        // צור מופע City לפי המודל שלך
        final city = City(
          name: row.city,
          latitude: row.lat,
          longitude: row.lon,
        );
        _ctrl.text = row.city;
        widget.onCitySelected(city);
      },
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        return TextField(
          controller: textController,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'עיר',
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.location_city),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final list = options.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300, maxWidth: 600),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: list.length,
                itemBuilder: (ctx, i) {
                  final c = list[i];
                  return ListTile(
                    title: Text('${c.city}, ${c.country}'),
                    subtitle: c.tz == null ? null : Text(c.tz!),
                    onTap: () => onSelected(c),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
