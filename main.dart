import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const CosmosWatchApp());

const bg = Color(0xFF090B0E);
const panel = Color(0x667E8790);
const silver = Color(0xFFD5D9DD);
const muted = Color(0xFF929AA2);

class CosmosWatchApp extends StatelessWidget {
  const CosmosWatchApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'COSMOS WATCH',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(primary: silver, surface: bg),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;
  final pages = const [HomePage(), RadarPage(), ObjectsPage(), EventsPage(), SettingsPage()];
  final labels = const ['Главная', 'Радар', 'Объекты', 'События', 'Настройки'];
  final icons = const [Icons.public, Icons.radar, Icons.language, Icons.event, Icons.tune];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: Row(children: [
              const Icon(Icons.blur_circular, color: silver, size: 25),
              const SizedBox(width: 10),
              const Text('COSMOS WATCH', style: TextStyle(letterSpacing: 2.2, fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF9DB9A5), shape: BoxShape.circle)),
              const SizedBox(width: 7),
              const Text('LIVE DATA', style: TextStyle(color: muted, fontSize: 9, letterSpacing: 1.2)),
            ]),
          ),
          Expanded(child: IndexedStack(index: index, children: pages)),
        ]),
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0x99565E66),
          border: Border.all(color: const Color(0x55FFFFFF)),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(5, (i) => GestureDetector(
            onTap: () => setState(() => index = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: index == i ? const Color(0x557F8992) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(icons[i], size: 19, color: index == i ? Colors.white : const Color(0xFFADB4BA)),
                const SizedBox(height: 3),
                Text(labels[i], style: TextStyle(fontSize: 9, color: index == i ? Colors.white : const Color(0xFFADB4BA))),
              ]),
            ),
          )),
        ),
      ),
    );
  }
}

class Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const Glass({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: panel,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0x44FFFFFF)),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 8))],
    ),
    child: child,
  );
}

Widget heading(String title, String subtitle) => Padding(
  padding: const EdgeInsets.only(bottom: 14),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w300, letterSpacing: .3)),
    const SizedBox(height: 4),
    Text(subtitle, style: const TextStyle(color: muted, fontSize: 11, letterSpacing: 1.1)),
  ]),
);

class IssPosition {
  final double latitude, longitude, altitude, velocity;
  final int timestamp;
  IssPosition(this.latitude, this.longitude, this.altitude, this.velocity, this.timestamp);
  factory IssPosition.fromJson(Map<String, dynamic> j) => IssPosition(
    (j['latitude'] as num).toDouble(),
    (j['longitude'] as num).toDouble(),
    (j['altitude'] as num).toDouble(),
    (j['velocity'] as num).toDouble(),
    (j['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
  );
}

class SpaceApi {
  static const _base = 'https://api.wheretheiss.at/v1/satellites/25544';

  static Future<IssPosition> iss() async {
    final r = await http.get(Uri.parse(_base)).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    return IssPosition.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  // The provider calculates actual past/future orbital positions from its orbit model.
  // The endpoint accepts at most 10 timestamps in one request.
  static Future<List<IssPosition>> issTrack({int samples = 10, int stepSeconds = 600}) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final timestamps = List.generate(samples, (i) => now + i * stepSeconds).join(',');
    final uri = Uri.parse('$_base/positions').replace(queryParameters: {'timestamps': timestamps});
    final r = await http.get(uri).timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    final decoded = jsonDecode(r.body) as List<dynamic>;
    return decoded.map((e) => IssPosition.fromJson(e as Map<String, dynamic>)).toList();
  }
}

class IssCard extends StatefulWidget {
  const IssCard({super.key});
  @override
  State<IssCard> createState() => _IssCardState();
}
class _IssCardState extends State<IssCard> {
  IssPosition? data;
  String? error;
  Timer? timer;
  @override
  void initState() { super.initState(); refresh(); timer = Timer.periodic(const Duration(seconds: 15), (_) => refresh()); }
  Future<void> refresh() async {
    try { final value = await SpaceApi.iss(); if (mounted) setState(() { data = value; error = null; }); }
    catch (_) { if (mounted) setState(() => error = 'Нет соединения с источником данных'); }
  }
  @override
  void dispose() { timer?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: const [Icon(Icons.satellite_alt, color: silver), SizedBox(width: 8), Text('МЕЖДУНАРОДНАЯ КОСМИЧЕСКАЯ СТАНЦИЯ', style: TextStyle(fontSize: 10, letterSpacing: .8)), Spacer(), Icon(Icons.circle, color: Color(0xFF9DB9A5), size: 7)]),
    const SizedBox(height: 16),
    if (data != null) ...[
      Row(children: [
        Expanded(child: metric('ШИРОТА', '${data!.latitude.toStringAsFixed(2)}°')),
        Expanded(child: metric('ДОЛГОТА', '${data!.longitude.toStringAsFixed(2)}°')),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: metric('ВЫСОТА', '${data!.altitude.toStringAsFixed(1)} км')),
        Expanded(child: metric('СКОРОСТЬ', '${(data!.velocity / 3600).toStringAsFixed(2)} км/с')),
      ]),
    ] else Text(error ?? 'Получение текущих координат…', style: const TextStyle(color: muted)),
    const SizedBox(height: 8),
    Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: refresh, icon: const Icon(Icons.refresh, size: 15), label: const Text('Обновить'))),
  ]));
}
Widget metric(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
  Text(label, style: const TextStyle(color: muted, fontSize: 9, letterSpacing: 1)),
  const SizedBox(height: 5),
  Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w300)),
]);

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
    heading('Космос рядом', 'ОБЗОР НАБЛЮДЕНИЙ И МИССИЙ'),
    Container(height: 180, decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF333B43), Color(0xFF111820), Color(0xFF090B0E)]),
      border: Border.all(color: const Color(0x44FFFFFF))),
      child: Stack(children: [
        Positioned(right: 28, top: 24, child: Container(width: 112, height: 112, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Color(0xFFB7BEC4), Color(0xFF535E68), Color(0xFF1A222B)])))),
        const Positioned(left: 18, bottom: 18, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('EARTH ORBIT', style: TextStyle(color: silver, fontSize: 9, letterSpacing: 2)),
          SizedBox(height: 6), Text('Наблюдай реальную\nорбиту Земли', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w300)),
        ])),
      ]),
    ),
    const SizedBox(height: 16),
    const IssCard(),
    const SizedBox(height: 16),
    const Glass(child: Row(children: [Icon(Icons.auto_awesome, color: silver), SizedBox(width: 12), Expanded(child: Text('Следующий шаг — добавить каталог объектов и расчёт видимых пролётов.', style: TextStyle(color: silver, fontSize: 12)))])),
  ]);
}

class RadarPage extends StatefulWidget {
  const RadarPage({super.key});
  @override
  State<RadarPage> createState() => _RadarPageState();
}

class _RadarPageState extends State<RadarPage> {
  IssPosition? current;
  List<IssPosition> track = [];
  String? error;
  bool loading = false;
  DateTime? updatedAt;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    refresh();
    timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
  }

  Future<void> refresh() async {
    if (loading) return;
    loading = true;
    if (mounted) setState(() => error = null);
    try {
      final live = await SpaceApi.iss();
      // Respect the public API's approximate one-request-per-second rate limit.
      await Future.delayed(const Duration(milliseconds: 1100));
      final futureTrack = await SpaceApi.issTrack();
      if (!mounted) return;
      setState(() {
        current = live;
        track = futureTrack;
        updatedAt = DateTime.now();
        error = null;
      });
    } catch (_) {
      if (mounted) setState(() => error = 'Не удалось обновить орбитальные данные. Проверь подключение.');
    } finally {
      loading = false;
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
    children: [
      heading('Орбитальный радар', 'РЕАЛЬНОЕ ПОЛОЖЕНИЕ И ПРОГНОЗ ТРАЕКТОРИИ'),
      Glass(padding: const EdgeInsets.all(14), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.radar, color: silver, size: 19),
            const SizedBox(width: 8),
            const Expanded(child: Text('ISS · NORAD 25544', style: TextStyle(fontSize: 11, letterSpacing: 1))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(color: const Color(0x337E8790), borderRadius: BorderRadius.circular(20)),
              child: Row(children: [
                Icon(Icons.circle, size: 6, color: current == null ? muted : const Color(0xFFD5D9DD)),
                const SizedBox(width: 5),
                Text(current == null ? 'ОЖИДАНИЕ' : 'LIVE', style: const TextStyle(fontSize: 9, letterSpacing: 1, color: silver, fontWeight: FontWeight.w500)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          AspectRatio(
            aspectRatio: 1.18,
            child: CustomPaint(
              painter: GroundTrackPainter(current: current, points: track),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 8),
          const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('−180°', style: TextStyle(color: muted, fontSize: 9)),
            Text('КАРТА КООРДИНАТ · ШИРОТА / ДОЛГОТА', style: TextStyle(color: muted, fontSize: 8, letterSpacing: .7)),
            Text('+180°', style: TextStyle(color: muted, fontSize: 9)),
          ]),
          const SizedBox(height: 12),
          if (current != null) ...[
            Row(children: [
              Expanded(child: metric('ШИРОТА', '${current!.latitude.toStringAsFixed(2)}°')),
              Expanded(child: metric('ДОЛГОТА', '${current!.longitude.toStringAsFixed(2)}°')),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: metric('ВЫСОТА', '${current!.altitude.toStringAsFixed(1)} км')),
              Expanded(child: metric('СКОРОСТЬ', '${(current!.velocity / 3600).toStringAsFixed(2)} км/с')),
            ]),
            const SizedBox(height: 12),
            Text('Под точкой показано текущее положение МКС. Линия — рассчитанные API будущие позиции примерно на 90 минут вперёд.', style: const TextStyle(color: muted, fontSize: 10, height: 1.4)),
          ] else
            Text(error ?? 'Загружаем положение станции и расчёт траектории…', style: const TextStyle(color: muted, fontSize: 11)),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: const TextStyle(color: Color(0xFFFFA5A5), fontSize: 10)),
          ],
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text(updatedAt == null ? 'Данные ещё не получены' : 'Обновлено: ${TimeOfDay.fromDateTime(updatedAt!).format(context)}', style: const TextStyle(color: muted, fontSize: 9))),
            TextButton.icon(onPressed: loading ? null : refresh, icon: const Icon(Icons.refresh, size: 15), label: Text(loading ? 'Загрузка…' : 'Обновить')),
          ]),
        ],
      )),
      const SizedBox(height: 12),
      const Glass(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline, color: silver, size: 18),
        SizedBox(width: 10),
        Expanded(child: Text('Это координатная карта наземной проекции, а не радиолокационное изображение и не спутниковый снимок. Положение и прогнозные точки берутся из открытого API; точность прогноза зависит от актуальности орбитальной модели источника.', style: TextStyle(color: muted, fontSize: 10, height: 1.45))),
      ])),
    ],
  );
}

class GroundTrackPainter extends CustomPainter {
  final IssPosition? current;
  final List<IssPosition> points;
  GroundTrackPainter({required this.current, required this.points});

  Offset project(double latitude, double longitude, Rect rect) {
    final x = rect.left + (longitude + 180) / 360 * rect.width;
    final y = rect.top + (90 - latitude) / 180 * rect.height;
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    final bgPaint = Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Color(0xFF252B31), Color(0xFF090B0E)],
    ).createShader(rect);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)), bgPaint);

    final grid = Paint()
      ..color = const Color(0x337E8790)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    for (int lon = -180; lon <= 180; lon += 30) {
      final x = rect.left + (lon + 180) / 360 * rect.width;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), grid);
    }
    for (int lat = -60; lat <= 60; lat += 30) {
      final y = rect.top + (90 - lat) / 180 * rect.height;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), grid);
    }
    final equator = Paint()..color = const Color(0x557E8790)..strokeWidth = 1;
    final eqY = rect.top + .5 * rect.height;
    canvas.drawLine(Offset(rect.left, eqY), Offset(rect.right, eqY), equator);

    // Subtle latitude/longitude labels.
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final lat in [60, 30, 0, -30, -60]) {
      final y = rect.top + (90 - lat) / 180 * rect.height;
      tp.text = TextSpan(text: '${lat.abs()}°${lat > 0 ? 'N' : lat < 0 ? 'S' : ''}', style: const TextStyle(color: Color(0xFF929AA2), fontSize: 8));
      tp.layout();
      tp.paint(canvas, Offset(rect.left + 4, y - 10));
    }

    if (points.length > 1) {
      final pathPaint = Paint()
        ..color = const Color(0xFFD5D9DD)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      for (int i = 1; i < points.length; i++) {
        final a = points[i - 1], b = points[i];
        // Do not draw a misleading line across the whole map at the date line.
        if ((a.longitude - b.longitude).abs() > 180) continue;
        canvas.drawLine(project(a.latitude, a.longitude, rect), project(b.latitude, b.longitude, rect), pathPaint);
      }
      final futurePaint = Paint()..color = const Color(0xFFD5D9DD);
      for (final p in points.skip(1)) {
        final o = project(p.latitude, p.longitude, rect);
        canvas.drawCircle(o, 1.8, futurePaint);
      }
    }

    if (current != null) {
      final pos = project(current!.latitude, current!.longitude, rect);
      final halo = Paint()..color = const Color(0x557E8790);
      final dot = Paint()..color = const Color(0xFFF0F2F4);
      canvas.drawCircle(pos, 9, halo);
      canvas.drawCircle(pos, 4.5, dot);
      final label = TextPainter(
        text: const TextSpan(text: 'ISS NOW', style: TextStyle(color: Color(0xFFF0F2F4), fontSize: 8, fontWeight: FontWeight.w600, letterSpacing: .8)),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = (pos.dx + 9 + label.width < rect.right) ? pos.dx + 9 : pos.dx - label.width - 9;
      final dy = (pos.dy - 18).clamp(rect.top, rect.bottom - 12).toDouble();
      label.paint(canvas, Offset(dx, dy));
    }

    final border = Paint()..color = const Color(0x557E8790)..style = PaintingStyle.stroke..strokeWidth = 1;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)), border);
  }

  @override
  bool shouldRepaint(covariant GroundTrackPainter oldDelegate) =>
      oldDelegate.current?.latitude != current?.latitude ||
      oldDelegate.current?.longitude != current?.longitude ||
      oldDelegate.points.length != points.length ||
      (points.isNotEmpty && oldDelegate.points.isNotEmpty &&
        oldDelegate.points.last.timestamp != points.last.timestamp);
}

class ObjectsPage extends StatelessWidget {
  const ObjectsPage({super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
    heading('Объекты', 'КАТАЛОГ НЕБЕСНЫХ ТЕЛ'),
    objectTile(Icons.public, 'Планеты', 'Солнечная система'),
    objectTile(Icons.blur_on, 'Астероиды и кометы', 'Малые тела Солнечной системы'),
    objectTile(Icons.satellite_alt, 'Спутники', 'Орбитальные аппараты и станции'),
    const SizedBox(height: 14),
    Glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('LIVE SPACE', style: TextStyle(letterSpacing: 1.5, fontSize: 11)),
      const SizedBox(height: 8),
      const Text('Официальный видеопоток с МКС', style: TextStyle(color: muted, fontSize: 12)),
      const SizedBox(height: 12),
      FilledButton.tonalIcon(onPressed: () => launchUrl(Uri.parse('https://www.youtube.com/@NASA/live'), mode: LaunchMode.externalApplication),
        icon: const Icon(Icons.play_arrow), label: const Text('Открыть трансляцию NASA')),
    ])),
    const SizedBox(height: 14),
    const Glass(child: Text('Камеры других спутников доступны только если оператор публикует открытый видеопоток. Большинство спутников таких трансляций не передаёт.', style: TextStyle(color: muted, fontSize: 11))),
  ]);
}
Widget objectTile(IconData icon, String title, String sub) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Glass(child: Row(children: [
  Icon(icon, color: silver, size: 24), const SizedBox(width: 14),
  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontSize: 15)), const SizedBox(height: 3),
    Text(sub, style: const TextStyle(color: muted, fontSize: 10)),
  ])),
  const Icon(Icons.chevron_right, color: muted),
])));

class EventsPage extends StatelessWidget {
  const EventsPage({super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
    heading('События', 'АСТРОНОМИЧЕСКИЙ КАЛЕНДАРЬ'),
    const Glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Календарь наблюдений', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w300)),
      SizedBox(height: 8),
      Text('Затмения · метеорные потоки · сближения · пролёты МКС', style: TextStyle(color: muted, fontSize: 11)),
      SizedBox(height: 14),
      Text('Подключение проверенного календаря событий — следующий этап интеграции.', style: TextStyle(color: silver, fontSize: 11)),
    ])),
  ]);
}
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
    heading('Настройки', 'ПЕРСОНАЛИЗАЦИЯ ПРИЛОЖЕНИЯ'),
    const Glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Язык интерфейса', style: TextStyle(fontSize: 15)),
      SizedBox(height: 5),
      Text('Русский · дополнительные языки будут загружаться по выбору', style: TextStyle(color: muted, fontSize: 11)),
    ])),
    const SizedBox(height: 12),
    const Glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Внешний вид', style: TextStyle(fontSize: 15)),
      SizedBox(height: 5),
      Text('Серебристое прозрачное стекло · единый стиль всех вкладок', style: TextStyle(color: muted, fontSize: 11)),
    ])),
    const SizedBox(height: 12),
    const Glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Данные и приватность', style: TextStyle(fontSize: 15)),
      SizedBox(height: 5),
      Text('Координаты МКС загружаются из открытого источника. Геолокация устройства пока не запрашивается.', style: TextStyle(color: muted, fontSize: 11)),
    ])),
  ]);
}
