import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_app/models/post_media.dart';
import 'package:social_app/widgets/post_body.dart';
import 'package:social_app/widgets/message_composer.dart';
import 'package:social_app/screens/widgets/profile_tabs.dart';

void main() {
  test('legacy posts and multi-media posts remain compatible without duplicate covers', () {
    final old = PostMedia.fromPost({'image_url': 'https://example.com/old.jpg'});
    expect(old.single.kind, 'image');
    final multiple = PostMedia.fromPost({'image_url':'https://example.com/one.jpg', 'media':[
      {'kind':'image','url':'https://example.com/one.jpg'}, {'kind':'video','url':'https://example.com/movie.mp4'},
    ]});
    expect(multiple.length, 2);
    expect(multiple.last.isVideo, isTrue);
    expect(PostMedia.parse({'kind':'script','url':'anything'}), isNull);
    expect(PostMedia.fromPost({'media':[], 'video_url':'https://example.com/legacy.mp4'}).single.isVideo,isTrue);
  });
  test('private attachment round trip preserves object path', () {
    const media = PostMedia(kind:'image', storagePath:'conversation/user/file.jpg');
    final parsed = PostMedia.parse(media.toJson())!;
    expect(parsed.storagePath, media.storagePath);
    expect(parsed.url, isEmpty);
  });
  testWidgets('long post opens full detail from collapsed text', (tester) async {
    var opened = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 250, child: PostBody(
      post: {'content': List.filled(40, 'Nội dung bài viết dài').join(' ')}, onOpen: () => opened = true)))));
    expect(find.text('Xem đầy đủ'), findsOneWidget);
    await tester.tap(find.text('Xem đầy đủ'));
    expect(opened, isTrue);
  });
  testWidgets('failed send keeps draft and blocks duplicate submission while pending', (tester) async {
    final pending = Completer<void>(); var sends = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MessageComposer(onSend: (text, file, video) {
      sends++; return pending.future;
    }))));
    await tester.enterText(find.byType(TextField), 'Tin nhắn cần giữ lại');
    await tester.tap(find.byTooltip('Gửi')); await tester.pump();
    await tester.tap(find.byTooltip('Gửi')); expect(sends,1);
    pending.completeError(Exception('Mất mạng')); await tester.pumpAndSettle();
    expect(find.text('Tin nhắn cần giữ lại'), findsOneWidget);
  });
  testWidgets('profile tabs scroll to friends without overflow on small screen', (tester) async {
    tester.view.physicalSize = const Size(320,640); tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    var selected=-1;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Align(alignment: Alignment.topCenter,
      child: SizedBox(height: 70, child: ProfileTabs(selectedIndex: 0, onTabChanged:(i)=>selected=i, postCount:15,photoCount:20,videoCount:3))))));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Bạn bè'), 200, scrollable: find.byType(Scrollable));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bạn bè')); expect(selected,4); expect(tester.takeException(),isNull);
  });
}
