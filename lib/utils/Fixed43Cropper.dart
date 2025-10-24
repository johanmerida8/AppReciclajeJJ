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
  String? _drag; // 'pan','tl','tr','bl','br'
  Offset? _lastGlobal;

  // Pinch zoom state
  double? _initialScale;
  double? _initialCropWidth;
  double? _initialCropHeight;

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

    // 🎯 SET INITIAL RATIO (VERTICAL ORIENTATION ONLY)
    // Default to 4:3 horizontal crop box
    _ratio = 4 / 3;

    // 🎯 CONSISTENT INITIALIZATION: 40% of smaller dimension
    final iw = _iw.toDouble();
    final ih = _ih.toDouble();
    
    final smallerDim = math.min(iw, ih);
    
    // Use consistent 40% of smaller dimension
    if (_ratio >= 1.0) {
      // Horizontal crop box (4:3)
      _cw = smallerDim * 0.40;
      _ch = _cw / _ratio;
    } else {
      // Vertical crop box (3:4)
      _ch = smallerDim * 0.40;
      _cw = _ch * _ratio;
    }

    // Center
    _left = (iw - _cw) / 2;
    _top = (ih - _ch) / 2;

    // 🎯 VALIDATE: Ensure initial crop box is within bounds
    _validateCropBounds(_iw, _ih);

    if (mounted) setState(() => _ready = true);
  }

  //Fast size decode helper (UI isolate-friendly)
  Future<ui.Image> _decodeUi(Uint8List bytes) {
    final c = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, (ui.Image img) => c.complete(img));
    return c.future;
  }

  void _setRatio(double newRatio) {
    if (_ratio == newRatio) return;
    
    final centerX = _left + _cw / 2;
    final centerY = _top + _ch / 2;

    _ratio = newRatio;

    // Use original image dimensions (no rotation)
    final iw = _iw.toDouble();
    final ih = _ih.toDouble();

    // 🎯 Calculate crop box size based on smaller dimension
    final smallerDim = math.min(iw, ih);
    
    double newW, newH;
    
    if (_ratio >= 1.0) {
      // Horizontal crop box (4:3) - use consistent 40%
      newW = smallerDim * 0.40;
      newH = newW / _ratio;
    } else {
      // Vertical crop box (3:4) - use consistent 40%
      newH = smallerDim * 0.40;
      newW = newH * _ratio;
    }

    // Ensure minimum size
    if (newW < _minSize) {
      newW = _minSize;
      newH = newW / _ratio;
    }
    if (newH < _minSize) {
      newH = _minSize;
      newW = newH * _ratio;
    }

    // Boundary checks - ensure crop box doesn't exceed image
    if (newW > iw * 0.85) {
      newW = iw * 0.85;
      newH = newW / _ratio;
    }
    if (newH > ih * 0.85) {
      newH = ih * 0.85;
      newW = newH * _ratio;
    }

    _cw = newW.clamp(_minSize, iw);
    _ch = newH.clamp(_minSize, ih);

    // Recenter the crop box
    _left = (centerX - _cw / 2).clamp(0.0, iw - _cw);
    _top = (centerY - _ch / 2).clamp(0.0, ih - _ch);

    // 🎯 VALIDATE: Ensure bounds are respected after ratio change
    _validateCropBounds(_iw, _ih);

    setState(() {});
  }

  // Convert screen point to image coordinates
  Offset _screenToImage(Offset p) {
    // Simple conversion without zoom
    final adjustedX = (p.dx - _imgDx) / _scale;
    final adjustedY = (p.dy - _imgDy) / _scale;

    return Offset(adjustedX, adjustedY);
  }

  // Handle pinch gesture start
  void _onScaleStart(ScaleStartDetails d) {
    // Detect what we're touching
    final imgPt = _screenToImage(d.focalPoint);
    final handleHit = _hitHandle(imgPt);
    
    if (handleHit != null) {
      // Touching corner/edge → Resize mode
      _drag = handleHit;
    } else {
      // Touching anywhere else → Could be pan or pinch
      _drag = 'pan';
    }
    
    _lastGlobal = d.focalPoint;
    _initialScale = 1.0;
    _initialCropWidth = _cw;
    _initialCropHeight = _ch;
  }

  // Handle pinch gesture update
  void _onScaleUpdate(ScaleUpdateDetails d) {
    // Check if this is a pinch gesture (2 fingers)
    if (d.scale != 1.0 && (d.scale - _initialScale!).abs() > 0.01) {
      // PINCH MODE: Resize crop box with two fingers
      _handlePinchResize(d.scale);
      return;
    }
    
    // Otherwise, it's a PAN gesture (1 finger)
    if (_drag != null && _lastGlobal != null) {
      _handleCropDrag(d.focalPoint);
    }
  }

  // Handle pinch gesture end
  void _onScaleEnd(ScaleEndDetails d) {
    _drag = null;
    _lastGlobal = null;
    _initialScale = null;
    _initialCropWidth = null;
    _initialCropHeight = null;
  }

  // Handle pinch-to-resize crop box
  void _handlePinchResize(double scale) {
    // Use original image dimensions (no rotation)
    final iw = _iw.toDouble();
    final ih = _ih.toDouble();
    
    setState(() {
      double newW, newH;
      
      // 🎯 Natural pinch behavior based on orientation
      if (_ratio >= 1.0) {
        // 4:3 (Horizontal): Pinch expands WIDTH → height follows
        newW = _initialCropWidth! * scale;
        newH = newW / _ratio;
      } else {
        // 3:4 (Vertical): Pinch expands HEIGHT → width follows
        newH = _initialCropHeight! * scale;
        newW = newH * _ratio;
      }
      
      // Apply minimum size constraint
      if (newW < _minSize) {
        newW = _minSize;
        newH = newW / _ratio;
      }
      if (newH < _minSize) {
        newH = _minSize;
        newW = newH * _ratio;
      }
      
      // Apply maximum size constraint (85% of image)
      if (newW > iw * 0.85) {
        newW = iw * 0.85;
        newH = newW / _ratio;
      }
      if (newH > ih * 0.85) {
        newH = ih * 0.85;
        newW = newH * _ratio;
      }
      
      // Keep crop box centered during pinch
      final centerX = _left + _cw / 2;
      final centerY = _top + _ch / 2;
      
      _cw = newW;
      _ch = newH;
      
      // Recenter after resize
      _left = (centerX - _cw / 2).clamp(0.0, iw - _cw);
      _top = (centerY - _ch / 2).clamp(0.0, ih - _ch);
      
      // 🎯 VALIDATE: Ensure bounds are respected after pinch
      _validateCropBounds(_iw, _ih);
    });
  }

  void _handleCropDrag(Offset currentPos) {
    if (_lastGlobal == null) return;

    final prev = _screenToImage(_lastGlobal!);
    final cur = _screenToImage(currentPos);
  final dx = cur.dx - prev.dx;
  final dy = cur.dy - prev.dy;

  // Use original image dimensions (no rotation)
  final iw = _iw.toDouble();
  final ih = _ih.toDouble();

  setState(() {
    if (_drag == 'pan') {
      // 🎯 PAN MODE: Move image under crop box (crop box stays centered visually)
      // User drags transparent area → Image moves, crop box follows
      // This is like moving the image under a fixed viewport
      _left = (_left - dx).clamp(0.0, iw - _cw);
      _top = (_top - dy).clamp(0.0, ih - _ch);
    } else {
      // 🎯 RESIZE MODE: Resize from corners/edges while maintaining aspect ratio
      // Different behavior for horizontal (4:3) vs vertical (3:4) ratios
      double newLeft = _left;
      double newTop = _top;
      double newW = _cw;
      double newH = _ch;

      switch (_drag) {
        case 'tl': // Top-left corner
          if (_ratio >= 1.0) {
            // Horizontal crop (4:3): width drives height
            newLeft = _left + dx;
            newW = (_left + _cw) - newLeft;
            newH = newW / _ratio;
            newTop = (_top + _ch) - newH; // Anchor bottom-right
          } else {
            // Vertical crop (3:4): height drives width
            newTop = _top + dy;
            newH = (_top + _ch) - newTop;
            newW = newH * _ratio;
            newLeft = (_left + _cw) - newW; // Anchor bottom-right
          }
          
          // Adjust if exceeds bounds
          if (newLeft < 0) {
            newLeft = 0;
            newW = _left + _cw;
            if (_ratio >= 1.0) {
              newH = newW / _ratio;
              newTop = (_top + _ch) - newH;
            } else {
              newH = newW / _ratio;
              newTop = (_top + _ch) - newH;
            }
          }
          if (newTop < 0) {
            newTop = 0;
            newH = _top + _ch;
            newW = newH * _ratio;
            if (_ratio >= 1.0) {
              // Keep left unchanged
            } else {
              newLeft = (_left + _cw) - newW;
            }
          }
          break;

        case 'tr': // Top-right corner
          if (_ratio >= 1.0) {
            // Horizontal crop (4:3): width drives height
            newW = _cw + dx;
            newH = newW / _ratio;
            newTop = (_top + _ch) - newH; // Anchor bottom-left
          } else {
            // Vertical crop (3:4): height drives width
            newTop = _top + dy;
            newH = (_top + _ch) - newTop;
            newW = newH * _ratio;
          }
          
          // Adjust if exceeds bounds
          if (newLeft + newW > iw) {
            newW = iw - newLeft;
            newH = newW / _ratio;
            if (_ratio >= 1.0) {
              newTop = (_top + _ch) - newH;
            } else {
              newTop = (_top + _ch) - newH;
            }
          }
          if (newTop < 0) {
            newTop = 0;
            newH = _top + _ch;
            newW = newH * _ratio;
          }
          break;

        case 'bl': // Bottom-left corner
          if (_ratio >= 1.0) {
            // Horizontal crop (4:3): width drives height
            newLeft = _left + dx;
            newW = (_left + _cw) - newLeft;
            newH = newW / _ratio;
          } else {
            // Vertical crop (3:4): height drives width
            newH = _ch + dy;
            newW = newH * _ratio;
            newLeft = (_left + _cw) - newW; // Anchor top-right
          }
          
          // Adjust if exceeds bounds
          if (newLeft < 0) {
            newLeft = 0;
            newW = _left + _cw;
            newH = newW / _ratio;
          }
          if (newTop + newH > ih) {
            newH = ih - newTop;
            newW = newH * _ratio;
            if (_ratio >= 1.0) {
              newLeft = (_left + _cw) - newW;
            } else {
              newLeft = (_left + _cw) - newW;
            }
          }
          break;

        case 'br': // Bottom-right corner
          if (_ratio >= 1.0) {
            // Horizontal crop (4:3): width drives height
            newW = _cw + dx;
            newH = newW / _ratio;
          } else {
            // Vertical crop (3:4): height drives width
            newH = _ch + dy;
            newW = newH * _ratio;
          }
          
          // Adjust if exceeds bounds
          if (newLeft + newW > iw) {
            newW = iw - newLeft;
            newH = newW / _ratio;
          }
          if (newTop + newH > ih) {
            newH = ih - newTop;
            newW = newH * _ratio;
          }
          break;
      }

      // Apply minimum size constraint
      if (newW < _minSize) {
        newW = _minSize;
        newH = newW / _ratio;
        
        // Adjust position for tl and bl corners
        if (_drag == 'tl' || _drag == 'bl') {
          newLeft = (_left + _cw) - newW;
        }
        
        // Adjust top for tl and tr corners
        if (_drag == 'tl' || _drag == 'tr') {
          newTop = (_top + _ch) - newH;
        }
      }
      
      if (newH < _minSize) {
        newH = _minSize;
        newW = newH * _ratio;
        
        // Adjust position for tl and bl corners
        if (_drag == 'tl' || _drag == 'bl') {
          newLeft = (_left + _cw) - newW;
        }
        
        // Adjust top for tl and tr corners
        if (_drag == 'tl' || _drag == 'tr') {
          newTop = (_top + _ch) - newH;
        }
      }

      // Final boundary checks
      newLeft = newLeft.clamp(0.0, iw - newW);
      newTop = newTop.clamp(0.0, ih - newH);
      newW = newW.clamp(_minSize, iw - newLeft);
      newH = newH.clamp(_minSize, ih - newTop);

      _left = newLeft;
      _top = newTop;
      _cw = newW;
      _ch = newH;
      
      // 🎯 VALIDATE: Ensure bounds are respected after resize
      _validateCropBounds(_iw, _ih);
    }
  });

  _lastGlobal = currentPos;
  }

  String? _hitHandle(Offset imgPt) {
    // 🎯 RESPONSIVE HIT DETECTION: Larger hit areas for better touch response
    // Use adaptive sizing based on scale AND crop box size
    // For smaller crop boxes (like 3:4), we need proportionally larger hit zones
    
    // Calculate handle size: at least 80px in screen coordinates (larger for 3:4!)
    final handleScreenSize = 80.0;
    final handleImageSize = handleScreenSize / _scale;
    
    // Create LARGE hit zones at each corner
    final tl = Rect.fromCenter(center: Offset(_left, _top), width: handleImageSize, height: handleImageSize);
    final tr = Rect.fromCenter(center: Offset(_left + _cw, _top), width: handleImageSize, height: handleImageSize);
    final bl = Rect.fromCenter(center: Offset(_left, _top + _ch), width: handleImageSize, height: handleImageSize);
    final br = Rect.fromCenter(center: Offset(_left + _cw, _top + _ch), width: handleImageSize, height: handleImageSize);
    
    // Check corners FIRST (priority over everything else)
    if (tl.contains(imgPt)) return 'tl';
    if (tr.contains(imgPt)) return 'tr';
    if (bl.contains(imgPt)) return 'bl';
    if (br.contains(imgPt)) return 'br';
    
    // Also check edges for resize (larger threshold for 3:4)
    final edgeThreshold = math.max(40.0, 50.0 / _scale);
    final cropRect = Rect.fromLTWH(_left, _top, _cw, _ch);
    
    if (!cropRect.contains(imgPt)) return null;
    
    // Check if near edges
    final nearLeft = (imgPt.dx - _left).abs() < edgeThreshold;
    final nearRight = (imgPt.dx - (_left + _cw)).abs() < edgeThreshold;
    final nearTop = (imgPt.dy - _top).abs() < edgeThreshold;
    final nearBottom = (imgPt.dy - (_top + _ch)).abs() < edgeThreshold;
    
    // Prioritize corners over edges
    if (nearTop && nearLeft) return 'tl';
    if (nearTop && nearRight) return 'tr';
    if (nearBottom && nearLeft) return 'bl';
    if (nearBottom && nearRight) return 'br';
    
    return null;
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
          outPath: outPath,
          x: _left.round(),
          y: _top.round(),
          w: _cw.round(),
          h: _ch.round(),
          quality: 70, // ✅ Reduced to 70 to decrease file size for better upload
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
          IconButton(
            tooltip: '4:3 (Horizontal)',
            icon: _buildRatioButton('4:3', 4/3),
            onPressed: _ready ? () => _setRatio(4/3) : null,
          ),
          IconButton(
            tooltip: '3:4 (Vertical)',
            icon: _buildRatioButton('3:4', 3/4),
            onPressed: _ready ? () => _setRatio(3/4) : null,
          ),
          IconButton(
            tooltip: 'Confirmar',
            onPressed: _ready ? _onConfirm : null, 
            icon: const Icon(Icons.check, color: Colors.white),
          )
        ],
      ),
      body: _ready ? _buildCropperBody() : const Center(child: CircularProgressIndicator()),
    );
  }

  /// Build ratio button widget
  Widget _buildRatioButton(String label, double ratio) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _ratio == ratio ? Colors.blue : Colors.transparent,
        border: Border.all(color: Colors.white, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  /// Build the main cropper body with LayoutBuilder
  Widget _buildCropperBody() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxW = constraints.maxWidth;
        final boxH = constraints.maxHeight;

        // Use original image dimensions (no rotation)
        // Calculate scale for image display
        _scale = _calculateImageScale(boxW, boxH, _iw, _ih);

        // Calculate render dimensions and centering
        final renderW = _iw * _scale;
        final renderH = _ih * _scale;
        _imgDx = (boxW - renderW) / 2;
        _imgDy = (boxH - renderH) / 2;

        // Calculate crop box screen coordinates
        final cropBoxRect = _getCropBoxScreenRect();

        return Stack(
          children: [
            _buildImageLayer(renderW, renderH),
            _buildCropBoxLayer(cropBoxRect),
            if (_saving) _buildSavingOverlay(),
          ],
        );
      },
    );
  }

  double _calculateImageScale(double boxW, double boxH, int effectiveIW, int effectiveIH) {
    final sW = boxW / effectiveIW;
    final sH = boxH / effectiveIH;
    final baseFitScale = math.min(sW, sH);

    // 🎯 SMART SCALING FOR LANDSCAPE IMAGES
    // Detect landscape images (width > height)
    final isLandscape = effectiveIW > effectiveIH;
    final aspectRatio = effectiveIW / effectiveIH;
    
    if (isLandscape && aspectRatio > 1.3) {
      // 🎯 LANDSCAPE MODE: For wide images (1040×600, 445×161, 800×600)
      // Priority: Fill width to maximize screen usage
      // These images look better when they utilize the full width
      
      // Use width-based scaling with a higher minimum (70% width coverage)
      final minWidthScale = boxW * 0.70 / effectiveIW;
      final targetScale = math.max(baseFitScale, minWidthScale);
      
      // Ensure the image still fits vertically (don't exceed screen height)
      final maxHeightScale = boxH / effectiveIH;
      return math.min(targetScale, maxHeightScale);
    } else {
      // 🎯 PORTRAIT/SQUARE MODE: Standard fit-contain with minimum scale
      // For portrait or nearly-square images, use the original logic
      
      // Calculate minimum scale to ensure reasonable screen coverage
      // We want at least 50% of screen width OR height to be filled
      final minScaleW = boxW * 0.5 / effectiveIW;
      final minScaleH = boxH * 0.5 / effectiveIH;
      final minScale = math.max(minScaleW, minScaleH);
      
      // Use baseFitScale (shows full image) but enforce minimum for small images
      final finalScale = math.max(baseFitScale, minScale);
      
      return finalScale;
    }
  }

  /// Validate crop box stays within image bounds
  void _validateCropBounds(int effectiveIW, int effectiveIH) {
    final iw = effectiveIW.toDouble();
    final ih = effectiveIH.toDouble();
    
    // 🎯 STEP 1: Ensure crop box dimensions NEVER exceed image dimensions
    if (_cw > iw) {
      _cw = iw * 0.9;
      _ch = _cw / _ratio;
    }
    
    if (_ch > ih) {
      _ch = ih * 0.9;
      _cw = _ch * _ratio;
    }
    
    // 🎯 STEP 2: Ensure crop box dimensions maintain aspect ratio and fit
    // After adjusting height, width might exceed bounds - check again
    if (_cw > iw) {
      _cw = iw * 0.9;
      _ch = _cw / _ratio;
    }
    
    // 🎯 STEP 3: Clamp crop box position within image bounds
    final maxLeft = math.max(0.0, iw - _cw);
    final maxTop = math.max(0.0, ih - _ch);
    
    _left = _left.clamp(0.0, maxLeft);
    _top = _top.clamp(0.0, maxTop);
    
    // 🎯 STEP 4: FINAL SAFETY CHECK - Ensure right/bottom edges are within image
    if (_left + _cw > iw) {
      _left = iw - _cw;
      if (_left < 0) {
        _left = 0;
        _cw = iw;
        _ch = _cw / _ratio;
      }
    }
    
    if (_top + _ch > ih) {
      _top = ih - _ch;
      if (_top < 0) {
        _top = 0;
        _ch = ih;
        _cw = _ch * _ratio;
      }
    }
  }

  /// Get crop box rectangle in screen coordinates
  Rect _getCropBoxScreenRect() {
    return Rect.fromLTWH(
      _imgDx + _left * _scale,
      _imgDy + _top * _scale,
      _cw * _scale,
      _ch * _scale,
    );
  }

  /// Build image layer with rotation handling
  Widget _buildImageLayer(double renderW, double renderH) {
    return GestureDetector(
      // Use onScale* to handle BOTH pan (1 finger) and pinch (2 fingers)
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      onScaleEnd: _onScaleEnd,
      child: Stack(
        children: [
          // Image display (no rotation)
          Positioned(
            left: _imgDx,
            top: _imgDy,
            width: renderW,
            height: renderH,
            child: Image.file(
              File(widget.file.path),
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  /// Build crop box layer with overlay and handles
  Widget _buildCropBoxLayer(Rect cropRect) {
    const handleSize = 16.0; // Larger visual handles
    
    return Stack(
      children: [
        // Dimmed overlay outside crop box (pointer events pass through)
        IgnorePointer(
          child: CustomPaint(
            painter: _DimOutsidePainter(cropRect),
            size: Size.infinite,
          ),
        ),
        // Crop box border and handles (RESPONSIVE to touch)
        Positioned(
          left: cropRect.left,
          top: cropRect.top,
          width: cropRect.width,
          height: cropRect.height,
          child: IgnorePointer(
            child: Stack(
              children: [
                // White border
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
                // Corner handles (larger and more visible)
                Positioned(left: -handleSize, top: -handleSize, width: handleSize * 2, height: handleSize * 2, child: _Handle()),
                Positioned(right: -handleSize, top: -handleSize, width: handleSize * 2, height: handleSize * 2, child: _Handle()),
                Positioned(left: -handleSize, bottom: -handleSize, width: handleSize * 2, height: handleSize * 2, child: _Handle()),
                Positioned(right: -handleSize, bottom: -handleSize, width: handleSize * 2, height: handleSize * 2, child: _Handle()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Build saving overlay
  Widget _buildSavingOverlay() {
    return const Stack(
      children: [
        ModalBarrier(dismissible: false, color: Colors.black38),
        Center(child: CircularProgressIndicator()),
      ],
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

  // Clamp coordinates to image bounds
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