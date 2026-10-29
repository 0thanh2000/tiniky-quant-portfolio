import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
class CallScreen extends StatefulWidget {
  static bool active = false;
  final String conversationId, otherId, name;
  final bool video;
  final Map<String, dynamic>? incoming;
  const CallScreen({super.key, required this.conversationId, required this.otherId,
    required this.name, required this.video, this.incoming});
  static Future<void> openOutgoing(BuildContext context, {required String conversationId,
    required String otherId, required String name, required bool video}) async {
    if (active) return;
    active = true;
    try { await Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(
      conversationId: conversationId, otherId: otherId, name: name, video: video))); }
    finally { active = false; }
  }
  @override State<CallScreen> createState() => _CallScreenState();
}
class _CallScreenState extends State<CallScreen> with WidgetsBindingObserver {
  final _db = Supabase.instance.client;
  final _local = RTCVideoRenderer(), _remote = RTCVideoRenderer();
  RTCPeerConnection? _peer;
  MediaStream? _stream;
  String? _id;
  Timer? _pollTimer, _heartbeat;
  final _pendingIce = <RTCIceCandidate>[];
  final _seenIce = <String>{};
  bool _ready = false, _ending = false, _accepting = false, _polling = false;
  bool _remoteSet = false, _muted = false, _cameraOff = false, _speaker = false, _connected = false;
  String _label = 'Đang chuẩn bị...';
  DateTime? _connectedAt;
  DateTime? _lastContact;
  DateTime? _remoteSetAt;
  bool _preparing = false;
  bool _disposedRenderers = false;
  @override void initState() {
    super.initState(); WidgetsBinding.instance.addObserver(this);
    _id = widget.incoming?['id']?.toString();
    _label = widget.incoming == null ? 'Đang chuẩn bị...' : 'Cuộc gọi đến';
    if (state == AppLifecycleState.resumed) _poll();
    // This version deliberately ends calls when the app is backgrounded.
    // Native background ringing/CallKit is a separate deployment integration.
    if (state == AppLifecycleState.paused) _finish('ended');
  }
  Future<void> _prepare() async {
    _preparing = true;
    try {
    await VideoPreloader.pauseAll();
    await VideoPreloader.pauseAllAudio();
    final config = await _db.functions.invoke('turn-credentials').timeout(const Duration(seconds: 20));
    if (config.status != 200 || config.data is! Map || config.data['iceServers'] is! List) {
      throw Exception('Chưa cấu hình TURN cho gọi thoại/video.');
    }
    if (_ending) return;
    await _local.initialize();
    if (_ending) return;
    await _remote.initialize();
    if (_ending) return;
    _ready = true;
    _stream = await navigator.mediaDevices.getUserMedia({'audio': true,
      'video': widget.video ? {'facingMode': 'user', 'width': {'ideal': 640}, 'height': {'ideal': 480}, 'frameRate': {'ideal': 24}} : false});
    if (_ending) { await _cleanup(); return; }
    _local.srcObject = _stream;
    _speaker = widget.video;
    await Helper.setSpeakerphoneOn(_speaker);
    final peer = await createPeerConnection({'iceServers': config.data['iceServers'], 'sdpSemantics': 'unified-plan'});
    _peer = peer;
    for (final track in _stream!.getTracks()) { await peer.addTrack(track, _stream!); }
    peer.onIceCandidate = (candidate) {
      if (_ending || (candidate.candidate?.isEmpty ?? true)) return;
      if (_id == null) { _pendingIce.add(candidate); } else { _sendIce(candidate); }
    };
    peer.onTrack = (event) {
      if (_ending || !mounted) return;
      if (event.streams.isNotEmpty) setState(() => _remote.srcObject = event.streams.first);
    };
    peer.onConnectionState = (state) {
      if (_ending || !mounted) return;
        setState(() => _label = 'Kết nối bị gián đoạn...');
      }
    };
    _heartbeat ??= Timer.periodic(const Duration(seconds: 20), (_) async {
      if (_id == null || _ending) return;
      try { await _db.rpc('app_call_heartbeat', params: {'call_id': _id}); } catch (_) {}
    });
    if (mounted) setState(() {});
    } finally {
      _preparing = false;
      if (_ending) { await _cleanup(); await _disposeRenderers(); }
    }
  }
  Future<void> _start() async {
    try {
      await _prepare(); if (_ending) return;
      final offer = await _peer!.createOffer();
      await _peer!.setLocalDescription(offer);
      final row = await _db.rpc('app_start_call', params: {'conversation': widget.conversationId,
        'callee': widget.otherId, 'with_video': widget.video, 'offer_sdp': offer.sdp});
      _id = (row as Map)['id'].toString();
      if (_ending) { await _db.rpc('app_finish_call', params: {'call_id': _id, 'result': 'ended'}); return; }
      for (final candidate in _pendingIce) { await _sendIce(candidate); }
      _pendingIce.clear();
      if (mounted) setState(() => _label = 'Đang đổ chuông...');
      _poll();
    } catch (e) { _fail('Không bắt đầu được cuộc gọi: $e'); }
  }
  Future<void> _accept() async {
    if (_accepting || _ending) return;
    setState(() { _accepting = true; _label = 'Đang kết nối...'; });
      if (row['status'] != 'ringing') throw Exception('Cuộc gọi đã kết thúc.');
      await _peer!.setRemoteDescription(RTCSessionDescription(row['offer'] as String, 'offer'));
      _remoteSet = true; _remoteSetAt = DateTime.now();
      final answer = await _peer!.createAnswer();
      await _peer!.setLocalDescription(answer);
      await _db.rpc('app_answer_call', params: {'call_id': _id, 'answer_sdp': answer.sdp});
      _poll();
    } catch (e) { _fail('Không nhận được cuộc gọi: $e'); }
  }
  Future<void> _sendIce(RTCIceCandidate candidate) async {
    if (_id == null || _ending) return;
    try {
      await _db.from('app_call_candidates').insert({'call_id': _id, 'sender_id': _db.auth.currentUser!.id,
        'candidate': candidate.toMap()});
    } catch (_) {
      // ICE is essential; surface failure instead of showing a false connected state.
      if (!_ending) _fail('Lỗi trao đổi kết nối cuộc gọi. Vui lòng thử lại.');
    }

      final status = row['status'];
      if (status != 'ringing' && status != 'accepted') { await _finish(status.toString(), remote: true); return; }
      final expires = DateTime.parse(row['expires_at']);
      if (DateTime.now().toUtc().isAfter(expires)) { await _finish(status == 'ringing' ? 'missed' : 'ended'); return; }
      if (widget.incoming == null && row['answer'] != null && !_remoteSet && _peer != null) {
        await _peer!.setRemoteDescription(RTCSessionDescription(row['answer'] as String, 'answer'));
        _remoteSet = true; _remoteSetAt = DateTime.now();
        if (mounted) setState(() => _label = 'Đang kết nối...');
      }
      if (_remoteSet && _peer != null) {
        final candidates = await _db.from('app_call_candidates').select('id, candidate').eq('call_id', _id!)
          .neq('sender_id', _db.auth.currentUser!.id).order('id').limit(200);
        for (final c in candidates) {
          if (_ending) break;
          final key = c['id'].toString();
          if (_seenIce.contains(key)) continue;
          final data = c['candidate'] as Map;
          await _peer!.addCandidate(RTCIceCandidate(data['candidate'] as String?, data['sdpMid'] as String?, (data['sdpMLineIndex'] as num?)?.toInt()));
          _seenIce.add(key);
        }
      }
      if (!_connected && _remoteSetAt != null && DateTime.now().difference(_remoteSetAt!).inSeconds > 35) {
        await _fail('Quá thời gian kết nối. Kiểm tra TURN và thử lại.'); return;
      }
      if (mounted && _connectedAt != null) setState(() {});
    } catch (_) {
      if (!_ending && DateTime.now().difference(_lastContact!).inSeconds > 30) {
        _fail('Mất kết nối máy chủ cuộc gọi.');
      }
    } finally { _polling = false; }
  }
  Future<void> _fail(String message) async {
    if (_ending) return;
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 6)));
    await _finish('failed');
  }
  Future<void> _finish(String result, {bool remote = false}) async {
    if (_ending) return;
    _ending = true; _pollTimer?.cancel(); _heartbeat?.cancel();
    if (!remote && _id != null) {
      try { await _db.rpc('app_finish_call', params: {'call_id': _id, 'result': result}).timeout(const Duration(seconds: 4)); } catch (_) {}
    }
    await _cleanup();
    if (mounted) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) Navigator.pop(context); });
    }
  }
  Future<void> _cleanup() async {
    final stream = _stream; _stream = null;
    if (stream != null) { for (final track in stream.getTracks()) { await track.stop(); } await stream.dispose(); }
    final peer = _peer; _peer = null;
    if (peer != null) { try { await peer.close(); await peer.dispose(); } catch (_) {} }
    if (_ready) { _local.srcObject = null; _remote.srcObject = null; }
  }
  Future<void> _disposeRenderers() async {
    if (_disposedRenderers) return;
    _disposedRenderers = true;
    try { await _local.dispose(); } catch (_) {}
    try { await _remote.dispose(); } catch (_) {}
  }
  @override void dispose() {
    WidgetsBinding.instance.removeObserver(this); _pollTimer?.cancel(); _heartbeat?.cancel(); _ending = true;
    if (!_preparing) _cleanup().whenComplete(_disposeRenderers);
    super.dispose();
  }
  @override Widget build(BuildContext context) {
    final inbound = widget.incoming != null && !_accepting;
    final duration = _connectedAt == null ? '' : DateTime.now().difference(_connectedAt!);
    return PopScope(canPop: _ending, onPopInvokedWithResult: (popped, _) { if (!popped) _finish(inbound ? 'declined' : 'ended'); },
      child: Scaffold(backgroundColor: const Color(0xff0c2822), body: SafeArea(child: Stack(children: [
        if (_ready && widget.video && _remote.srcObject != null) Positioned.fill(child: RTCVideoView(_remote, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)),
        Positioned(top: 36, left: 20, right: 20, child: Column(children: [
          Text(widget.name, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8), Text(_connected && duration is Duration ? '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}' : _label,
            style: const TextStyle(color: Colors.white70)),
        ])),
        if (_ready && widget.video && _local.srcObject != null) Positioned(right: 16, top: 125,
          child: ClipRRect(borderRadius: BorderRadius.circular(18), child: SizedBox(width: 110, height: 160, child: RTCVideoView(_local, mirror: true)))),
        if (!widget.video || !_connected) const Center(child: Icon(Icons.person, size: 110, color: Colors.white24)),
        Positioned(bottom: 32, left: 12, right: 12, child: Wrap(alignment: WrapAlignment.center, spacing: 16, runSpacing: 16, children: [
          if (inbound) _button(Icons.call, 'Nhận', Colors.green, _accept)
          else ...[
            _button(_muted ? Icons.mic_off : Icons.mic, 'Mic', Colors.white24, () async {
              if (_stream == null) return;
     
            if (widget.video) _button(_cameraOff ? Icons.videocam_off : Icons.videocam, 'Camera', Colors.white24, () async {
              if (_stream == null) return;
              setState(() => _cameraOff = !_cameraOff);
              for (final track in _stream!.getVideoTracks()) { track.enabled = !_cameraOff; }
            }),
            if (widget.video) _button(Icons.cameraswitch, 'Đổi', Colors.white24, () async {
              final tracks = _stream?.getVideoTracks() ?? [];
              if (tracks.isNotEmpty) { try { await Helper.switchCamera(tracks.first); } catch (_) {} }
            }),
          ],
          _button(Icons.call_end, inbound ? 'Từ chối' : 'Kết thúc', Colors.red, () => _finish(inbound ? 'declined' : 'ended')),
        ])),
      ]))));
  }
  Widget _button(IconData icon, String label, Color color, Future<void> Function() action) => Column(mainAxisSize: MainAxisSize.min, children: [
    IconButton.filled(onPressed: _ending ? null : action, style: IconButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white,
      padding: const EdgeInsets.all(16)), icon: Icon(icon)), const SizedBox(height: 5), Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
  ]);
}
