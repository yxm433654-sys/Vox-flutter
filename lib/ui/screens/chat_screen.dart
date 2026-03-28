import 'dart:async';

import 'package:dynamic_photo_chat_flutter/models/file_upload_response.dart';
import 'package:dynamic_photo_chat_flutter/models/message.dart';
import 'package:dynamic_photo_chat_flutter/services/realtime_service.dart';
import 'package:dynamic_photo_chat_flutter/state/app_state.dart';
import 'package:dynamic_photo_chat_flutter/ui/screens/video_player_screen.dart';
import 'package:dynamic_photo_chat_flutter/ui/widgets/message_bubble.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.peerId});

  final int peerId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  final List<ChatMessage> _messages = [];
  RealtimeService? _realtime;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  int _lastMessageId = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _realtime?.stop();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final state = context.read<AppState>();
    final session = state.session!;
    try {
      final history = await state.messages.history(
          userId: session.userId, peerId: widget.peerId, page: 0, size: 100);
      _messages
        ..clear()
        ..addAll(history);
      _lastMessageId = _messages.isEmpty
          ? 0
          : _messages.map((e) => e.id).reduce((a, b) => a > b ? a : b);
      await _markAllRead(session.userId);
      _startRealtime();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _scrollToBottom();
      }
    }
  }

  void _startRealtime() {
    final state = context.read<AppState>();
    final session = state.session!;
    final rt = RealtimeService(state.messages, wsBaseUrl: state.wsBaseUrl);
    rt.start(
      userId: session.userId,
      token: session.token,
      lastMessageId: _lastMessageId,
      onMessage: (m) async {
        if (m.id > _lastMessageId) _lastMessageId = m.id;
        if (m.senderId != widget.peerId) return;
        if (_messages.any((e) => e.id == m.id)) return;
        setState(() {
          _messages.add(m);
          _messages.sort((a, b) => a.id.compareTo(b.id));
        });
        await _markAllRead(session.userId);
        _scrollToBottom();
      },
      onError: (e) {
        if (!mounted) return;
        setState(() => _error = e.toString());
      },
    );
    _realtime = rt;
  }

  Future<void> _markAllRead(int myId) async {
    final state = context.read<AppState>();
    final unread = _messages
        .where((m) => m.receiverId == myId && (m.status ?? '') != 'READ')
        .toList();
    for (final m in unread) {
      try {
        await state.messages.markRead(m.id);
        final idx = _messages.indexWhere((e) => e.id == m.id);
        if (idx >= 0) {
          _messages[idx] = ChatMessage(
            id: m.id,
            senderId: m.senderId,
            receiverId: m.receiverId,
            type: m.type,
            content: m.content,
            resourceId: m.resourceId,
            videoResourceId: m.videoResourceId,
            coverUrl: m.coverUrl,
            videoUrl: m.videoUrl,
            status: 'READ',
            createdAt: m.createdAt,
          );
        }
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    final state = context.read<AppState>();
    final session = state.session!;
    setState(() => _sending = true);
    try {
      final id = await state.messages.sendText(
          senderId: session.userId, receiverId: widget.peerId, content: text);
      _textCtrl.clear();
      final msg = ChatMessage(
        id: id,
        senderId: session.userId,
        receiverId: widget.peerId,
        type: 'TEXT',
        content: text,
        resourceId: null,
        videoResourceId: null,
        coverUrl: null,
        videoUrl: null,
        status: 'SENT',
        createdAt: DateTime.now(),
      );
      setState(() {
        _messages.add(msg);
        _messages.sort((a, b) => a.id.compareTo(b.id));
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndUploadNormal() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: kIsWeb,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'heic', 'mp4', 'mov'],
    );
    if (result == null || result.files.isEmpty) return;
    if (!mounted) return;
    final state = context.read<AppState>();
    final session = state.session!;
    setState(() => _sending = true);
    try {
      final uploaded = await state.files
          .uploadNormal(file: result.files.first, userId: session.userId);
      await _sendForUploadedNormal(uploaded, session.userId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendForUploadedNormal(
      FileUploadResponse uploaded, int myId) async {
    final state = context.read<AppState>();
    final fileType = (uploaded.fileType ?? '').toUpperCase();
    if (uploaded.fileId == null) {
      throw Exception('Upload response missing fileId');
    }
    if (fileType == 'IMAGE') {
      final mid = await state.messages.sendImage(
          senderId: myId,
          receiverId: widget.peerId,
          resourceId: uploaded.fileId!);
      final msg = ChatMessage(
        id: mid,
        senderId: myId,
        receiverId: widget.peerId,
        type: 'IMAGE',
        content: null,
        resourceId: uploaded.fileId,
        videoResourceId: null,
        coverUrl: uploaded.url,
        videoUrl: null,
        status: 'SENT',
        createdAt: DateTime.now(),
      );
      setState(() => _messages.add(msg));
      _scrollToBottom();
      return;
    }

    final mid = await state.messages.sendVideo(
        senderId: myId,
        receiverId: widget.peerId,
        videoResourceId: uploaded.fileId!);
    final msg = ChatMessage(
      id: mid,
      senderId: myId,
      receiverId: widget.peerId,
      type: 'VIDEO',
      content: null,
      resourceId: null,
      videoResourceId: uploaded.fileId,
      coverUrl: null,
      videoUrl: uploaded.url,
      status: 'SENT',
      createdAt: DateTime.now(),
    );
    setState(() => _messages.add(msg));
    _scrollToBottom();
  }

  Future<void> _pickAndUploadLivePhoto() async {
    final jpegPick = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: kIsWeb,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg'],
    );
    if (jpegPick == null || jpegPick.files.isEmpty) return;
    final movPick = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: kIsWeb,
      type: FileType.custom,
      allowedExtensions: const ['mov', 'mp4'],
    );
    if (movPick == null || movPick.files.isEmpty) return;
    if (!mounted) return;
    final state = context.read<AppState>();
    final session = state.session!;
    setState(() => _sending = true);
    try {
      final uploaded = await state.files.uploadLivePhoto(
          jpeg: jpegPick.files.first,
          mov: movPick.files.first,
          userId: session.userId);
      await _sendForDynamic(uploaded, session.userId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndUploadMotionPhoto() async {
    final pick = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: kIsWeb,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg'],
    );
    if (pick == null || pick.files.isEmpty) return;
    if (!mounted) return;
    final state = context.read<AppState>();
    final session = state.session!;
    setState(() => _sending = true);
    try {
      final uploaded = await state.files
          .uploadMotionPhoto(file: pick.files.first, userId: session.userId);
      await _sendForDynamic(uploaded, session.userId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendForDynamic(FileUploadResponse uploaded, int myId) async {
    final coverId = uploaded.coverId;
    final videoId = uploaded.videoId;
    if (coverId == null || videoId == null) {
      throw Exception('Upload response missing coverId/videoId');
    }
    final state = context.read<AppState>();
    final mid = await state.messages.sendDynamicPhoto(
        senderId: myId,
        receiverId: widget.peerId,
        coverId: coverId,
        videoId: videoId);
    final msg = ChatMessage(
      id: mid,
      senderId: myId,
      receiverId: widget.peerId,
      type: 'DYNAMIC_PHOTO',
      content: null,
      resourceId: coverId,
      videoResourceId: videoId,
      coverUrl: uploaded.coverUrl,
      videoUrl: uploaded.videoUrl,
      status: 'SENT',
      createdAt: DateTime.now(),
    );
    setState(() => _messages.add(msg));
    _scrollToBottom();
  }

  void _openPlayer(String url) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => VideoPlayerScreen(url: url)));
  }

  Future<void> _showAttachMenu() async {
    if (_sending) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('上传图片/视频'),
                onTap: () => Navigator.of(ctx).pop('normal'),
              ),
              ListTile(
                leading: const Icon(Icons.motion_photos_on_outlined),
                title: const Text('上传 Live Photo (JPEG + MOV/MP4)'),
                onTap: () => Navigator.of(ctx).pop('live'),
              ),
              ListTile(
                leading: const Icon(Icons.motion_photos_auto_outlined),
                title: const Text('上传 Motion Photo (带XMP的JPEG)'),
                onTap: () => Navigator.of(ctx).pop('motion'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
    if (!mounted) return;
    if (action == null) return;
    if (action == 'normal') return _pickAndUploadNormal();
    if (action == 'live') return _pickAndUploadLivePhoto();
    if (action == 'motion') return _pickAndUploadMotionPhoto();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final myId = state.session!.userId;
    return Scaffold(
      appBar: AppBar(
        title: Text('与用户 ${widget.peerId} 聊天'),
      ),
      body: Column(
        children: [
          if (_error != null)
            Padding(
                padding: const EdgeInsets.all(8),
                child:
                    Text(_error!, style: const TextStyle(color: Colors.red))),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, idx) {
                      final m = _messages[idx];
                      final isMine = m.senderId == myId;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: MessageBubble(
                          message: m,
                          isMine: isMine,
                          onPlayVideo: _openPlayer,
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _showAttachMenu,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendText(),
                      decoration: const InputDecoration(
                        hintText: '输入消息',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      minLines: 1,
                      maxLines: 4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _sending ? null : _sendText,
                    child: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('发送'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
