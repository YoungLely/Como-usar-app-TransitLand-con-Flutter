 Future<List<Map<String, dynamic>>> fetchRoutesForRTP({
    int limit = 50,
    int offset = 0,
  }) async {
    final url = Uri.parse('https://transit.land/api/v2/rest/routes');

    final queryParams = {
      'api_key': apiKey,
      'operator_onestop_id': 'o-9g3-reddetransportedepasajeros',
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    final uriWithParams = url.replace(queryParameters: queryParams);

    try {
      final response = await http.get(uriWithParams);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Datos de las rutas del RTP: $data');

        List<Map<String, dynamic>> routes = [];

        for (var route in data['routes']) {
          List<Map<String, dynamic>> routeStops = [];

          // Extraemos los stops si están presentes.
          if (route['stops'] is List) {
            for (var stop in route['stops']) {
              routeStops.add({
                'stop_id': stop['stop_id'],
                'stop_name': stop['stop_name'],
                'latitude': stop['geometry']['coordinates'][1],
                'longitude': stop['geometry']['coordinates'][0],
                'onestop_id': stop['onestop_id'],
                'stop_timezone': stop['stop_timezone'] ?? '',
                'tts_stop_name': stop['tts_stop_name'] ?? ''
              });
            }
          }

          // Extraemos coordenadas del shape si están presentes en la ruta.
          List<LatLng> shapeCoordinates = [];
          if (route['geometry']?['coordinates'] != null) {
            shapeCoordinates = route['geometry']['coordinates']
                .map<LatLng>(
                    (point) => LatLng(point[1], point[0])) // [lon, lat]
                .toList();
          }

          routes.add({
            'route_color': route['route_color'],
            'route_id': route['route_id'],
            'route_short_name': route['route_short_name'] ?? 'Sin nombre',
            'route_long_name': route['route_long_name'] ?? 'Sin nombre',
            'onestop_id': route['onestop_id'],
            'stops': routeStops, // Agregar paradas a la ruta
            'shape_coordinates':
                shapeCoordinates, // Agregar coordenadas de la forma
          });
        }

        print('Rutas encontradas: $routes');
        return routes;
      } else {
        print('Error: ${response.statusCode}, ${response.body}');
        throw Exception('Error al cargar las rutas del RTP');
      }
    } catch (e) {
      print('Exception: $e');
      rethrow;
    }
  }


  /// Decodifica una cadena de polyline en una lista de puntos `LatLng`.
  ///
  /// La codificación de polyline es un algoritmo de compresión con pérdida que 
  /// permite almacenar una serie de coordenadas como una sola cadena. Este método 
  /// decodifica esa cadena de vuelta en una lista de puntos `LatLng`.
  ///
  /// El algoritmo funciona convirtiendo cada carácter en la cadena a su valor ASCII, 
  /// restando 63, y luego realizando una serie de operaciones bit a bit para 
  /// reconstruir los valores originales de latitud y longitud.
  ///
  /// La lista resultante de puntos `LatLng` se puede usar para trazar la polilínea en un mapa.
  ///
  /// Parámetros:
  /// - `polyline`: La cadena de polilínea codificada.
  ///
  /// Retorna:
  /// - Una lista de puntos `LatLng` que representan la polilínea decodificada.
  List<LatLng> decodePolyline(String polyline) {
    List<LatLng> points = [];
    int index = 0, len = polyline.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

