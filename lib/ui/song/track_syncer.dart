import 'package:flutter/material.dart';
import 'package:mudeo/data/models/song_model.dart';
import 'package:mudeo/utils/localization.dart';

class TrackSyncer extends StatefulWidget {
  const TrackSyncer({
    @required this.song,
    @required this.onDelayChanged,
  });

  final SongEntity song;
  final Function(TrackEntity, int) onDelayChanged;

  @override
  _TrackSyncerState createState() => _TrackSyncerState();
}

class _TrackSyncerState extends State<TrackSyncer> {
  int _timeSpan = 1000 * 10;
  int _timeStart = 0;
  bool _isSyncing = false;

  SongEntity _song;

  @override
  void initState() {
    super.initState();
    _song = widget.song;
  }

  void _syncVideos() {
    if (_song.tracks.length < 2) {
      return;
    }

    setState(() {
      _isSyncing = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final firstVideo = _song.tracks.first.video;
        final volumeMap = firstVideo.volumeMap;

        for (int i = 1; i <= _song.tracks.length - 1; i++) {
          final track = _song.tracks[i];
          final compareVideo = track.video;
          final compareMap = compareVideo.volumeMap;
          print('Comparing video $i to first video - delay: ${track.delay}');

          double minDiff = 999999999;
          int minDiffDelay = 0;

          for (int j = -1000; j <= 1000; j++) {
            double totalDiff = 0;

            for (int k = 1000; k <= 9000; k++) {
              final oldVolume = volumeMap[k];
              final newVolume = compareMap[k + j];
              final diff = oldVolume > newVolume
                  ? oldVolume - newVolume
                  : newVolume - oldVolume;

              totalDiff += diff;
            }

            if (totalDiff < minDiff) {
              minDiff = totalDiff;
              minDiffDelay = j;
            }
          }

          final delay = minDiffDelay * -1;
          print('Set delay to: $delay');
          widget.onDelayChanged(track, delay);
          setState(() {
            _song = _song.setTrackDelay(track, delay);
          });
        }

        setState(() {
          _isSyncing = false;
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalization.of(context);

    return AlertDialog(
      title: Text(AppLocalization.of(context).trackAdjustment),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ..._song.tracks
              .map((track) => TrackVolume(
                    track: track,
                    timeSpan: _timeSpan,
                  ))
              .toList(),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              Expanded(
                child: RaisedButton(
                  color: Colors.grey,
                  child: Text(localization.sync.toUpperCase()),
                  onPressed: _isSyncing ? null : () => _syncVideos(),
                ),
              ),
              SizedBox(width: 20),
              Expanded(
                child: RaisedButton(
                  child: Text(localization.done.toUpperCase()),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TrackVolume extends StatelessWidget {
  const TrackVolume({this.track, this.timeSpan});

  final TrackEntity track;
  final int timeSpan;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        height: 1400,
        width: timeSpan.toDouble(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 100),
          child: Container(
            color: Colors.black38,
            child: CustomPaint(
              painter: VolumePainter(
                track: track,
                timeSpan: timeSpan,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class VolumePainter extends CustomPainter {
  const VolumePainter({this.track, this.timeSpan});

  final TrackEntity track;
  final int timeSpan;

  @override
  void paint(Canvas canvas, Size size) {
    final video = track.video;
    var paint = Paint();
    paint.color = Colors.white;
    paint.style = PaintingStyle.fill;

    if (video == null || video.volumeData == null) {
      print('## SKIPPING');
      return;
    }

    final volumeData = video.volumeData;

    double volume = 0;

    for (int i = 0; i <= timeSpan; i++) {
      var time = (i - track.delay).toString();

      if (volumeData.containsKey(time)) {
        volume = volumeData[time];
      }

      if (volume > 120) {
        volume = 120;
      } else if (volume < 20) {
        volume = 20;
      }

      if (i % 10 == 0) {
        final height = 1200.0;
        final rect = Rect.fromLTRB(i.toDouble(), height, i.toDouble() + 7,
            height - ((volume - 20) * 10));
        canvas.drawRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
