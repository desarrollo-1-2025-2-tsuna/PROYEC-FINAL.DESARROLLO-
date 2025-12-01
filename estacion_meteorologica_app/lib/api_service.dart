import 'dart:convert';
import 'package:http/http.dart' as http;

/// Ajusta esta URL si cambias el puerto o si corres en otro dispositivo.
/// - Backend en tu mismo PC: http://127.0.0.1:8000
/// - Android emulador: http://10.0.2.2:8000
class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000';

  // -------- Modelo de medición --------
  // Debe coincidir con los nombres del backend:
  //  "precipitacion", "velocidad_viento",
  //  "presion_atmosferica", "temperatura", "humedad"
}

class Medicion {
  final String? id;
  final double precipitacion;
  final double velocidadViento;
  final double presionAtmosferica;
  final double temperatura;
  final double humedad;
  final DateTime? timestamp;

  Medicion({
    this.id,
    required this.precipitacion,
    required this.velocidadViento,
    required this.presionAtmosferica,
    required this.temperatura,
    required this.humedad,
    this.timestamp,
  });

  factory Medicion.fromJson(Map<String, dynamic> json) {
    double _toDouble(dynamic v) =>
        v == null ? 0 : (v is num ? v.toDouble() : double.parse(v.toString()));

    return Medicion(
      id: json['_id']?.toString(),
      precipitacion: _toDouble(json['precipitacion']),
      velocidadViento: _toDouble(json['velocidad_viento']),
      presionAtmosferica: _toDouble(json['presion_atmosferica']),
      temperatura: _toDouble(json['temperatura']),
      humedad: _toDouble(json['humedad']),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'precipitacion': precipitacion,
      'velocidad_viento': velocidadViento,
      'presion_atmosferica': presionAtmosferica,
      'temperatura': temperatura,
      'humedad': humedad,
      // el backend pone el timestamp si no lo mandamos
      if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
    };
  }
}

// --------- Funciones para llamar a la API ---------

extension ApiMediciones on ApiService {
  static Future<List<Medicion>> listarMediciones({int limit = 100}) async {
    final uri = Uri.parse('$baseUrl/mediciones?limit=$limit');
    final resp = await http.get(uri);

    if (resp.statusCode != 200) {
      throw Exception('Error al listar mediciones: ${resp.body}');
    }

    final List data = jsonDecode(resp.body);
    return data.map((e) => Medicion.fromJson(e)).toList();
  }

  static Future<Medicion> crearMedicion(Medicion m) async {
    final uri = Uri.parse('$baseUrl/mediciones');
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(m.toJson()),
    );

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception('Error al crear medición: ${resp.body}');
    }

    final data = jsonDecode(resp.body);
    return Medicion.fromJson(data);
  }

  static Future<void> eliminarMedicion(String id) async {
    final uri = Uri.parse('$baseUrl/mediciones/$id');
    final resp = await http.delete(uri);

    if (resp.statusCode != 200) {
      throw Exception('Error al eliminar medición: ${resp.body}');
    }
  }

  static Future<void> eliminarTodas() async {
    final uri = Uri.parse('$baseUrl/mediciones');
    final resp = await http.delete(uri);

    if (resp.statusCode != 200) {
      throw Exception('Error al eliminar todas: ${resp.body}');
    }
  }
}
