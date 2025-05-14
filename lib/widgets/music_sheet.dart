import 'package:flutter/material.dart';
import '../services/music_service.dart';
import '../utils/music_fonts.dart';

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
    final minMeasureWidth = 160.0;
    final totalWidth = (measureCount * minMeasureWidth) + 200.0; // margin for clef/time signature
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(20),
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
  // Standard music engraving measurements
  static const double staffSpacing = 10.0;   // Space between staff lines
  static const double lineWidth = 1.2;      // Staff line thickness
  static const double noteSize = 24.0;      // Note head size
  static const double stemLength = 40.0;    // Standard stem length
  static const double beamSpacing = 8.0;    // Space between beams
  static const double ledgerLineLength = 16.0; // Length of ledger lines
  static const double measureWidth = 160.0;  // Width for each measure

  // Staff positioning
  static const double staffStartX = 80.0;   // Left margin for staff
  static const double staffStartY = 50.0;   // Top margin for staff
  static const double clefOffset = 85.0;     // Vertical offset for treble clef

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
    final endX = size.width - 20.0;
    paint.strokeWidth = lineWidth;
    
    for (var i = 0; i < 5; i++) {
      final y = staffStartY + (i * staffSpacing);
      canvas.drawLine(
        Offset(staffStartX, y),
        Offset(endX, y),
        paint,
      );
    }
  }

  void _drawClef(Canvas canvas, Size size, Paint paint) {
    // G clef (treble clef) should curl around the G line (second line from bottom)
    final textPainter = TextPainter(
      text: TextSpan(
        text: BravuraFont.trebleClef,
        style: const TextStyle(
          fontFamily: 'Bravura',
          fontSize: 48,  // Further reduced size
          color: Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    
    // Position clef so it curls around the G line
    final gLineY = staffStartY + staffSpacing * 3; // Second line from bottom
    final clefY = gLineY - textPainter.height * 0.52; // Further lowered the clef
    textPainter.paint(canvas, Offset(staffStartX + 4, clefY)); // Moved further right with positive offset
  }

  void _drawTimeSignature(Canvas canvas, Size size, Paint paint) {
    final beatsText = BravuraFont.getTimeSignature(score.beats);
    final beatTypeText = BravuraFont.getTimeSignature(score.beatType);
    
    // Draw numerator (top number)
    final numeratorPainter = TextPainter(
      text: TextSpan(
        text: beatsText,
        style: const TextStyle(
          fontFamily: 'Bravura',
          fontSize: 36,
          color: Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    numeratorPainter.layout();
    
    // Draw denominator (bottom number)
    final denominatorPainter = TextPainter(
      text: TextSpan(
        text: beatTypeText,
        style: const TextStyle(
          fontFamily: 'Bravura',
          fontSize: 36,
          color: Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    denominatorPainter.layout();
    
    // Position time signature after clef with proper spacing
    final timeX = staffStartX + 65;
    
    // Center the numbers vertically in the staff
    final staffCenterY = staffStartY + (staffSpacing * 2);
    final totalHeight = numeratorPainter.height + denominatorPainter.height;
    final spacing = -120.0; // Dramatically increased overlap (10x tighter)
    
    // Calculate Y positions to center the entire time signature in the staff
    final numeratorY = staffCenterY - (totalHeight + spacing) / 2;
    final denominatorY = numeratorY + numeratorPainter.height + spacing;
    
    // Draw the numbers
    numeratorPainter.paint(canvas, Offset(timeX, numeratorY));
    denominatorPainter.paint(canvas, Offset(timeX, denominatorY));
  }

  void _drawMeasures(Canvas canvas, Size size, Paint paint) {
    final staffHeight = staffSpacing * 4;
    final measureCount = score.measures.length;
    final totalWidth = size.width - 180.0;
    final measureWidth = (totalWidth / measureCount).clamp(160.0, 240.0);
    double currentX = staffStartX + 80.0; // Start after clef and time signature

    for (int m = 0; m < measureCount; m++) {
      final measure = score.measures[m];
      
      // Draw barline
      canvas.drawLine(
        Offset(currentX, staffStartY - 2),
        Offset(currentX, staffStartY + staffHeight + 2),
        paint..strokeWidth = lineWidth,
      );

      // Calculate note spacing within measure
      final noteCount = measure.notes.length;
      double noteSpacing = measureWidth / (noteCount + 1);
      
      // Adjust spacing based on note types
      if (noteCount > 1) {
        final longNotes = measure.notes.where((n) => n.type == 'whole' || n.type == 'half').length;
        final shortNotes = noteCount - longNotes;
        noteSpacing = ((measureWidth - 50) / noteCount).clamp(35.0, 70.0);
        if (longNotes > 0) noteSpacing += 12.0;
        if (shortNotes > 2) noteSpacing -= 6.0;
      }

      // Draw notes
      double noteX = currentX + 25.0;
      for (final note in measure.notes) {
        final noteY = _getNoteY(note, staffStartY);
        
        // Draw ledger lines if needed
        _drawLedgerLines(canvas, noteX, noteY, staffStartY, paint);
        
        // Draw accidentals
        if (note.alter != null && note.alter != 0) {
          _drawAccidental(canvas, noteX - 20, noteY, note.alter!, paint);
        }
        
        if (note.isRest) {
          _drawRest(canvas, noteX, noteY, note, paint);
        } else {
          // Draw note components in correct order
          _drawNoteHead(canvas, noteX, noteY, note, paint);
          
          if (_hasStem(note.type)) {
            _drawStem(canvas, noteX, noteY, note, paint);
          }
          
          if (_hasFlag(note.type)) {
            _drawFlag(canvas, noteX, noteY, note, paint);
          }
          
          if (note.hasDot) {
            _drawDot(canvas, noteX + noteSize/2 + 6, noteY, paint);
          }
        }
        
        // Draw slurs if present
        if (note.slurs.isNotEmpty) {
          _drawSlurs(canvas, noteX, noteY, note, paint);
        }
        
        noteX += noteSpacing;
      }

      currentX += measureWidth;
    }

    // Final double barline
    canvas.drawLine(
      Offset(currentX, staffStartY - 2),
      Offset(currentX, staffStartY + staffHeight + 2),
      paint..strokeWidth = lineWidth,
    );
    canvas.drawLine(
      Offset(currentX + 4, staffStartY - 2),
      Offset(currentX + 4, staffStartY + staffHeight + 2),
      paint..strokeWidth = lineWidth * 2,
    );
  }

  void _drawNote(Canvas canvas, double x, double startY, Note note, Paint paint) {
    _drawLedgerLines(canvas, x, startY, 80.0, paint);

    if (note.alter != null && note.alter != 0) {
      _drawAccidental(canvas, x - 20, startY, note.alter!, paint);
    }

    _drawNoteHead(canvas, x, startY, note, paint);

    if (_hasStem(note.type)) {
      _drawStem(canvas, x, startY, note, paint);
    }

    if (_hasFlag(note.type)) {
      _drawFlag(canvas, x, startY, note, paint);
    }

    if (note.hasDot) {
      _drawDot(canvas, x, startY, paint);
    }

    if (note.slurs.isNotEmpty) {
      _drawSlurs(canvas, x, startY, note, paint);
    }
  }

  void _drawNoteHead(Canvas canvas, double x, double y, Note note, Paint paint) {
    final text = note.type == 'whole' ? BravuraFont.noteheadWhole :
                note.type == 'half' ? BravuraFont.noteheadHalf :
                BravuraFont.noteheadBlack;

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Bravura',
          fontSize: noteSize,
          height: 1.0,
          color: Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    
    // Center the notehead precisely on the staff line or space
    final noteX = x - textPainter.width / 2;
    final noteY = y - textPainter.height / 2;

    // For half and whole notes, ensure crisp edges
    if (note.type == 'half' || note.type == 'whole') {
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = lineWidth;
    } else {
      paint.style = PaintingStyle.fill;
    }
    
    textPainter.paint(canvas, Offset(noteX, noteY));
  }

  bool _hasStem(String type) {
    return type != 'whole';
  }

  bool _hasFlag(String type) {
    return type == 'eighth' || type == '16th' || type == '32nd';
  }

  void _drawStem(Canvas canvas, double x, double y, Note note, Paint paint) {
    // Standard stem direction rules
    final middleLineY = staffStartY + (staffSpacing * 2);
    final stemUp = y >= middleLineY;
    
    final stemPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = lineWidth * 1.2  // Slightly thicker stem
      ..style = PaintingStyle.stroke;
    
    if (stemUp) {
      // Attach stem to right side of notehead
      canvas.drawLine(
        Offset(x + noteSize/3.5, y - noteSize/8),  // Better stem attachment
        Offset(x + noteSize/3.5, y - stemLength),
        stemPaint,
      );
    } else {
      // Attach stem to left side of notehead
      canvas.drawLine(
        Offset(x - noteSize/3.5, y + noteSize/8),  // Better stem attachment
        Offset(x - noteSize/3.5, y + stemLength),
        stemPaint,
      );
    }
  }

  void _drawFlag(Canvas canvas, double x, double y, Note note, Paint paint) {
    final middleLineY = staffStartY + (staffSpacing * 2);
    final stemUp = y >= middleLineY;
    final text = stemUp ? 
                (note.type == 'eighth' ? BravuraFont.flag8thUp : BravuraFont.flag16thUp) :
                (note.type == 'eighth' ? BravuraFont.flag8thDown : BravuraFont.flag16thDown);

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Bravura',
          fontSize: noteSize * 1.1,  // Slightly larger flag for better visibility
          height: 1.0,
          color: Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    
    // Position flag at the end of the stem with better alignment
    final xPos = stemUp ? 
                x + noteSize/3.5 - textPainter.width/2 : 
                x - noteSize/3.5 - textPainter.width/2;
    final yPos = stemUp ? 
                y - stemLength + noteSize/4 : 
                y + stemLength - noteSize * 0.7;
    textPainter.paint(canvas, Offset(xPos, yPos));
  }

  void _drawRest(Canvas canvas, double x, double y, Note note, Paint paint) {
    // Standard rest positions relative to the middle line
    double restY = staffStartY + staffSpacing * 2; // Middle line
    
    // Adjust rest position based on type
    if (note.type == 'whole') {
      restY = staffStartY + staffSpacing; // Fourth line from bottom
    } else if (note.type == 'half') {
      restY = staffStartY + staffSpacing * 1.5; // Third space from bottom
    } else if (note.type == 'quarter') {
      restY = staffStartY + staffSpacing * 2; // Middle line
    } else if (note.type == 'eighth' || note.type == '16th') {
      restY = staffStartY + staffSpacing * 2.5; // Second space from top
    }

    final text = note.type == 'whole' ? BravuraFont.restWhole :
                note.type == 'half' ? BravuraFont.restHalf :
                note.type == 'quarter' ? BravuraFont.restQuarter :
                note.type == 'eighth' ? BravuraFont.rest8th :
                note.type == '16th' ? BravuraFont.rest16th :
                BravuraFont.restQuarter;

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Bravura',
          fontSize: noteSize * 0.9,
          height: 1.0,
          color: Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final restX = x - textPainter.width / 2;
    textPainter.paint(canvas, Offset(restX, restY - textPainter.height / 2));
  }

  void _drawAccidental(Canvas canvas, double x, double y, int alter, Paint paint) {
    final text = alter == 1 ? BravuraFont.accidentalSharp :
                alter == -1 ? BravuraFont.accidentalFlat :
                BravuraFont.accidentalNatural;

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Bravura',
          fontSize: noteSize * 0.8,
          height: 1.0,
          color: Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    
    // Position accidental to the left of the notehead
    final accX = x - textPainter.width - 2;
    final accY = y - textPainter.height / 2;
    textPainter.paint(canvas, Offset(accX, accY));
  }

  void _drawDot(Canvas canvas, double x, double y, Paint paint) {
    final dotPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    
    // Position dot to the right of the notehead, aligned with spaces
    final dotY = (y / staffSpacing).round() * staffSpacing;
    canvas.drawCircle(
      Offset(x + noteSize/2 + 4, dotY),
      noteSize * 0.15,  // Smaller, more refined dot
      dotPaint
    );
  }

  void _drawSlurs(Canvas canvas, double x, double y, Note note, Paint paint) {
    // Handle slur start points
    for (final slur in note.slurs) {
      if (slur.type == 'start') {
        // Determine if stem is up or down
        final middleLineY = staffStartY + (staffSpacing * 2);
        final stemUp = y >= middleLineY;
        
        // Store the starting position for this slur
        if (stemUp) {
          // For up-stem notes, start from bottom right
          note.slurStartX = x + noteSize/3;
          note.slurStartY = y + noteSize/3;
        } else {
          // For down-stem notes, start from top right
          note.slurStartX = x + noteSize/3;
          note.slurStartY = y - noteSize/3;
        }
      } else if (slur.type == 'stop') {
        final startX = note.slurStartX ?? x - measureWidth/2;
        final startY = note.slurStartY ?? y;
        
        // Determine if current note's stem is up or down
        final middleLineY = staffStartY + (staffSpacing * 2);
        final stemUp = y >= middleLineY;
        
        // Calculate end position based on stem direction
        final endX = x - noteSize/3;
        final endY = stemUp ? y + noteSize/3 : y - noteSize/3;
        
        final path = Path();
        final dx = endX - startX;
        final dy = endY - startY;
        
        // Adjust curve height based on distance and direction
        final curveHeight = (dx / 80.0).clamp(20.0, 40.0);
        final direction = stemUp ? 1 : -1;
        
        // Start the slur curve
        path.moveTo(startX, startY);
        
        // Create a smooth curve using cubic Bezier
        path.cubicTo(
          startX + dx/3,     // First control point X
          startY - curveHeight * direction,  // First control point Y
          startX + dx*2/3,   // Second control point X
          startY - curveHeight * direction,  // Second control point Y
          endX,              // End point X
          endY               // End point Y
        );
        
        // Draw the slur with a refined stroke
        final slurPaint = Paint()
          ..color = Colors.black
          ..strokeWidth = 1.8
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        
        canvas.drawPath(path, slurPaint);
      }
    }
  }

  void _drawLedgerLines(Canvas canvas, double x, double y, double startY, Paint paint) {
    final staffTop = startY;
    final staffBottom = startY + (staffSpacing * 4);
    paint.strokeWidth = lineWidth;
    
    // Draw ledger lines above staff
    if (y < staffTop - staffSpacing/4) {
      var currentY = staffTop;
      while (currentY > y - staffSpacing/4) {
        currentY -= staffSpacing;
        _drawLedgerLine(canvas, x, currentY, paint);
      }
    }
    
    // Draw ledger lines below staff
    if (y > staffBottom + staffSpacing/4) {
      var currentY = staffBottom;
      while (currentY < y + staffSpacing/4) {
        currentY += staffSpacing;
        _drawLedgerLine(canvas, x, currentY, paint);
      }
    }

    // Special case for middle C
    if (y >= staffBottom + staffSpacing * 0.75 && y <= staffBottom + staffSpacing * 1.25) {
      _drawLedgerLine(canvas, x, staffBottom + staffSpacing, paint);
    }
  }

  void _drawLedgerLine(Canvas canvas, double x, double y, Paint paint) {
    canvas.drawLine(
      Offset(x - ledgerLineLength/2, y),
      Offset(x + ledgerLineLength/2, y),
      paint,
    );
  }

  double _getNoteY(Note note, double startY) {
    // Standard music notation positioning following the staff pattern:
    // Each line and space represents a specific note, moving up the scale
    // Lines from bottom to top: E4, G4, B4, D5, F5
    // Spaces from bottom to top: F4, A4, C5, E5
    final stepOrder = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
    
    // Position of middle C (C4) - one ledger line below the staff
    final middleC = startY + (staffSpacing * 5);
    
    // Calculate steps from middle C
    int stepsFromMiddleC = 0;
    
    // Calculate octave difference
    int octaveDiff = note.octave - 4; // relative to C4
    stepsFromMiddleC += octaveDiff * 7; // 7 steps per octave
    
    // Add steps within the octave
    int currentStepIndex = stepOrder.indexOf(note.step);
    int middleCIndex = stepOrder.indexOf('C');
    stepsFromMiddleC += currentStepIndex - middleCIndex;
    
    // Each step is half a staff space
    // Moving up the staff means subtracting from the Y coordinate
    return middleC - (stepsFromMiddleC * staffSpacing / 2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 