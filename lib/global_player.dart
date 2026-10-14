import 'dart:io';
import 'package:media_kit/media_kit.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';

class GlobalPlayer {
  static final Player player = Player(configuration: const PlayerConfiguration());
  static MediaKitAudioHandler? audioHandler;

  static Future<void> init() async {
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            flags: AndroidAudioFlags.none,
            usage: AndroidAudioUsage.media,
          ),
        ));

        audioHandler = await AudioService.init(
          builder: () => MediaKitAudioHandler(),
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'com.stylora.media_player_app.channel.audio',
            androidNotificationChannelName: 'Media Playback',
            androidNotificationOngoing: true,
          ),
        );
      } catch (e) {
        // Fallback for non-mobile platforms
      }
    }
  }
}

class MediaKitAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  MediaKitAudioHandler() {
    GlobalPlayer.player.stream.playing.listen((playing) {
      playbackState.add(playbackState.value.copyWith(
        playing: playing,
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        processingState: playing ? AudioProcessingState.ready : AudioProcessingState.idle,
      ));
    });

    GlobalPlayer.player.stream.position.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
      ));
    });
    
    GlobalPlayer.player.stream.playlist.listen((playlist) {
      if (playlist.medias.isNotEmpty && playlist.index >= 0 && playlist.index < playlist.medias.length) {
        final media = playlist.medias[playlist.index];
        final filename = media.uri.split('/').last;
        final titleWithoutExt = filename.contains('.') ? filename.substring(0, filename.lastIndexOf('.')) : filename;
        mediaItem.add(MediaItem(
          id: media.uri,
          album: 'Zenora Player',
          title: titleWithoutExt,
          artUri: Uri.parse('asset:///assets/icon.png'),
        ));
      }
    });
  }

  @override
  Future<void> play() => GlobalPlayer.player.play();

  @override
  Future<void> pause() => GlobalPlayer.player.pause();

  @override
  Future<void> seek(Duration position) => GlobalPlayer.player.seek(position);

  @override
  Future<void> stop() async {
    await GlobalPlayer.player.stop();
    return super.stop();
  }

  @override
  Future<void> skipToNext() => GlobalPlayer.player.next();

  @override
  Future<void> skipToPrevious() => GlobalPlayer.player.previous();
}
