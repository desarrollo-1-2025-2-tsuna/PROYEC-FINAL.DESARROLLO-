import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// 👉 Cambia esto si el backend corre en otra IP
const String baseUrl = 'http://127.0.0.1:8000';

void main() {
  runApp(const EstacionApp());
}

class EstacionApp extends StatelessWidget {
  const EstacionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Estación Meteorológica',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF050816),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF22C55E),
          brightness: Brightness.dark,
        ),
      ),
      home: const EstacionHomePage(),
    );
  }
}

class Medicion {
  final String id;
  double? precipitacion;
  double? velocidadViento;
  double? presionAtmosferica;
  double? temperatura;
  double? humedad;
  DateTime? timestamp;

  Medicion({
    required this.id,
    this.precipitacion,
    this.velocidadViento,
    this.presionAtmosferica,
    this.temperatura,
    this.humedad,
    this.timestamp,
  });

  factory Medicion.fromJson(Map<String, dynamic> json) {
    return Medicion(
      id: json['_id']?.toString() ?? '',
      precipitacion: (json['precipitacion'] as num?)?.toDouble(),
      velocidadViento: (json['velocidad_viento'] as num?)?.toDouble(),
      presionAtmosferica: (json['presion_atmosferica'] as num?)?.toDouble(),
      temperatura: (json['temperatura'] as num?)?.toDouble(),
      humedad: (json['humedad'] as num?)?.toDouble(),
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
      'timestamp': timestamp?.toUtc().toIso8601String(),
    };
  }
}

class EstacionHomePage extends StatefulWidget {
  const EstacionHomePage({super.key});

  @override
  State<EstacionHomePage> createState() => _EstacionHomePageState();
}

class _EstacionHomePageState extends State<EstacionHomePage> {
  List<Medicion> _mediciones = [];
  Medicion? _ultima;
  bool _cargando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  Future<void> _cargarTodo() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await Future.wait([
        _cargarMediciones(),
        _cargarUltima(),
      ]);
    } catch (e) {
      setState(() {
        _error = 'Error al cargar datos: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  Future<void> _cargarMediciones() async {
    final uri = Uri.parse('$baseUrl/mediciones?limit=100');
    final resp = await http.get(uri);
    if (resp.statusCode == 200) {
      final List data = jsonDecode(resp.body) as List;
      setState(() {
        _mediciones = data.map((e) => Medicion.fromJson(e)).toList();
      });
    } else {
      throw Exception('Error ${resp.statusCode} al cargar mediciones');
    }
  }

  Future<void> _cargarUltima() async {
    final uri = Uri.parse('$baseUrl/mediciones/ultima');
    final resp = await http.get(uri);
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      setState(() {
        _ultima = Medicion.fromJson(data);
      });
    } else if (resp.statusCode == 404) {
      // No hay mediciones todavía
      setState(() {
        _ultima = null;
      });
    } else {
      throw Exception('Error ${resp.statusCode} al cargar última medición');
    }
  }

  Future<void> _crearDemo() async {
    final uri = Uri.parse('$baseUrl/mediciones');
    final now = DateTime.now();

    final body = jsonEncode({
      "precipitacion": 3.5,
      "velocidad_viento": 4.2,
      "presion_atmosferica": 1010.5,
      "temperatura": 22.3,
      "humedad": 65.0,
      "timestamp": now.toUtc().toIso8601String(),
    });

    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      await _cargarTodo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medición demo agregada')),
        );
      }
    } else {
      throw Exception('Error ${resp.statusCode} al crear medición demo');
    }
  }

  Future<void> _crearOModificarMedicion({Medicion? existente}) async {
    final resultado = await showModalBottomSheet<_FormResultado>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF020617),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return _FormularioMedicionSheet(medicion: existente);
      },
    );

    if (resultado == null) return;

    if (resultado.esNuevo) {
      // Crear
      final uri = Uri.parse('$baseUrl/mediciones');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(resultado.toJson()),
      );
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        await _cargarTodo();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Medición creada')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al crear medición: ${resp.statusCode}'),
            ),
          );
        }
      }
    } else {
      // Actualizar
      final uri = Uri.parse('$baseUrl/mediciones/${existente!.id}');
      final resp = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(resultado.toJson()),
      );
      if (resp.statusCode == 200) {
        await _cargarTodo();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Medición actualizada')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al actualizar: ${resp.statusCode}'),
            ),
          );
        }
      }
    }
  }

  Future<void> _eliminarMedicion(Medicion medicion) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF020617),
        title: const Text('Eliminar medición'),
        content: const Text('¿Seguro que quieres eliminar esta medición?'),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          FilledButton(
            child: const Text('Eliminar'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    final uri = Uri.parse('$baseUrl/mediciones/${medicion.id}');
    final resp = await http.delete(uri);

    if (resp.statusCode == 200) {
      await _cargarTodo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medición eliminada')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: ${resp.statusCode}'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Encabezado
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF030712), Color(0xFF022C22)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud, size: 32, color: Colors.white70),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Interfaz Usuario',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Estación Meteorológica',
                        style: TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Actualizar',
                    onPressed: _cargarTodo,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),

            // Barra de acciones
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _cargarTodo,
                      icon: const Icon(Icons.sync),
                      label: const Text('Actualizar lista'),
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _crearOModificarMedicion(),
                      icon: const Icon(Icons.add),
                      label: const Text('Nueva medición'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filledTonal(
                    onPressed: _crearDemo,
                    icon: const Icon(Icons.bolt),
                    tooltip: 'Agregar demo',
                  ),
                ],
              ),
            ),

            // Resumen de última medición
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildResumenCard(),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: RefreshIndicator(
                onRefresh: _cargarTodo,
                child: _cargando
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(child: Text(_error!))
                        : _mediciones.isEmpty
                            ? const Center(
                                child: Text('No hay mediciones todavía'),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.only(
                                  left: 16,
                                  right: 16,
                                  bottom: 16,
                                ),
                                itemCount: _mediciones.length,
                                itemBuilder: (context, index) {
                                  final m = _mediciones[index];
                                  return Dismissible(
                                    key: ValueKey(m.id),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade700,
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24),
                                      child: const Icon(Icons.delete,
                                          color: Colors.white),
                                    ),
                                    confirmDismiss: (_) async {
                                      await _eliminarMedicion(m);
                                      return false; // ya manejamos el borrado
                                    },
                                    child: _buildMedicionCard(m),
                                  );
                                },
                              ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumenCard() {
    if (_ultima == null) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: const [
              Icon(Icons.info_outline, color: Colors.white70),
              SizedBox(width: 12),
              Text('Sin mediciones registradas todavía'),
            ],
          ),
        ),
      );
    }

    final m = _ultima!;
    String fecha = m.timestamp != null
        ? '${m.timestamp!.day.toString().padLeft(2, '0')}/'
            '${m.timestamp!.month.toString().padLeft(2, '0')} '
            '${m.timestamp!.hour.toString().padLeft(2, '0')}:'
            '${m.timestamp!.minute.toString().padLeft(2, '0')}'
        : '—';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.speed, size: 32, color: Colors.white70),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Última medición',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fecha,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      if (m.temperatura != null)
                        _ChipResumen(
                            label: 'Temp', value: '${m.temperatura} °C'),
                      if (m.humedad != null)
                        _ChipResumen(label: 'Humedad', value: '${m.humedad} %'),
                      if (m.velocidadViento != null)
                        _ChipResumen(
                            label: 'Viento',
                            value: '${m.velocidadViento} m/s'),
                      if (m.presionAtmosferica != null)
                        _ChipResumen(
                            label: 'Presión',
                            value: '${m.presionAtmosferica} hPa'),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMedicionCard(Medicion m) {
    String fecha = m.timestamp != null
        ? '${m.timestamp!.day.toString().padLeft(2, '0')}/'
            '${m.timestamp!.month.toString().padLeft(2, '0')} '
            '${m.timestamp!.hour.toString().padLeft(2, '0')}:'
            '${m.timestamp!.minute.toString().padLeft(2, '0')}'
        : 'Fecha desconocida';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        title: Text(
          fecha,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              if (m.temperatura != null)
                _ChipMini(text: 'Temp: ${m.temperatura} °C'),
              if (m.humedad != null) _ChipMini(text: 'Hum: ${m.humedad} %'),
              if (m.precipitacion != null)
                _ChipMini(text: 'Prec: ${m.precipitacion} mm'),
              if (m.velocidadViento != null)
                _ChipMini(text: 'Viento: ${m.velocidadViento} m/s'),
              if (m.presionAtmosferica != null)
                _ChipMini(text: 'Pres: ${m.presionAtmosferica} hPa'),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _crearOModificarMedicion(existente: m);
            } else if (value == 'delete') {
              _eliminarMedicion(m);
            }
          },
          itemBuilder: (ctx) => const [
            PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Editar'),
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete),
                title: Text('Eliminar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip pequeño para los valores en cada tarjeta
class _ChipMini extends StatelessWidget {
  final String text;

  const _ChipMini({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11),
      ),
    );
  }
}

/// Chip para el resumen de la última medición
class _ChipResumen extends StatelessWidget {
  final String label;
  final String value;

  const _ChipResumen({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: Colors.white.withOpacity(0.06),
      side: const BorderSide(color: Colors.white24),
      padding: const EdgeInsets.symmetric(horizontal: 6),
    );
  }
}

/// Resultado que devuelve el formulario (nuevo o edición)
class _FormResultado {
  final bool esNuevo;
  final double? precipitacion;
  final double? velocidadViento;
  final double? presionAtmosferica;
  final double? temperatura;
  final double? humedad;

  _FormResultado({
    required this.esNuevo,
    this.precipitacion,
    this.velocidadViento,
    this.presionAtmosferica,
    this.temperatura,
    this.humedad,
  });

  Map<String, dynamic> toJson() {
    return {
      "precipitacion": precipitacion,
      "velocidad_viento": velocidadViento,
      "presion_atmosferica": presionAtmosferica,
      "temperatura": temperatura,
      "humedad": humedad,
    };
  }
}

/// BottomSheet con el formulario para crear / editar medición
class _FormularioMedicionSheet extends StatefulWidget {
  final Medicion? medicion;

  const _FormularioMedicionSheet({this.medicion});

  @override
  State<_FormularioMedicionSheet> createState() =>
      _FormularioMedicionSheetState();
}

class _FormularioMedicionSheetState extends State<_FormularioMedicionSheet> {
  late final TextEditingController _tempCtrl;
  late final TextEditingController _humCtrl;
  late final TextEditingController _precCtrl;
  late final TextEditingController _vientoCtrl;
  late final TextEditingController _presCtrl;

  @override
  void initState() {
    super.initState();
    _tempCtrl = TextEditingController(
        text: widget.medicion?.temperatura?.toString() ?? '');
    _humCtrl =
        TextEditingController(text: widget.medicion?.humedad?.toString() ?? '');
    _precCtrl = TextEditingController(
        text: widget.medicion?.precipitacion?.toString() ?? '');
    _vientoCtrl = TextEditingController(
        text: widget.medicion?.velocidadViento?.toString() ?? '');
    _presCtrl = TextEditingController(
        text: widget.medicion?.presionAtmosferica?.toString() ?? '');
  }

  @override
  void dispose() {
    _tempCtrl.dispose();
    _humCtrl.dispose();
    _precCtrl.dispose();
    _vientoCtrl.dispose();
    _presCtrl.dispose();
    super.dispose();
  }

  double? _parseDouble(String text) {
    if (text.trim().isEmpty) return null;
    return double.tryParse(text.replaceAll(',', '.'));
  }

  void _guardar() {
    final resultado = _FormResultado(
      esNuevo: widget.medicion == null,
      temperatura: _parseDouble(_tempCtrl.text),
      humedad: _parseDouble(_humCtrl.text),
      precipitacion: _parseDouble(_precCtrl.text),
      velocidadViento: _parseDouble(_vientoCtrl.text),
      presionAtmosferica: _parseDouble(_presCtrl.text),
    );
    Navigator.of(context).pop(resultado);
  }

  @override
  Widget build(BuildContext context) {
    final esNuevo = widget.medicion == null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Text(
              esNuevo ? 'Nueva medición' : 'Editar medición',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _buildField(_tempCtrl, 'Temperatura (°C)'),
            _buildField(_humCtrl, 'Humedad (%)'),
            _buildField(_precCtrl, 'Precipitación (mm)'),
            _buildField(_vientoCtrl, 'Velocidad del viento (m/s)'),
            _buildField(_presCtrl, 'Presión atmosférica (hPa)'),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _guardar,
                child: Text(esNuevo ? 'Crear' : 'Guardar cambios'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: ctrl,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true, signed: false),
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
