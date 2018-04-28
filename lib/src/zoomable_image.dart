import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class ZoomableImage extends StatefulWidget {
  final ImageProvider image;
  final double maxScale;
  final double maxZoom;
  final double minZoom;
  final GestureTapCallback onTap;
  final Color backgroundColor;

  ZoomableImage(this.image, {
    Key key,
    @deprecated double scale,
    /// Maximum ratio to blow up image pixels. A value of 2.0 means that the
    /// a single device pixel will be rendered as up to 4 logical pixels.
    this.maxScale = 2.0,
    /// Maximum zoom relative to the size of the image within the context.
    /// A value of 4.0 means that the image can be zoomed in to at most 4x its
    /// starting size.
    this.maxZoom = 4.0,
    /// Minimum zoom relative to the size of the image within the context.
    /// A value of 0.5 means that the image can be zoomed out to be at most 0.5x
    /// its starting size.
    this.minZoom = 0.5,
    this.onTap,
    this.backgroundColor = Colors.black,
  })
      : super(key: key);

  @override
  _ZoomableImageState createState() => new _ZoomableImageState();
}

// See /flutter/examples/layers/widgets/gestures.dart
class _ZoomableImageState extends State<ZoomableImage> {
  ImageStream _imageStream;
  ui.Image _image;
  Size _imageSize;

  Offset _startingFocalPoint;

  Offset _previousOffset;
  Offset _offset; // where the top left corner of the image is drawn

  double _previousScale;
  double _scale; // multiplier applied to scale the full image

  @override
  Widget build(BuildContext ctx) => _image == null
      ? new Container()
      : new LayoutBuilder(builder: _buildLayout);

  Widget _buildLayout(BuildContext ctx, BoxConstraints constraints) {
    if (_offset == null || _scale == null) {
      _imageSize = new Size(
        _image.width.toDouble(),
        _image.height.toDouble(),
      );

      Size canvas = constraints.biggest;
      Size fitted = _containmentSize(canvas, _imageSize);

      Offset delta = canvas - fitted;
      _offset = delta / 2.0; // Centers the image
      _scale = canvas.width / _imageSize.width;
    }

    return new GestureDetector(
      child: _child(),
      onTap: widget.onTap,
      onDoubleTap: () => _handleDoubleTap(ctx),
      onScaleStart: _handleScaleStart,
      onScaleUpdate: _handleScaleUpdate,
    );
  }

  Widget _child() {
    return new CustomPaint(
      child: new Container(color: widget.backgroundColor),
      foregroundPainter: new _ZoomableImagePainter(
        image: _image,
        offset: _offset,
        scale: _scale,
      ),
    );
  }

  void _handleDoubleTap(BuildContext ctx) {
    double newScale = _scale * 2;
    if (newScale > widget.maxScale) {
      return;
    }

    // We want to zoom in on the center of the screen.
    // Since we're zooming by a factor of 2, we want the new offset to be twice
    // as far from the center in both width and height than it is now.
    Offset center = ctx.size.center(Offset.zero);
    Offset newOffset = _offset - (center - _offset);

    setState(() {
      _scale = newScale;
      _offset = newOffset;
    });
  }

  void _handleScaleStart(ScaleStartDetails d) {
    print("starting scale at ${d.focalPoint} from $_offset $_scale");
    _startingFocalPoint = d.focalPoint;
    _previousOffset = _offset;
    _previousScale = _scale;
  }

  void _handleScaleUpdate(ScaleUpdateDetails d) {
    double newScale = _previousScale * d.scale;
    if (newScale > widget.maxScale) {
      return;
    }

    // Ensure that item under the focal point stays in the same place despite zooming
    final Offset normalizedOffset =
        (_startingFocalPoint - _previousOffset) / _previousScale;
    final Offset newOffset = d.focalPoint - normalizedOffset * newScale;

    setState(() {
      _scale = newScale;
      _offset = newOffset;
    });
  }

  @override
  void didChangeDependencies() {
    _resolveImage();
    super.didChangeDependencies();
  }

  @override
  void reassemble() {
    _resolveImage(); // in case the image cache was flushed
    super.reassemble();
  }

  void _resolveImage() {
    _imageStream = widget.image.resolve(createLocalImageConfiguration(context));
    _imageStream.addListener(_handleImageLoaded);
  }

  void _handleImageLoaded(ImageInfo info, bool synchronousCall) {
    print("image loaded: $info");
    setState(() {
      _image = info.image;
    });
  }

  @override
  void dispose() {
    _imageStream.removeListener(_handleImageLoaded);
    super.dispose();
  }
}

// Given a canvas and an image, determine what size the image should be to be contained in but not
// exceed the canvas while preserving its aspect ratio.
Size _containmentSize(Size canvas, Size image) {
  double canvasRatio = canvas.width / canvas.height;
  double imageRatio = image.width / image.height;

  if (canvasRatio < imageRatio) {
    // fat
    return new Size(canvas.width, canvas.width / imageRatio);
  } else if (canvasRatio > imageRatio) {
    // skinny
    return new Size(canvas.height * imageRatio, canvas.height);
  } else {
    return canvas;
  }
}

class _ZoomableImagePainter extends CustomPainter {
  const _ZoomableImagePainter({this.image, this.offset, this.scale});

  final ui.Image image;
  final Offset offset;
  final double scale;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    Size imageSize = new Size(image.width.toDouble(), image.height.toDouble());
    Size targetSize = imageSize * scale;

    paintImage(
      canvas: canvas,
      rect: offset & targetSize,
      image: image,
      fit: BoxFit.fill,
    );
  }

  @override
  bool shouldRepaint(_ZoomableImagePainter old) {
    return old.image != image || old.offset != offset || old.scale != scale;
  }
}
