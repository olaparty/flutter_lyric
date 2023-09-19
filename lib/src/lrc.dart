// @dart=2.12

///The parsed LRC class. You can instantiate this class directly
///or parse a string using `Lrc.parse()`.
class Lrc {
  ///the overall type of LRC for this object
  LrcTypes type;

  ///the name of the artist of the song (optional)  [ar]
  String? artist;

  ///the name of the album of the song (optional) [al]
  String? album;

  ///the title of the song (optional) [ti]
  String? title;

  ///the name of the author of the lyrics (optional) [au]
  String? author;

  ///the name of the creator of the LRC file (optional) [by]
  String? creator;

  ///the name of the program that created the LRC file (optional) [re]
  String? program;

  ///the version of the program that created the LRC file (optional) [ve]
  String? version;

  ///the length of the song (optional) [length]
  String? length;

  ///the language of the song, using IETF BCP 47 language tag (optional) [la]
  String? language;

  ///offset of time in milliseconds, can be positive [shifts time up]
  ///or negative [shifts time down] (optional) [offset]
  int? offset;

  ///the list of lyric lines
  List<LrcLine> lyrics;

  ///Handy parameter to get a stream of the lyrics.
  ///See `List<LrcLine>.toStream()`.
  Stream<LrcStream> get stream => lyrics.toStream();

  Lrc({
    this.type = LrcTypes.simple,
    required this.lyrics,
    this.artist,
    this.album,
    this.title,
    this.creator,
    this.author,
    this.program,
    this.version,
    this.length,
    this.offset,
    this.language,
  });

  ///Format the lrc to a readable string that can then be
  ///outputted to an LRC file.
  String format() {
    var output = '';

    output += (artist != null) ? '[ar:$artist]\n' : '';
    output += (album != null) ? '[al:$album]\n' : '';
    output += (title != null) ? '[ti:$title]\n' : '';
    output += (length != null) ? '[length:$length]\n' : '';
    output += (creator != null) ? '[by:$creator]\n' : '';
    output += (author != null) ? '[au:$author]\n' : '';
    output += (offset != null) ? '[offset:${offset.toString()}]\n' : '';
    output += (program != null) ? '[re:$program]\n' : '';
    output += (version != null) ? '[ve:$version]\n' : '';
    output += (language != null) ? '[la:$language]\n' : '';

    for (var lyric in lyrics) {
      output += lyric.lyricsString + '\n';
    }

    return output;
  }

  ///Parses an LRC from a string. Throws a `FormatExeption`
  ///if the inputted string is not valid.
  static Lrc parse(String parsed) {
    parsed = parsed.trim();

    if (!isValid(parsed)) {
      throw FormatException('The inputted string is not a valid LRC file');
    }

    //split string into lines, code from Linesplitter().convert(data)
    var lines = ((data) {
      var lines = <String>[];
      var end = data.length;
      var sliceStart = 0;
      var char = 0;
      for (var i = 0; i < end; i++) {
        var previousChar = char;
        char = data.codeUnitAt(i);
        if (char != 13) {
          if (char != 10) continue;
          if (previousChar == 13) {
            sliceStart = i + 1;
            continue;
          }
        }
        lines.add(data.substring(sliceStart, i));
        sliceStart = i + 1;
      }
      if (sliceStart < end) lines.add(data.substring(sliceStart, end));
      return lines;
    })(parsed);

    //temporary storer variables
    String? artist,
        album,
        title,
        length,
        author,
        creator,
        offset,
        program,
        version,
        language;
    LrcTypes? type;
    var lyrics = <LrcLine>[];

    String? setIfMatchTag(String toMatch, String tag) =>
        (RegExp(r'^\[' + tag + r':.*\]$').hasMatch(toMatch))
            ? toMatch.substring(tag.length + 2, toMatch.length - 1).trim()
            : null;

    //loop thru each lines
    for (var i in lines) {
      artist = artist ?? setIfMatchTag(i, 'ar');
      album = album ?? setIfMatchTag(i, 'al');
      title = title ?? setIfMatchTag(i, 'ti');
      author = author ?? setIfMatchTag(i, 'au');
      length = length ?? setIfMatchTag(i, 'length');
      creator = creator ?? setIfMatchTag(i, 'by');
      offset = offset ?? setIfMatchTag(i, 'offset');
      program = program ?? setIfMatchTag(i, 're');
      version = version ?? setIfMatchTag(i, 've');
      language = language ?? setIfMatchTag(i, 'la');

      if (RegExp(r'^\[\d\d:\d\d\.\d\d\].*$').hasMatch(i)) {
        var lyric = i.substring(10).trim();
        var lineType = LrcTypes.simple;
        Map<String, Object>? args;
        List<Word>? words;
        //checkers for different types of LRCs
        if (lyric.contains(RegExp(r'^\w:'))) {
          //if extended
          type = (type == LrcTypes.enhanced)
              ? LrcTypes.extended_enhanced
              : LrcTypes.extended;
          args = {
            'letter': lyric[0], //get the letter of the type of person
            'lyrics': lyric.substring(2) //get the rest of the lyrics
          };
          lineType = LrcTypes.extended;
        } else if (lyric.contains(RegExp(r'<\d\d:\d\d\.\d\d>'))) {
          //if enhanced
          type = (type == LrcTypes.extended)
              ? LrcTypes.extended_enhanced
              : LrcTypes.enhanced;
          args = {};
          words = [];
          lineType = LrcTypes.enhanced;
          //for each timestamp in the line, regex has capturing
          //groups to make this easier
          var iterable =
          RegExp(r'<((\d\d):(\d\d)\.(\d\d))>([^<]*)').allMatches(lyric);
          var len = iterable.length;
          var index = 0;
          for (var j in iterable) {
            var start = Duration(
              minutes: int.parse(j.group(2)!),
              seconds: int.parse(j.group(3)!),
              milliseconds: int.parse(j.group(4)!),
            );

            // for (var i = 0; i < j.groupCount; i++) {
            //   print(' g$i=${j.group(i)}');
            // }
            var isLast = index == len - 1;
            var word = Word(start, j.group(5)!.trim())..isLast = isLast;
            words.add(word);

            //puts each timestamp+lyrics in the args, no duplicates
            args.putIfAbsent(
                j.group(1)!, //the key is the <mm:ss.xx>
                    () => <String, Object>{
                  //the value is another map with the duration and lyrics
                  'duration': start,
                  'lyrics': j.group(5)!.trim()
                });

            index++;
          }
        }
        if (words != null) {
          for (var i = 0; i < words.length - 1; i++) {
            words[i].end = words[i + 1].start;
          }
          // words.removeWhere((element) => element.text.trim().isEmpty);
        }

        lyrics.add(LrcLine(
            starTime: Duration(
              minutes: int.parse(i.substring(1, 3)),
              seconds: int.parse(i.substring(4, 6)),
              milliseconds: int.parse(i.substring(7, 9)),
            ),
            rawLyrics: lyric,
            type: lineType,
            words: words,
            args: args));
      }
    }

    return Lrc(
        type: type ?? LrcTypes.simple,
        artist: artist,
        album: album,
        title: title,
        author: author,
        length: length,
        creator: creator,
        offset: (offset != null) ? int.tryParse(offset) : null,
        program: program,
        version: version,
        lyrics: lyrics,
        language: language);
  }

  ///Checks if the string input is a valid LRC using Regex.
  static bool isValid(String input) => RegExp(
      r'^([\r\n]*\[((ti)|(a[rlu])|(by)|([rv]e)|(length)|(offset)|(la)):.+\][\r\n]*)*([\r\n]*\[\d\d:\d\d\.\d\d\].*){2,}[\r\n]*$')
      .hasMatch(input.trim());

  @override
  String toString() {
    var lyrics = this.lyrics.join('\n');

    return '''
    Type: '$type'
    Artist: '$artist'
    Album: '$album'
    Title: '$title'
    Author: '$author'
    Creator: '$creator'
    Program: '$program'
    Length: '$length'
    Language: '$language'
    Offset: '$offset'
    Lyrics: '$lyrics'
    ''';
  }
}

///The types of LRC
enum LrcTypes {
  ///A simple LRC, with no extra formatting, etc
  simple,

  ///LRC with modifiers at the start in the form `A: foo`
  extended,

  ///LRC with additional timestamps per line in the form `<00:00.00> foo`
  enhanced,

  ///LRC that some lines are extended and some are enhanced
  extended_enhanced
}

///A line of lyrics, with its defined duration and raw lyrics
class LrcLine {
  ///timestamp for the lyrics wherein it'll be displayed
  Duration starTime;
  Duration? endTime;

  ///the raw lyrics for the line
  String rawLyrics;

  ///the additional arguments for other lrc types
  Map<String, Object>? args;

  ///the type of lrc for this line
  LrcTypes type;

  List<Word>? words;

  LrcLine({
    required this.starTime,
    required this.rawLyrics,
    required this.type,
    this.args,
    this.endTime,
    this.words,
  });

  ///get the string for a formatted line
  String get formattedLine {
    ///function to add leading zeros
    String f(int x) => x.toString().padLeft(2, '0');

    var minutes = starTime.inMinutes,
        seconds = starTime.inSeconds - (minutes * 60),
        milliseconds =
            starTime.inMilliseconds - ((minutes * 60000) + (seconds * 1000));

    return '[${f(minutes)}:${f(seconds)}:${f(milliseconds)}]$rawLyrics';
  }

  String get formattedWord {
    ///function to add leading zeros
    String f(int x) => x.toString().padLeft(2, '0');

    var minutes = starTime.inMinutes,
        seconds = starTime.inSeconds - (minutes * 60),
        milliseconds =
            starTime.inMilliseconds - ((minutes * 60000) + (seconds * 1000));

    var sb = StringBuffer();
    words?.forEach((e) => sb.write(e.formattedLine));

    return '[${f(minutes)}:${f(seconds)}:${f(milliseconds)}]$sb';
  }

  String get lyricsString {
    if (words != null) {
      var sb = StringBuffer();
      words?.forEach((e) => sb.write(e.text));
      return sb.toString();
    }
    return rawLyrics;
  }

  @override
  String toString() {
    return '''
      Timestamp: '$starTime'
      Lyrics: '$rawLyrics'
      Args: '$args'
    ''';
  }
}

class Word {
  Duration start;
  Duration? end;
  String text;
  bool isLast = false;

  Word(this.start, this.text);

  ///get the string for a formatted line
  String get formattedLine {
    ///function to add leading zeros
    String f(int x) => x.toString().padLeft(2, '0');

    var minutes = start.inMinutes,
        seconds = start.inSeconds - (minutes * 60),
        milliseconds =
            start.inMilliseconds - ((minutes * 60000) + (seconds * 1000));

    return '<${f(minutes)}:${f(seconds)}:${f(milliseconds)}>$text';
  }
}

///A data class to store each yielding of the stream
class LrcStream {
  ///The previous line. Is null if the current line is the fist position.
  LrcLine? previous;

  ///the current line
  LrcLine current;

  ///The next line. Is null if the current line is the last position.
  LrcLine? next;

  ///the duration from the current to the next. Is null if the current line is the last position.
  Duration? duration;

  ///the position of the current line
  int position;

  ///The total number of lines in the stream
  int length;

  ///The main constructor for a LrcStream
  LrcStream(
      {this.previous,
        required this.current,
        this.next,
        this.duration,
        required this.position,
        required this.length})
  //position should be greater than or equal to 0
      : assert(position >= 0),
  //the length should be greater than or equal to the position
        assert(length >= position),
  //previous is null only if position is 0
        assert((previous == null) ? position == 0 : true),
  //next is null only if position is the last
        assert((next == null) ? position == length : true);
}

///Handy extensions on lists of LrcLine
extension LrcLineExtensions on List<LrcLine> {
  ///Creates a stream for each lyric using their durations
  Stream<LrcStream> toStream() async* {
    for (var i = 0; i < length; i++) {
      var lineCurrent = this[i];
      var lineNext = (i + 1 < length) ? this[i + 1] : null;
      var durationToNext = (lineNext != null)
          ? Duration(
          milliseconds: lineNext.starTime.inMilliseconds -
              lineCurrent.starTime.inMilliseconds)
          : null;
      yield LrcStream(
          duration: durationToNext,
          previous: (i != 0) ? this[i - 1] : null,
          current: lineCurrent,
          next: lineNext,
          position: i,
          length: length - 1);
      if (durationToNext != null) {
        await Future.delayed(durationToNext);
      }
    }
  }
}

///Handy extensions on strings
extension StringExtensions on String {
  ///Handy extension method that parses them to LRCs
  Lrc toLrc() => Lrc.parse(this);

  ///Handy extension getter if the given string is a valid LRC
  bool get isValidLrc => Lrc.isValid(this);
}
