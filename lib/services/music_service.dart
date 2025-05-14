import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:xml/xml.dart';

class Note {
  final String step;
  final int octave;
  final double duration;
  final bool isRest;
  final String type; // quarter, half, whole, etc.
  final bool hasStem;
  final String stemDirection; // up or down
  final List<Slur> slurs;
  final bool hasDot;
  final int? alter; // for sharps and flats
  
  // Properties to store slur positions
  double? slurStartX;
  double? slurStartY;
  double? slurEndX;
  double? slurEndY;

  Note({
    required this.step,
    required this.octave,
    required this.duration,
    this.isRest = false,
    this.type = 'quarter',
    this.hasStem = true,
    this.stemDirection = 'up',
    this.slurs = const [],
    this.hasDot = false,
    this.alter,
    this.slurStartX,
    this.slurStartY,
    this.slurEndX,
    this.slurEndY,
  });

  factory Note.fromXmlElement(XmlElement noteElem) {
    final isRest = noteElem.getElement('rest') != null;
    final duration = double.tryParse(noteElem.getElement('duration')?.text ?? '1') ?? 1.0;
    final type = noteElem.getElement('type')?.text ?? 'quarter';
    final stem = noteElem.getElement('stem');
    final hasStem = stem != null;
    final stemDirection = stem?.text ?? 'up';
    final hasDot = noteElem.getElement('dot') != null;
    
    // Parse slurs
    final slurs = <Slur>[];
    final notations = noteElem.getElement('notations');
    if (notations != null) {
      for (final slur in notations.findElements('slur')) {
        slurs.add(Slur(
          type: slur.getAttribute('type') ?? 'start',
          number: int.tryParse(slur.getAttribute('number') ?? '1') ?? 1,
        ));
      }
    }

    if (isRest) {
      return Note(
        step: '',
        octave: 0,
        duration: duration,
        isRest: true,
        type: type,
        hasStem: false,
        stemDirection: 'up',
        slurs: slurs,
        hasDot: hasDot,
      );
    }

    final pitchElem = noteElem.getElement('pitch');
    final step = pitchElem?.getElement('step')?.text ?? '';
    final octave = int.tryParse(pitchElem?.getElement('octave')?.text ?? '4') ?? 4;
    final alter = int.tryParse(pitchElem?.getElement('alter')?.text ?? '');

    return Note(
      step: step,
      octave: octave,
      duration: duration,
      type: type,
      hasStem: hasStem,
      stemDirection: stemDirection,
      slurs: slurs,
      hasDot: hasDot,
      alter: alter,
    );
  }
}

class Slur {
  final String type; // start or stop
  final int number;

  Slur({
    required this.type,
    required this.number,
  });
}

class Measure {
  final List<Note> notes;

  Measure({required this.notes});

  factory Measure.fromXmlElement(XmlElement measureElem) {
    final notes = <Note>[];
    for (final noteElem in measureElem.findElements('note')) {
      notes.add(Note.fromXmlElement(noteElem));
    }
    return Measure(notes: notes);
  }
}

class Score {
  final List<Measure> measures;
  final int beats;
  final int beatType;

  Score({
    required this.measures,
    required this.beats,
    required this.beatType,
  });

  factory Score.fromXML(String xmlString) {
    final xml = XmlDocument.parse(xmlString);
    final measures = <Measure>[];
    int beats = 4;
    int beatType = 4;

    // Find time signature (first occurrence)
    final timeElement = xml.findAllElements('time').firstOrNull;
    if (timeElement != null) {
      beats = int.tryParse(timeElement.getElement('beats')?.text ?? '4') ?? 4;
      beatType = int.tryParse(timeElement.getElement('beat-type')?.text ?? '4') ?? 4;
    }

    // Parse measures
    for (final measureElem in xml.findAllElements('measure')) {
      measures.add(Measure.fromXmlElement(measureElem));
    }

    return Score(
      measures: measures,
      beats: beats,
      beatType: beatType,
    );
  }
}

class MusicService {
  static Future<Score> loadMusicXML(String level) async {
    try {
      // Load the MusicXML file from assets
      final String xmlString = await rootBundle.loadString('assets/$level.musicxml');
      // Parse the MusicXML string into a Score object
      final Score score = Score.fromXML(xmlString);
      return score;
    } catch (e) {
      print('Error loading MusicXML file: $e');
      rethrow;
    }
  }

  static List<String> getAvailableLevels() {
    return ['lvl1', 'lvl2', 'lvl3'];
  }

  static String getLevelTitle(String level) {
    switch (level) {
      case 'lvl1':
        return 'Basic Scale';
      case 'lvl2':
        return 'Intermediate Melody';
      case 'lvl3':
        return 'Advanced Exercise';
      default:
        return 'Unknown Level';
    }
  }
} 