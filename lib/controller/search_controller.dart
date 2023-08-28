import 'dart:developer';
import 'dart:io';

import 'package:android_path_provider/android_path_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music_stream/model/search_model.dart';
import 'package:music_stream/utils/constants/api.dart';
import 'package:music_stream/view/now_playing/nowplaying_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path/path.dart' as path;

final downloadProgressProvider =
    StateNotifierProvider<DownloadProgressController, int>((ref) {
  return DownloadProgressController();
});

class DownloadProgressController extends StateNotifier<int> {
  DownloadProgressController() : super(0);

  void updateProgress(int progress) {
    state = progress;
  }
}

final searchProvider = ChangeNotifierProvider<SearchController>((ref) {
  return SearchController();
});

class SearchController with ChangeNotifier {
  // <============================= VARIABLES ===========================================>
  var searchController = TextEditingController();
  var yt = YoutubeExplode();
  final player = AudioPlayer();
  List<SearchModel> searchModelList = [];
  var isLoading = false;
  var duration = const Duration();
  var position = const Duration();
  final playlist = ConcatenatingAudioSource(
    // Start loading next item just before reaching it
    useLazyPreparation: true,
    // Customise the shuffle algorithm
    shuffleOrder: DefaultShuffleOrder(),
    // Specify the playlist items
    children: [],
  );
  var index = -1;
  var title = "title";
  var subTitle = "subTitle";
  var audioUrl = "";
  var isDownloadStarted = false;
  // <================================VOLUME CONTROL =======================================>
  var minVolume = 0.0;
  var maxVolume = 1.0;
  var currentVolume = 0.5;
  // <================================= METHODS =========================================>

  // <================================= METHOD FOR SEARCH ===============================>
  Future<List<SearchModel>> getSearch(String query) async {
    if (searchModelList.isNotEmpty) {
      searchModelList = [];
      notifyListeners();
    }
    isLoading = true;
    notifyListeners();
    SearchModel searchModel =
        SearchModel(videoId: "", title: "", thumbnails: "", artists: "");
    final response = await Dio().get("${KApi.baseUrl}/search?query=$query");
    if (response.statusCode == 200) {
      // log(response.data["songs"].toString());

      // for (var data in response.data["songs"]) {
      //   log(data.toString());
      // }
      List searchList = response.data["songs"];
      for (int i = 0; i < searchList.length; i++) {
        searchModel = SearchModel.fromJson(response.data, i);
        searchModelList.add(searchModel);
        // log(searchModel.toString());
      }
      // searchModel = SearchModel.fromJson(response.data);

      // <============== FOR PLAYING AUDIO FROM API =======================>
      // var audioUrl = "";
      // final StreamManifest manifest =
      //     await yt.videos.streamsClient.getManifest(searchModel.videoId);
      // audioUrl = manifest.audioOnly.withHighestBitrate().url.toString();
      // final player = AudioPlayer();
      // await player.setUrl(audioUrl);
      // player.play();
      // log(searchModel.toString());
    }
    log(searchModelList.toString());
    isLoading = false;
    notifyListeners();
    searchController.clear();
    return searchModelList;
  }

  // <========================================== METHOD FOR NAVIGATING TO NOW PLAYING SCREEN ===============================================>
  // void goNowPlay(BuildContext context,
  //     {required String url, required String title, required int index}) async {
  //   if (player.playing) {
  //     await player.pause();
  //   }
  //   var audioUrl = "";
  //   final StreamManifest manifest = await yt.videos.streamsClient
  //       .getManifest(searchModelList.elementAt(index).videoId);
  //   audioUrl = manifest.audioOnly.withHighestBitrate().url.toString();

  //   await player.setUrl(audioUrl);

  //   // for (var data in searchModelList) {
  //   //   await playlist.add(
  //   //     AudioSource.uri(
  //   //       await exractAudioUrl(
  //   //         videoId: data.videoId,
  //   //       ),
  //   //     ),
  //   //   );
  //   // }

  //   // await player.setAudioSource(
  //   //   playlist,
  //   //   initialIndex: 0,
  //   //   initialPosition: Duration.zero,
  //   // );
  //   player.play();
  //   mockDuration();
  //   if (context.mounted) {
  //     Navigator.push(
  //       context,
  //       CupertinoPageRoute(
  //         builder: (context) {
  //           return NowPlayingScreen(
  //             url: url,
  //             title: title,
  //           );
  //         },
  //       ),
  //     );
  //   }
  // }

  // <================================= METHOD FOR PLAY AND PAUSE MUSIC =======================================>
  Future<void> playOrPause() async {
    if (player.playing) {
      await player.pause();
      notifyListeners();
    } else if (!player.playing) {
      notifyListeners();
      await player.play();
    }
  }

  // <================================= METHOD TO EXRACT AUDIO URL =========================================>
  Future<Uri> exractAudioUrl({required String videoId}) async {
    var audioUrl = "";
    try {
      final StreamManifest manifest =
          await yt.videos.streamsClient.getManifest(videoId);
      audioUrl = manifest.audioOnly.withHighestBitrate().url.toString();
      return Uri.parse(audioUrl);
    } catch (e) {
      log(e.toString());
      return Uri();
    }
  }

  // <==================================== MOCK SLIDER ====================================>
  void mockDuration() {
    player.durationStream.listen((dura) {
      duration = dura!;
      notifyListeners();
    });
    player.positionStream.listen((pos) {
      position = pos;
      notifyListeners();
    });
  }

  onChanged(double value) {
    position = Duration(seconds: value.toInt());
    player.seek(position);
    notifyListeners();
  }

  // <================================ METHOD FOR FAST FORWARD ===============================>
  fastForward() {
    var sec10 = const Duration(seconds: 10);
    if (position + sec10 > duration) {
      position = duration;

      player.seek(position);
      notifyListeners();
      return;
    }
    position += sec10;
    player.seek(position);
    notifyListeners();
  }

  // <============================ METHOD FOR FAST BACKWARD ====================================>
  fastBackward() {
    var sec10 = const Duration(seconds: 10);
    if (position < sec10) {
      position = Duration.zero;
      player.seek(position);
      notifyListeners();
      return;
    }
    position -= sec10;
    player.seek(position);
    notifyListeners();
  }

  // <========================== METHOD FOR CARD TAP ==============================================>
  Future<void> searchCardTap({required int selectedIndex}) async {
    if (player.playing) {
      await player.pause();
    }

    final StreamManifest manifest = await yt.videos.streamsClient
        .getManifest(searchModelList.elementAt(selectedIndex).videoId);
    audioUrl = manifest.audioOnly.withHighestBitrate().url.toString();

    await player.setUrl(audioUrl);
    player.play();
    mockDuration();
    index = selectedIndex;
    title = searchModelList.elementAt(index).title;
    subTitle = searchModelList.elementAt(index).artists;
    notifyListeners();
  }

  // <================================ METHOD FOR LISTTILE TAP =====================================>
  Future<void> listTileTap({required BuildContext context}) async {
    if (index != -1) {
      await showModalBottomSheet(
        // backgroundColor: Colors.red,
        context: context,
        isScrollControlled: true,
        builder: (context) {
          return NowPlayingScreen(
            url: searchModelList.elementAt(index).thumbnails,
            title: title,
            artist: subTitle,
            videoId: searchModelList.elementAt(index).videoId,
          );
        },
      );
    }
  }

  // <=================================METHOD FOR VOLUME CONTROL ======================================>
  Future<void> controlVolume(double volume) async {
    currentVolume = volume;
    await player.setVolume(currentVolume);
    notifyListeners();
  }

  // <====================================== METHOD FOR DOWNLOADING SONGS ===============================>
  Future<void> downloadSongs(
      {required String videoId, required WidgetRef ref}) async {
    try {
      isDownloadStarted = true;
      notifyListeners();
      var status = await Permission.storage.status;
      log(status.toString());
      if (!status.isGranted) {
        await Permission.storage.request();
      }

      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      final audio = manifest.audioOnly.withHighestBitrate();
      final audioStream = yt.videos.streamsClient.get(audio);
      final dir = await AndroidPathProvider.downloadsPath;
      final filePath = path.join(
        dir,
        '$videoId.mp3',
      );
      final file = File(filePath);
      // Delete The File If Exists
      if (file.existsSync()) {
        file.deleteSync();
      }
      // Open the file in writeAppened.
      final output = file.openWrite(mode: FileMode.writeOnlyAppend);

// Track the file download status.
      final len = audio.size.totalBytes;
      var count = 0.0;
      // Listen for data received.
      await for (final data in audioStream) {
        count += data.length;
        final progress = ((count / len) * 100).ceil();
        ref.watch(downloadProgressProvider.notifier).updateProgress(progress);
        output.add(data);
      }
      await output.flush();
      await output.close();
      Fluttertoast.showToast(
          msg: 'Download completed and saved to: $filePath',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.white,
          textColor: Colors.black,
          fontSize: 16.0);
      isDownloadStarted = false;
      notifyListeners();
    } catch (e) {
      log(e.toString());
      isDownloadStarted = false;
      notifyListeners();
    }
  }
}
