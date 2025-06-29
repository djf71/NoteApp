import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:math';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Handwriting Collector',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomePage(), // 👈 Start on the home screen
    );
  }
}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          child: Text('Start'),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => HandwritingApp()),
            );
          },
        ),
      ),
    );
  }
}

class HandwritingApp extends StatefulWidget {
  @override
  _HandwritingAppState createState() => _HandwritingAppState();
}

class _HandwritingAppState extends State<HandwritingApp> {
  final GlobalKey _canvasKey = GlobalKey();
  List<Offset?> _points = [];
  List<String> sentences = [];
  int lastSentenceIndex = -1;
  String sentence = "The quick brown fox jumps over the lazy dog.";
  int _penWeight = 1; // default to 1 (cleanest)

  @override
void initState() {
  super.initState();
  _loadSentences();
}

Future<void> _syncUploads() async {
  final dir = await getApplicationDocumentsDirectory();
  final files = dir.listSync();

  final pngFiles = files.where((f) => f.path.endsWith('.png')).toList();

  for (final imgFile in pngFiles) {
    final baseName = imgFile.path.split(Platform.pathSeparator).last.replaceAll('.png', '');
    final txtFile = File('${dir.path}/$baseName.txt');

    if (!txtFile.existsSync()) {
      print('⚠️ Missing text file for $baseName, skipping');
      continue;
    }

    final sentence = await txtFile.readAsString();
    final imgBytes = await File(imgFile.path).readAsBytes();

    bool uploaded = await _uploadToServer(imgBytes, sentence);

    if (uploaded) {
      await File(imgFile.path).delete();
      await txtFile.delete();
      print('Uploaded and deleted $baseName');
    } else {
      print('Failed to upload $baseName');
    }
  }
}

Future<bool> _uploadToServer(Uint8List imageBytes, String sentence) async {
  try {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('http://10.0.2.2:3000/upload'), 
    );

    request.files.add(http.MultipartFile.fromBytes(
      'image',
      imageBytes,
      filename: 'upload.png',
    ));

    request.fields['text'] = sentence;

    var response = await request.send();

    if (response.statusCode == 200) {
      return true;
    } else {
      print('Upload failed with status ${response.statusCode}');
      return false;
    }
  } catch (e) {
    print('Upload error: $e');
    return false;
  }
}

Future<void> _saveLocally(Uint8List pngBytes, String sentence) async {
  final dir = await getApplicationDocumentsDirectory();
  final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
  final imgFile = File('${dir.path}/$timestamp.png');
  final txtFile = File('${dir.path}/$timestamp.txt');

  await imgFile.writeAsBytes(pngBytes);
  await txtFile.writeAsString(sentence);

  print('Saved locally: $timestamp.png + $timestamp.txt');
}

Future<void> _loadSentences() async {
  final raw = await rootBundle.loadString('assets/sentences.txt');
  sentences = raw.split('\n').where((line) => line.trim().isNotEmpty).toList();
  _setRandomSentence();
}

void _setRandomSentence() {
  if (sentences.isEmpty) return;

  final random = Random();
  int index;
  do {
    index = random.nextInt(sentences.length);
  } while (index == lastSentenceIndex && sentences.length > 1);

  setState(() {
    lastSentenceIndex = index;
    sentence = sentences[index];
  });
}

  void _clearCanvas() {
    setState(() {
      _points = [];
    });
  }

  Future<void> _submitDrawing() async {
    RenderRepaintBoundary boundary =
        _canvasKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    Uint8List pngBytes = byteData!.buffer.asUint8List();

    await _saveLocally(pngBytes, sentence);

    print("Submitted"); 

    _clearCanvas();
    _setRandomSentence();
    
    /*
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('http://10.0.2.2:3000/upload'),
    );
    request.fields['text'] = sentence;
    request.files.add(http.MultipartFile.fromBytes(
      'image',
      pngBytes,
      filename: 'handwriting.png',
    ));

    var response = await request.send();
    if (response.statusCode == 200) {
      print('Uploaded!');
      _clearCanvas();
      // Generate new sentence if needed
    } else {
      print('Upload failed');
    }
    */
    
  }
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Handwriting Collector")),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Text(
              sentence,
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            Expanded(
              child: RepaintBoundary(
                key: _canvasKey,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      RenderBox renderBox =
                          _canvasKey.currentContext!.findRenderObject() as RenderBox;
                      Offset localPosition =
                          renderBox.globalToLocal(details.globalPosition);
                      _points.add(localPosition);
                    });
                  },
                  onPanEnd: (details) {
                    _points.add(null);
                  },
                  child: CustomPaint(
                    painter: DrawingPainter(points: _points,penWeight: _penWeight),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(onPressed: _clearCanvas, child: Text("Clear")),
                ElevatedButton(onPressed: _submitDrawing, child: Text("Submit")),
                ElevatedButton(onPressed: () async {
                  await _syncUploads();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Sync complete!')),
                  );
                },
  child: Text('Sync'),
),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                int value = index + 1;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _penWeight = value;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _penWeight == value ? Colors.blue : Colors.grey,
                    ),
                    child: Text('$value'),
                  ),
                );
              }),
            )
          ],
        ),
      ),
    );
  }
}

class DrawingPainter extends CustomPainter {
  final List<Offset?> points;
  final int penWeight; 

  DrawingPainter({required this.points,required this.penWeight});

  double _getStrokeWidth(int weight) {
  switch (weight) {
    case 1:
      return 2.0;
    case 2:
      return 4.0;
    case 3:
      return 6.0;
    case 4:
      return 8.0;
    case 5:
    default:
      return 10.0;
  }
}

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = _getStrokeWidth(penWeight) // dynamic width
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) => true;
}