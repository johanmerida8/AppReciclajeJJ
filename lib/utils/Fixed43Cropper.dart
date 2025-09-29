import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class Fixed43Cropper extends StatefulWidget {
  final XFile file;
  const Fixed43Cropper({super.key, required this.file});

  @override
  State<Fixed43Cropper> createState() => _Fixed43CropperState();
}

class _Fixed43CropperState extends State<Fixed43Cropper> {
  // late img.Image _decoded;

  // Crop rect in ORIGINAL IMAGE coordinates
  late double _left;
  late double _top;
  late double _cw;
  late double _ch;

  // Ratio: 4/3 or 3/4
  double _ratio = 4 / 3;

  // Render metrics
  double _scale = 1; // screen px per original px
  double _imgDx = 0; // image left (screen coords) when fit-contain
  double _imgDy = 0; // image top  (screen coords) when fit-contain

  bool _ready = false;
  bool _saving = false;

  // original image size (no full decode on UI)
  late int _iw;
  late int _ih;

  // Drag state
  String? _drag; // 'in','tl','tr','bl','br'
  Offset? _lastGlobal;

  // Min crop size in image px
  static const double _minSize = 64.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bytes = await File(widget.file.path).readAsBytes();
    final uiImg = await _decodeUi(bytes);
    _iw = uiImg.width;
    _ih = uiImg.height;

    // Start with a smaller 4:3 box centered, entirely inside the image.
    final iw = _iw.toDouble();
    final ih = _ih.toDouble();
    final maxAllowedW = math.min(iw, ih * _ratio);
    _cw = maxAllowedW * 0.7;
    _ch = _cw / _ratio;

    // Center
    _left = (iw - _cw) / 2;
    _top = (ih - _ch) / 2;

    if (mounted) setState(() => _ready = true);
  }

  //Fast size decode helper (UI isolate-friendly)
  Future<ui.Image> _decodeUi(Uint8List bytes) {
    final c = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, (ui.Image img) => c.complete(img));
    return c.future;
  }

  void _toggleRatio() {
    final centerX = _left + _cw / 2;
    final centerY = _top + _ch / 2;

    _ratio = (_ratio == 4 / 3) ? 3 / 4 : 4 / 3;

    // Adjust size to fit new ratio but keep center and stay inside
    final iw = _iw.toDouble();
    final ih = _ih.toDouble();

    double newW = _cw;
    double newH = newW / _ratio;
    if (newH > ih) {
      newH = ih * 0.9;
      newW = newH * _ratio;
    }
    if (newW > iw) {
      newW = iw * 0.9;
      newH = newW / _ratio;
    }

    _cw = newW.clamp(_minSize, iw);
    _ch = newH.clamp(_minSize, ih);

    _left = (centerX - _cw / 2).clamp(0.0, iw - _cw);
    _top = (centerY - _ch / 2).clamp(0.0, ih - _ch);

    setState(() {});
  }

  // Convert screen point to image coordinates (clamped)
  Offset _screenToImage(Offset p) {
    final ix = ((p.dx - _imgDx) / _scale).clamp(0.0, _iw.toDouble());
    final iy = ((p.dy - _imgDy) / _scale).clamp(0.0, _ih.toDouble());
    return Offset(ix, iy);
  }

  bool _pointInCrop(Offset imgPt) {
    return imgPt.dx >= _left &&
        imgPt.dx <= _left + _cw &&
        imgPt.dy >= _top &&
        imgPt.dy <= _top + _ch;
  }

  String? _hitHandle(Offset imgPt) {
    const h = 24.0; // handle hit size in image px (scaled later)
    final tl = Rect.fromCenter(center: Offset(_left, _top), width: h, height: h);
    final tr = Rect.fromCenter(center: Offset(_left + _cw, _top), width: h, height: h);
    final bl = Rect.fromCenter(center: Offset(_left, _top + _ch), width: h, height: h);
    final br = Rect.fromCenter(center: Offset(_left + _cw, _top + _ch), width: h, height: h);
    if (tl.contains(imgPt)) return 'tl';
    if (tr.contains(imgPt)) return 'tr';
    if (bl.contains(imgPt)) return 'bl';
    if (br.contains(imgPt)) return 'br';
    return null;
  }

  void _onPanStart(DragStartDetails d) {
    _lastGlobal = d.globalPosition;
    final imgPt = _screenToImage(d.globalPosition);
    _drag = _hitHandle(imgPt) ?? (_pointInCrop(imgPt) ? 'in' : null);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_drag == null || _lastGlobal == null) return;
    final prev = _screenToImage(_lastGlobal!);
    final cur = _screenToImage(d.globalPosition);
    final dx = cur.dx - prev.dx;
    final dy = cur.dy - prev.dy;

    final iw = _iw.toDouble();
    final ih = _ih.toDouble();

    if (_drag == 'in') {
      _left = (_left + dx).clamp(0.0, iw - _cw);
      _top = (_top + dy).clamp(0.0, ih - _ch);
    } else {
      double newLeft = _left, newTop = _top, newW = _cw, newH = _ch;
      switch (_drag) {
        case 'tl':
          newLeft += dx;
          newW = (_left + _cw) - newLeft;
          newW = newW.clamp(_minSize, iw);
          newH = newW / _ratio;
          newTop = (_top + _ch) - newH;
          break;
        case 'tr':
          newW = (_cw + dx).clamp(_minSize, iw);
          newH = newW / _ratio;
          newTop = (_top + _ch) - newH;
          break;
        case 'bl':
          newLeft += dx;
          newW = (_left + _cw) - newLeft;
          newW = newW.clamp(_minSize, iw);
          newH = newW / _ratio;
          break;
        case 'br':
          newW = (_cw + dx).clamp(_minSize, iw);
          newH = newW / _ratio;
          break;
      }
      newLeft = newLeft.clamp(0.0, iw - newW);
      newTop = newTop.clamp(0.0, ih - newH);
      if (newTop + newH > ih) newTop = ih - newH;
      if (newLeft + newW > iw) newLeft = iw - newW;

      _left = newLeft;
      _top = newTop;
      _cw = newW.clamp(_minSize, iw);
      _ch = newH.clamp(_minSize, ih);
    }

    _lastGlobal = d.globalPosition;
    setState(() {});
  }

  void _onPanEnd(DragEndDetails d) {
    _drag = null;
    _lastGlobal = null;
  }

  Future<void> _onConfirm() async {
    if (!_ready || _saving) return;
    setState(() => _saving = true);

    try {
      // Get temp path on UI isolate (plugins allowed here)
      final tmp = await getTemporaryDirectory();
      final outPath = '${tmp.path}/crop_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Do heavy work in background isolate, writing to the given outPath
      final path = await compute<_CropArgs, String>(
        _cropAndSave,
        _CropArgs(
          path: widget.file.path,
          outPath: outPath,               // <-- pass target path
          x: _left.round(),
          y: _top.round(),
          w: _cw.round(),
          h: _ch.round(),
          quality: 85,
        ),
      );

      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop(XFile(path));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al recortar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Recortar imagen',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          // TextButton(
          //   onPressed: _ready
          //       ? () {
          //           WidgetsBinding.instance.addPostFrameCallback((_) {
          //             if (mounted) Navigator.of(context).maybePop(widget.file);
          //           });
          //         }
          //       : null,
          //   child: const Text('Original', style: TextStyle(color: Colors.white)),
          // ),
          IconButton(
            tooltip: '4:3 ↔ 3:4',
            icon: const Icon(
              Icons.rotate_90_degrees_ccw,
              color: Colors.white,
            ),
            onPressed: _ready ? _toggleRatio : null,
          ),
          // TextButton(
          //   onPressed: _ready ? _onConfirm : null,
          //   child: const Text('Usar', style: TextStyle(color: Colors.white)),
          // ),
          IconButton(
            onPressed: _ready ? _onConfirm : null, 
            icon: const Icon(Icons.check, color: Colors.white),
          )
        ],
      ),
      body: _ready
          ? LayoutBuilder(builder: (context, c) {
              final boxW = c.maxWidth;
              final boxH = c.maxHeight;

              // Fit-contain using only original size (no heavy decode)
              final sW = boxW / _iw;
              final sH = boxH / _ih;
              _scale = math.min(sW, sH);
              final renderW = _iw * _scale;
              final renderH = _ih * _scale;
              _imgDx = (boxW - renderW) / 2;
              _imgDy = (boxH - renderH) / 2;

              final rLeft = _imgDx + _left * _scale;
              final rTop = _imgDy + _top * _scale;
              final rW = _cw * _scale;
              final rH = _ch * _scale;

              const handle = 14.0;

              return Stack(
                children: [
                  // Gesture + content
                  GestureDetector(
                    onPanStart: _onPanStart,
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: _onPanEnd,
                    child: Stack(
                      children: [
                        Positioned(
                          left: _imgDx,
                          top: _imgDy,
                          width: renderW,
                          height: renderH,
                          child: Image.file(File(widget.file.path), fit: BoxFit.fill),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _DimOutsidePainter(Rect.fromLTWH(rLeft, rTop, rW, rH)),
                            ),
                          ),
                        ),
                        Positioned(
                          left: rLeft,
                          top: rTop,
                          width: rW,
                          height: rH,
                          child: IgnorePointer(
                            child: Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                                Positioned(left: -handle, top: -handle, width: handle*2, height: handle*2, child: _Handle()),
                                Positioned(right: -handle, top: -handle, width: handle*2, height: handle*2, child: _Handle()),
                                Positioned(left: -handle, bottom: -handle, width: handle*2, height: handle*2, child: _Handle()),
                                Positioned(right: -handle, bottom: -handle, width: handle*2, height: handle*2, child: _Handle()),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Saving overlay
                  if (_saving) ...[
                    const ModalBarrier(dismissible: false, color: Colors.black38),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ],
              );
            })
          : const Center(child: CircularProgressIndicator()),
    );
  }
}

// Top-level args + worker (runs off the UI isolate)
class _CropArgs {
  final String path;
  final String outPath;
  final int x, y, w, h;
  final int quality;
  _CropArgs({
    required this.path,
    required this.outPath,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.quality,
  });
}

Future<String> _cropAndSave(_CropArgs a) async {
  // No plugins here
  final srcFile = File(a.path);
  final bytes = await srcFile.readAsBytes();

  final decoded = img.decodeImage(bytes)!;
  final oriented = img.bakeOrientation(decoded);

  final x = a.x.clamp(0, oriented.width - 1);
  final y = a.y.clamp(0, oriented.height - 1);
  final w = a.w.clamp(1, oriented.width - x);
  final h = a.h.clamp(1, oriented.height - y);

  final cropped = img.copyCrop(oriented, x: x, y: y, width: w, height: h);
  final outBytes = img.encodeJpg(cropped, quality: a.quality);

  // Write to the precomputed path from UI isolate
  await File(a.outPath).writeAsBytes(outBytes, flush: true);
  return a.outPath;
}

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(3)),
    );
  }
}

class _DimOutsidePainter extends CustomPainter {
  final Rect cropRect;
  _DimOutsidePainter(this.cropRect);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.55);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(cropRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DimOutsidePainter oldDelegate) =>
      oldDelegate.cropRect != cropRect;
}