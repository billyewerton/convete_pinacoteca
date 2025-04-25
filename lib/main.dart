import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

void main() {
  runApp(PDFtoGIFApp());
}

class PDFtoGIFApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Conversor PDF para GIF - PINACOTECA',
      theme: ThemeData(
        colorScheme: ColorScheme.light(primary: Colors.teal),
        scaffoldBackgroundColor: Color(0xFFF8F9FA),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            textStyle: TextStyle(fontSize: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      home: PDFtoGIFHomePage(),
    );
  }
}

class PDFtoGIFHomePage extends StatefulWidget {
  @override
  _PDFtoGIFHomePageState createState() => _PDFtoGIFHomePageState();
}

class _PDFtoGIFHomePageState extends State<PDFtoGIFHomePage> {
  String? inputDir;
  String? outputDir;
  String status = '';
  String currentFile = '';
  double progress = 0.0;
  bool isConverting = false;
  bool cancelRequested = false;

  final List<int> maxKbOptions = [100, 300, 500, 700, 1000];
  int _selectedMaxKb = 500;

  Future<void> _selectInputDirectory() async {
    final directoryPath = await getDirectoryPath();
    if (directoryPath != null) {
      setState(() {
        inputDir = directoryPath;
        if (outputDir == null) {
          outputDir = inputDir;
        }
      });
    }
  }

  Future<void> _selectOutputDirectory() async {
    final directoryPath = await getDirectoryPath();
    if (directoryPath != null) {
      setState(() => outputDir = directoryPath);
    }
  }

  void _cancelConversion() {
    setState(() {
      cancelRequested = true;
      status = '❌ Conversão cancelada pelo usuário.';
      isConverting = false;
    });
  }

  Future<void> _convertPDFs() async {
    if (inputDir == null || outputDir == null) {
      setState(() {
        status = '⚠️ Selecione as duas pastas antes de converter.';
      });
      return;
    }

    bool producao = true;
    String popplerPath = 'windows/poppler/bin/pdftoppm.exe';
    if (producao) {
      popplerPath = 'poppler/bin/pdftoppm.exe';
    }

    final dir = Directory(inputDir!);
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.pdf'))
        .toList();

    if (files.isEmpty) {
      setState(() {
        status = '⚠️ Nenhum PDF encontrado na pasta selecionada.';
      });
      return;
    }

    setState(() {
      isConverting = true;
      progress = 0.0;
      cancelRequested = false;
      status = '🔄 Convertendo ${files.length} arquivos...';
    });

    for (int i = 0; i < files.length; i++) {
      if (cancelRequested) break;

      final file = files[i];
      final name = p.basenameWithoutExtension(file.path);
      final tempPrefix = '$outputDir\\${name}_tmp';

      setState(() {
        currentFile = name;
      });

      final result = await Process.run(
        popplerPath,
        ['-png', file.path, '-rx', '200', '-ry', '200', '-scale-to', '1700', tempPrefix],
      );

      if (result.exitCode != 0) continue;

      final imageFiles = Directory(outputDir!)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('${name}_tmp') && f.path.endsWith('.png'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      for (int page = 0; page < imageFiles.length; page++) {
        if (cancelRequested) break;

        final pngFile = imageFiles[page];
        final bytes = await pngFile.readAsBytes();
        final decoded = img.decodePng(bytes);

        if (decoded != null) {
          var image = decoded;
          var gif = img.encodeGif(image);
          final gifName = imageFiles.length == 1
              ? '$outputDir\\$name.gif'
              : '$outputDir\\${name}_pagina${page + 1}.gif';
          final gifFile = File(gifName);
          await gifFile.writeAsBytes(gif);

          int resizeAttempts = 0;
          double scaleFactor = 0.90;
          int colorCount = 128;
          final maxSize = _selectedMaxKb * 1024;

          while ((await gifFile.length()) > maxSize && resizeAttempts < 10) {
            final newWidth = (image.width * scaleFactor).round();
            final newHeight = (image.height * scaleFactor).round();

            image = img.copyResize(image,
              width: newWidth,
              height: newHeight,
              interpolation: img.Interpolation.cubic,
            );

            final reduced = img.quantize(image, numberOfColors: colorCount);
            gif = img.encodeGif(reduced);
            await gifFile.writeAsBytes(gif);

            scaleFactor -= 0.03;
            colorCount = (colorCount * 0.9).floor().clamp(32, 128);
            resizeAttempts++;
          }
        }

        await pngFile.delete();
      }

      setState(() {
        progress = (i + 1) / files.length;
      });
    }

    setState(() {
      isConverting = false;
      if (!cancelRequested) {
        status = '✅ Conversão finalizada!';
        progress = 1.0;
      }
      currentFile = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
            color: Colors.teal,
            child: Column(
              children: [
                Icon(Icons.picture_as_pdf_outlined, size: 40, color: Colors.white),
                SizedBox(height: 12),
                Text(
                  'Conversor PDF ➜ GIF | PINACOTECA',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Tamanho máximo do GIF: ", style: TextStyle(fontSize: 16, color: Colors.white)),
                    SizedBox(width: 12),
                    DropdownButton<int>(
                      value: _selectedMaxKb,
                      dropdownColor: Colors.white,
                      iconEnabledColor: Colors.white,
                      underline: Container(height: 1, color: Colors.white),
                      style: TextStyle(color: Colors.black),
                      items: maxKbOptions.map((kb) {
                        return DropdownMenuItem<int>(
                          value: kb,
                          child: Text('${kb} KB'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedMaxKb = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Se o PDF tiver mais de uma página, será gerado um arquivo separado para cada página.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: TextEditingController(text: inputDir ?? ''),
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Pasta dos PDFs',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _selectInputDirectory,
                        icon: Icon(Icons.folder_open),
                        label: Text('Selecionar'),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: TextEditingController(text: outputDir ?? ''),
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Pasta para salvar os GIFs',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _selectOutputDirectory,
                        icon: Icon(Icons.save_alt),
                        label: Text('Selecionar'),
                      ),
                    ],
                  ),
                  SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: isConverting ? null : _convertPDFs,
                    icon: Icon(Icons.play_arrow),
                    label: Text(isConverting ? 'Convertendo...' : 'Converter PDFs'),
                  ),
                  SizedBox(height: 12),
                  if (isConverting)
                   ElevatedButton.icon(
  onPressed: _cancelConversion,
  icon: Icon(
    Icons.cancel,
    color: Colors.white,
  ),
  label: Text(
    'Cancelar Conversão',
    style: TextStyle(color: Colors.white),
  ),
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.redAccent,
  ),
),
                  SizedBox(height: 30),
                  if (isConverting || progress > 0)
                    Column(
                      children: [
                        LinearProgressIndicator(value: progress, color: Colors.teal),
                        SizedBox(height: 8),
                        if (currentFile.isNotEmpty)
                          Text('Convertendo: $currentFile', style: TextStyle(fontSize: 16)),
                        SizedBox(height: 4),
                        Text('Progresso: ${(progress * 100).toStringAsFixed(0)}%'),
                      ],
                    ),
                  if (status.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        status,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.teal),
                      ),
                    ),
                ],
              ),
            ),
          ),

// FOOTER
          Container(
            width: double.infinity,
            color: Colors.green.shade800,
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
          


             
                Image.asset('assets/logo.png', height: 32),
                SizedBox(width: 12),

             
                Flexible(
                  child: Text(
                    'Secretaria Municipal de Saúde de Fortaleza | Coordenadoria de Vigilância em Saúde | '
                    'Célula de Vigilância Epidemiológica | Equipe CIEVS | Versão 25.04.03',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),

                  
                ),
                
              ],
            ),
          ),


        ],
      ),
    );
  }
}
