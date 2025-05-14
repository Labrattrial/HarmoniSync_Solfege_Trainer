import 'package:flutter/material.dart';
import '../services/music_service.dart';

class MusicSheet extends StatelessWidget {
  final Score score;

  const MusicSheet({
    super.key,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate total width needed for all measures
    final measureCount = score.measures.length;
    final minMeasureWidth = 120.0;
    final totalWidth = (measureCount * minMeasureWidth) + 140.0; // margin for clef/time signature
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(16),
        width: totalWidth,
        child: CustomPaint(
          painter: MusicSheetPainter(score: score),
          size: Size(totalWidth, 300),
        ),
      ),
    );
  }
}

class MusicSheetPainter extends CustomPainter {
  final Score score;
  static const double staffSpacing = 12.0; // Increased for better readability
  static const double lineWidth = 1.5; // Slightly thicker lines
  static const double noteSize = 10.0; // Larger notes
  static const double stemLength = 25.0; // Longer stems
  static const double beamSpacing = 4.0;
  static const double ledgerLineLength = 8.0;
  static const double measureWidth = 100.0; // Width for each measure

  MusicSheetPainter({required this.score});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke;

    // Draw staff lines
    _drawStaff(canvas, size, paint);

    // Draw clef
    _drawClef(canvas, size, paint);

    // Draw time signature
    _drawTimeSignature(canvas, size, paint);

    // Draw measures and notes
    _drawMeasures(canvas, size, paint);
  }

  void _drawStaff(Canvas canvas, Size size, Paint paint) {
    final startX = 60.0; // Increased margin
    final endX = size.width - 20.0;
    final startY = 80.0; // Increased top margin

    for (var i = 0; i < 5; i++) {
      final y = startY + (i * staffSpacing);
      canvas.drawLine(
        Offset(startX, y),
        Offset(endX, y),
        paint,
      );
    }
  }

  void _drawClef(Canvas canvas, Size size, Paint paint) {
    final path = Path();
    final startX = 60.0;
    final startY = 40.0;

    // Draw a more detailed treble clef
    path.moveTo(startX, startY + 60);
    path.quadraticBezierTo(
      startX + 5,
      startY + 40,
      startX + 15,
      startY + 50,
    );
    path.quadraticBezierTo(
      startX + 25,
      startY + 60,
      startX + 15,
      startY + 70,
    );
    path.quadraticBezierTo(
      startX + 5,
      startY + 80,
      startX,
      startY + 60,
    );

    // Add the curl
    path.moveTo(startX + 15, startY + 70);
    path.quadraticBezierTo(
      startX + 20,
      startY + 75,
      startX + 25,
      startY + 70,
    );

    canvas.drawPath(path, paint);
  }

  void _drawTimeSignature(Canvas canvas, Size size, Paint paint) {
    final startX = 90.0;
    final startY = 60.0;

    final textPainter = TextPainter(
      text: TextSpan(
        text: '${score.beats}/${score.beatType}',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(startX, startY));
  }

  void _drawMeasures(Canvas canvas, Size size, Paint paint) {
    final startY = 80.0;
    final staffHeight = staffSpacing * 4;
    final measureCount = score.measures.length;
    final minMeasureWidth = 120.0;
    final totalWidth = size.width - 140.0;
    final measureWidth = totalWidth / measureCount;
    double currentX = 120.0;

    for (int m = 0; m < measureCount; m++) {
      final measure = score.measures[m];
      // --- Engraving-accurate barline ---
      // Barlines extend slightly above and below the staff
      canvas.drawLine(
        Offset(currentX, startY - 2),
        Offset(currentX, startY + staffHeight + 2),
        paint,
      );
      // Proportional note spacing: wider for longer notes
      final noteCount = measure.notes.length;
      double noteSpacing = 0;
      if (noteCount > 1) {
        // Give more space for whole/half notes, less for short notes
        final longNotes = measure.notes.where((n) => n.type == 'whole' || n.type == 'half').length;
        final shortNotes = noteCount - longNotes;
        final baseSpacing = ((measureWidth - 20) / (noteCount - 1)).clamp(30.0, 60.0);
        noteSpacing = baseSpacing + (longNotes > 0 ? 10.0 : 0.0) - (shortNotes > 0 ? 5.0 : 0.0);
      }
      double noteX = currentX + 20.0;
      for (final note in measure.notes) {
        if (note.isRest) {
          _drawRest(canvas, noteX, startY, note, paint);
        } else {
          _drawNote(canvas, noteX, startY, note, paint);
        }
        noteX += noteSpacing;
      }
      // Move to next measure
      currentX += measureWidth;
    }
    // Final barline
    canvas.drawLine(
      Offset(currentX, startY - 2),
      Offset(currentX, startY + staffHeight + 2),
      paint,
    );
  }

  void _drawNote(Canvas canvas, double x, double startY, Note note, Paint paint) {
    final y = _getNoteY(note, startY);

    // Draw ledger lines if needed
    _drawLedgerLines(canvas, x, y, startY, paint);

    // Draw accidental if needed
    if (note.alter != null && note.alter != 0) {
      _drawAccidental(canvas, x - 15, y, note.alter!, paint);
    }

    // Draw note head (filled or open)
    _drawNoteHead(canvas, x, y, note, paint);

    // Draw stem if needed
    if (_hasStem(note.type)) {
      _drawStem(canvas, x, y, note, paint);
    }

    // Draw flags if needed
    if (_hasFlag(note.type)) {
      _drawFlag(canvas, x, y, note, paint);
    }

    // Draw dot if needed
    if (note.hasDot) {
      _drawDot(canvas, x, y, paint);
    }

    // Draw slurs if needed
    if (note.slurs.isNotEmpty) {
      _drawSlurs(canvas, x, y, note, paint);
    }

    // Draw triplet if needed
    if (note.type == 'triplet') {
      _drawTriplet(canvas, x, y, paint);
    }
  }

  void _drawNoteHead(Canvas canvas, double x, double y, Note note, Paint paint) {
    // --- Engraving-accurate notehead ---
    // Elliptical, tilted (about 20 degrees), open or filled as needed
    final width = noteSize * 2.0;
    final height = noteSize * 1.2;
    final angle = 20 * 3.14159 / 180; // 20 degrees in radians
    final path = Path();
    // Draw an ellipse by transforming the canvas
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle);
    Rect oval = Rect.fromCenter(center: Offset(0, 0), width: width, height: height);
    if (note.type == 'half' || note.type == 'whole') {
      // Open notehead
      canvas.drawOval(oval, paint);
    } else {
      // Filled notehead
      final fillPaint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill;
      canvas.drawOval(oval, fillPaint);
      canvas.drawOval(oval, paint);
    }
    canvas.restore();
  }

  bool _hasStem(String type) {
    return type != 'whole';
  }

  bool _hasFlag(String type) {
    return type == 'eighth' || type == '16th' || type == '32nd';
  }

  void _drawStem(Canvas canvas, double x, double y, Note note, Paint paint) {
    // --- Engraving-accurate stem ---
    // Stems are 3.5 staff spaces (one octave) long
    final stemLengthEngraved = staffSpacing * 3.5;
    final middleLineY = _getNoteY(Note(step: 'B', octave: 4, type: note.type, duration: note.duration, isRest: false), y);
    final stemUp = y > middleLineY;
    double stemX, stemY;
    if (note.type == 'half' || note.type == 'whole') {
      if (stemUp) {
        // Stem up, right side
        stemX = x + noteSize;
        stemY = y - stemLengthEngraved;
        canvas.drawLine(
          Offset(stemX, y),
          Offset(stemX, stemY),
          paint,
        );
      } else {
        // Stem down, left side
        stemX = x - noteSize;
        stemY = y + stemLengthEngraved;
        canvas.drawLine(
          Offset(stemX, y),
          Offset(stemX, stemY),
          paint,
        );
      }
      return;
    }
    // Default for other note types
    stemX = stemUp ? x + noteSize : x - noteSize;
    stemY = stemUp ? y - stemLengthEngraved : y + stemLengthEngraved;
    canvas.drawLine(
      Offset(stemX, y),
      Offset(stemX, stemY),
      paint,
    );
  }

  void _drawFlag(Canvas canvas, double x, double y, Note note, Paint paint) {
    // --- Engraving-accurate flag ---
    // Curved, graceful, and correct direction
    final middleLineY = _getNoteY(Note(step: 'B', octave: 4, type: note.type, duration: note.duration, isRest: false), y);
    final stemUp = y > middleLineY;
    final stemX = stemUp ? x + noteSize : x - noteSize;
    final stemY = stemUp ? y - staffSpacing * 3.5 : y + staffSpacing * 3.5;
    final flagLength = 14.0;
    final flagCurve = 8.0;
    final flagCount = note.type == 'eighth' ? 1 : note.type == '16th' ? 2 : 3;
    for (int i = 0; i < flagCount; i++) {
      final offset = i * 5.0;
      final path = Path();
      if (stemUp) {
        path.moveTo(stemX, stemY + offset);
        path.cubicTo(
          stemX + flagLength / 3,
          stemY + offset + flagCurve,
          stemX + flagLength * 0.8,
          stemY + offset + flagCurve * 0.7,
          stemX + flagLength,
          stemY + offset + flagCurve * 0.5,
        );
      } else {
        path.moveTo(stemX, stemY - offset);
        path.cubicTo(
          stemX - flagLength / 3,
          stemY - offset - flagCurve,
          stemX - flagLength * 0.8,
          stemY - offset - flagCurve * 0.7,
          stemX - flagLength,
          stemY - offset - flagCurve * 0.5,
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  void _drawRest(Canvas canvas, double x, double startY, Note note, Paint paint) {
    // --- Engraving-accurate rest shapes ---
    final y = startY + (staffSpacing * 2);
    final path = Path();
    switch (note.type) {
      case 'whole':
        // Whole rest: rectangle hanging from 4th line
        path.addRect(Rect.fromLTWH(x - 8, y - staffSpacing, 16, 6));
        break;
      case 'half':
        // Half rest: rectangle sitting on 3rd line
        path.addRect(Rect.fromLTWH(x - 8, y - staffSpacing / 2, 16, 6));
        break;
      case 'quarter':
        // Quarter rest: standard squiggle
        path.moveTo(x, y - 10);
        path.relativeCubicTo(2, 4, -2, 8, 0, 12);
        path.relativeCubicTo(2, 4, -2, 8, 0, 12);
        break;
      case 'eighth':
        // Eighth rest: 7 shape with dot
        path.moveTo(x, y - 10);
        path.lineTo(x + 5, y);
        path.moveTo(x + 5, y);
        path.relativeArcToPoint(Offset(3, 3), radius: Radius.circular(2));
        break;
      case '16th':
        // Sixteenth rest: like eighth with extra flag
        path.moveTo(x, y - 10);
        path.lineTo(x + 5, y);
        path.moveTo(x + 5, y);
        path.relativeArcToPoint(Offset(3, 3), radius: Radius.circular(2));
        path.moveTo(x + 2, y + 2);
        path.relativeArcToPoint(Offset(3, 3), radius: Radius.circular(2));
        break;
      default:
        // Default to quarter rest
        path.moveTo(x, y - 10);
        path.relativeCubicTo(2, 4, -2, 8, 0, 12);
        path.relativeCubicTo(2, 4, -2, 8, 0, 12);
    }
    canvas.drawPath(path, paint);
  }

  void _drawTriplet(Canvas canvas, double x, double y, Paint paint) {
    // --- Engraving-accurate triplet ---
    // Place '3' above the group
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '3',
        style: TextStyle(
          color: Colors.black,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(x - 6, y - 35));
  }

  void _drawRepeatSign(Canvas canvas, double x, double startY, Paint paint) {
    // Double bar with two dots
    final top = startY;
    final bottom = startY + staffSpacing * 4;
    // Draw two vertical bars
    canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);
    canvas.drawLine(Offset(x + 6, top), Offset(x + 6, bottom), paint);
    // Draw two dots
    final dotPaint = Paint()..color = Colors.black..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(x + 10, startY + staffSpacing * 1.5), 2, dotPaint);
    canvas.drawCircle(Offset(x + 10, startY + staffSpacing * 2.5), 2, dotPaint);
  }

  void _drawLedgerLines(Canvas canvas, double x, double y, double startY, Paint paint) {
    final staffTop = startY;
    final staffBottom = startY + (staffSpacing * 4);
    
    // Calculate the nearest staff line
    final nearestLine = _getNearestStaffLine(y, startY);
    
    if (y < staffTop) {
      // Draw ledger lines above staff
      var lineY = nearestLine;
      while (lineY > y) {
        _drawLedgerLine(canvas, x, lineY, paint);
        lineY -= staffSpacing;
      }
    } else if (y > staffBottom) {
      // Draw ledger lines below staff
      var lineY = nearestLine;
      while (lineY < y) {
        _drawLedgerLine(canvas, x, lineY, paint);
        lineY += staffSpacing;
      }
    }
  }

  double _getNearestStaffLine(double y, double startY) {
    final staffLines = List.generate(5, (i) => startY + (i * staffSpacing));
    return staffLines.reduce((a, b) => (y - a).abs() < (y - b).abs() ? a : b);
  }

  void _drawLedgerLine(Canvas canvas, double x, double y, Paint paint) {
    // --- Engraving-accurate ledger line ---
    // Centered on notehead, not too long
    final length = noteSize * 2.2;
    canvas.drawLine(
      Offset(x - length / 2, y),
      Offset(x + length / 2, y),
      paint,
    );
  }

  void _drawAccidental(Canvas canvas, double x, double y, int alter, Paint paint) {
    // --- Engraving-accurate accidental placement ---
    // Place just to the left of the notehead, vertically centered
    final path = Path();
    if (alter == 1) { // Sharp
      path.moveTo(x, y - 10);
      path.lineTo(x, y + 10);
      path.moveTo(x - 3, y - 8);
      path.lineTo(x + 3, y + 8);
      path.moveTo(x - 3, y + 8);
      path.lineTo(x + 3, y - 8);
    } else if (alter == -1) { // Flat
      path.moveTo(x, y - 10);
      path.lineTo(x, y + 10);
      path.quadraticBezierTo(x + 5, y + 5, x, y);
    } else if (alter == 0) { // Natural
      path.moveTo(x, y - 10);
      path.lineTo(x, y + 10);
      path.moveTo(x - 3, y - 5);
      path.lineTo(x + 3, y + 5);
    }
    canvas.drawPath(path, paint);
  }

  void _drawDot(Canvas canvas, double x, double y, Paint paint) {
    // --- Engraving-accurate dot placement ---
    // Place dot precisely after the notehead, vertically centered
    canvas.drawCircle(
      Offset(x + noteSize * 1.5, y),
      noteSize / 4,
      paint,
    );
  }

  void _drawSlurs(Canvas canvas, double x, double y, Note note, Paint paint) {
    if (note.slurs.contains('start')) {
      final path = Path();
      path.moveTo(x, y - 15);
      path.quadraticBezierTo(
        x + 15,
        y - 25,
        x + 30,
        y - 15,
      );
      canvas.drawPath(path, paint);
    }
  }

  double _getNoteY(Note note, double startY) {
    // Standard mapping: E4 (bottom line) is index 0
    // Each step (line or space) is staffSpacing / 2
    final noteIndex = _getStaffIndex(note.step, note.octave);
    final e4LineY = startY + (staffSpacing * 4); // E4 is the bottom line
    return e4LineY - (noteIndex * staffSpacing / 2);
  }

  int _getStaffIndex(String step, int octave) {
    // Map note step/octave to staff index (relative to E4)
    // C4 = -2, D4 = -1, E4 = 0, F4 = 1, G4 = 2, A4 = 3, B4 = 4, C5 = 5, ...
    final stepOrder = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
    final e4Octave = 4;
    final e4StepIndex = 2; // 'E' in stepOrder
    final octaveDiff = octave - e4Octave;
    final stepDiff = stepOrder.indexOf(step) - e4StepIndex;
    return (octaveDiff * 7) + stepDiff;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 