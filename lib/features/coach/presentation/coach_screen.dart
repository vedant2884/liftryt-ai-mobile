import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/speech/speech_input_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/beta_badge.dart';
import '../../../shared/widgets/dumbbell_spinner.dart';
import '../data/coach_api.dart';
import '../data/models.dart';
import 'widgets/markdown_message.dart';
import 'widgets/tool_result_card.dart';

String _formatTime(DateTime d) {
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  final period = d.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

String _formatSessionDate(DateTime d) {
  final now = DateTime.now();
  if (d.year == now.year && d.month == now.month && d.day == now.day) return _formatTime(d);
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[d.month - 1]} ${d.day}';
}

/// Mirrors `frontend/src/pages/CoachPage.tsx` and its recently-redesigned
/// premium empty state — same backend/Groq integration (never a second AI
/// client, the Groq key never enters this app), same session model.
/// Sidebar becomes a mobile drawer instead of a permanent column.
class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key});

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _inputController = TextEditingController();
  final _inputFocus = FocusNode();
  final _scrollController = ScrollController();

  List<ChatSession> _sessions = [];
  bool _sessionsLoading = true;
  String? _activeSessionId;
  List<ChatMessage> _messages = [];
  bool _loadingSession = false;
  bool _sending = false;
  // Set once the streaming reply's placeholder bubble exists (first delta
  // or tool_result event) — drives hiding the dumbbell "Thinking" bubble
  // in favor of the real, growing reply, mirroring CoachPage.tsx.
  String? _streamingMessageId;
  CancelToken? _cancelToken;
  String? _error;
  bool _listening = false;
  // What was already typed before dictation started — new speech is
  // appended after it rather than overwriting it, matching CoachInput.tsx.
  String _textBeforeListening = '';

  @override
  void initState() {
    super.initState();
    // Repaints the input's border on focus change (see the focus-glow
    // treatment in build()) — FocusNode doesn't trigger a rebuild on its
    // own.
    _inputFocus.addListener(() => setState(() {}));
    ref.read(coachApiProvider).fetchSessions().then((s) {
      if (mounted) {
        setState(() {
          _sessions = s;
          _sessionsLoading = false;
        });
      }
    }).catchError((_) {
      if (mounted) setState(() => _sessionsLoading = false);
    });
  }

  @override
  void dispose() {
    if (_listening) SpeechInputService.stop();
    _cancelToken?.cancel();
    _inputController.dispose();
    _inputFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await SpeechInputService.stop();
      return;
    }
    // Permission denied or no recognizer on this device — the OS's own
    // permission prompt already explained why, so we just fall back to
    // normal typing rather than layering on a second error surface (same
    // approach as the web app's mic button).
    final available = await SpeechInputService.ensureAvailable();
    if (!available || !mounted) return;

    _textBeforeListening = _inputController.text;
    setState(() => _listening = true);
    await SpeechInputService.listen(
      onResult: (transcript) {
        final prefix = _textBeforeListening.isEmpty ? '' : '$_textBeforeListening ';
        _inputController.text = '$prefix$transcript';
        _inputController.selection = TextSelection.collapsed(offset: _inputController.text.length);
      },
      onDone: () {
        if (mounted) setState(() => _listening = false);
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _openSession(String sessionId) async {
    setState(() {
      _error = null;
      _activeSessionId = sessionId;
      _loadingSession = true;
    });
    Navigator.of(context).maybePop();
    try {
      final history = await ref.read(coachApiProvider).fetchMessages(sessionId);
      if (mounted) setState(() => _messages = history);
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _loadingSession = false);
    }
  }

  void _startNewChat() {
    setState(() {
      _error = null;
      _activeSessionId = null;
      _messages = [];
    });
    Navigator.of(context).maybePop();
  }

  Future<String> _ensureSession() async {
    if (_activeSessionId != null) return _activeSessionId!;
    final session = await ref.read(coachApiProvider).createSession();
    setState(() {
      _activeSessionId = session.id;
      _sessions = [session, ..._sessions];
    });
    return session.id;
  }

  /// Drives one streamed reply into `_messages`, from whichever SSE
  /// stream the caller hands it — new-message sending is the only caller
  /// today, but this is written to also take an edit-regeneration stream
  /// later without duplicating the delta/tool_result/done/error handling.
  Future<void> _consumeStream(
    String sessionId,
    Stream<Map<String, dynamic>> events, {
    required void Function(ChatMessage userMessage) onUserMessage,
  }) async {
    final streamingId = 'streaming-${DateTime.now().millisecondsSinceEpoch}';

    void applyToPlaceholder(ChatMessage Function(ChatMessage? existing) build) {
      final idx = _messages.indexWhere((m) => m.id == streamingId);
      setState(() {
        if (idx == -1) {
          _streamingMessageId = streamingId;
          _messages = [..._messages, build(null)];
        } else {
          final updated = [..._messages];
          updated[idx] = build(updated[idx]);
          _messages = updated;
        }
      });
      _scrollToBottom();
    }

    await for (final event in events) {
      switch (event['type']) {
        case 'start':
          onUserMessage(ChatMessage.fromJson(event['user_message'] as Map<String, dynamic>));
        case 'delta':
          applyToPlaceholder((existing) => ChatMessage(
                id: streamingId,
                sessionId: sessionId,
                role: 'assistant',
                content: '${existing?.content ?? ''}${event['content']}',
                toolName: existing?.toolName,
                toolPayload: existing?.toolPayload,
                createdAt: existing?.createdAt ?? DateTime.now(),
              ));
        case 'tool_result':
          applyToPlaceholder((existing) => ChatMessage(
                id: streamingId,
                sessionId: sessionId,
                role: 'assistant',
                content: existing?.content ?? '',
                toolName: event['tool_name'] as String,
                toolPayload: {
                  'name': event['tool_name'],
                  'arguments': event['arguments'],
                  'result': event['result'],
                },
                createdAt: existing?.createdAt ?? DateTime.now(),
              ));
        case 'done':
          final assistantMessage = ChatMessage.fromJson(event['assistant_message'] as Map<String, dynamic>);
          setState(() {
            _messages = [for (final m in _messages) if (m.id == streamingId) assistantMessage else m];
            _streamingMessageId = null;
          });
        case 'error':
          setState(() {
            // No visible content ever arrived for this turn — drop the
            // empty placeholder rather than leaving a blank bubble.
            _messages = [
              for (final m in _messages)
                if (m.id != streamingId || m.content.isNotEmpty) m,
            ];
            _streamingMessageId = null;
            _error = 'The AI coach is temporarily unavailable. Please try again.';
          });
      }
    }
  }

  Future<void> _sendMessage([String? text]) async {
    final content = (text ?? _inputController.text).trim();
    if (content.isEmpty || _sending) return;
    setState(() => _error = null);
    _inputController.clear();

    final optimisticId = 'pending-${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = ChatMessage(
      id: optimisticId,
      sessionId: _activeSessionId ?? 'pending',
      role: 'user',
      content: content,
      createdAt: DateTime.now(),
    );
    setState(() {
      _messages = [..._messages, optimistic];
      _sending = true;
      _streamingMessageId = null;
    });
    _scrollToBottom();

    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    try {
      final sessionId = await _ensureSession();
      await _consumeStream(
        sessionId,
        ref.read(coachApiProvider).sendMessageStream(sessionId, content, cancelToken: cancelToken),
        onUserMessage: (userMessage) {
          // Swaps the client-only optimistic id for the real persisted
          // one, matching CoachPage.tsx — not currently load-bearing on
          // mobile (no Edit Message feature here yet) but keeps message
          // ids honest for whatever reads them next (e.g. a future edit
          // feature, or just re-opening the session).
          setState(() {
            _messages = [for (final m in _messages) if (m.id == optimisticId) userMessage else m];
          });
        },
      );
      ref.read(coachApiProvider).fetchSessions().then((s) {
        if (mounted) setState(() => _sessions = s);
      });
    } catch (e) {
      // An intentional Stop tap, not a failure — whatever text had
      // already streamed in stays in the thread.
      if (e is DioException && CancelToken.isCancel(e)) return;
      if (mounted) {
        setState(() => _error = e is DioException ? ApiException.fromDioException(e).message : '$e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _streamingMessageId = null;
        });
      }
      _cancelToken = null;
    }
  }

  void _stopGenerating() {
    _cancelToken?.cancel();
  }

  Future<void> _weeklyCheckin() async {
    setState(() {
      _error = null;
      _sending = true;
    });
    try {
      final sessionId = await _ensureSession();
      final message = await ref.read(coachApiProvider).requestWeeklyCheckin(sessionId);
      if (mounted) setState(() => _messages = [..._messages, message]);
      _scrollToBottom();
      ref.read(coachApiProvider).fetchSessions().then((s) {
        if (mounted) setState(() => _sessions = s);
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Gym AI Coach', style: TextStyle(fontSize: 17)),
            SizedBox(width: 8),
            BetaBadge(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _sending ? null : _weeklyCheckin,
            child: const Text('Weekly check-in', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
      drawer: Drawer(backgroundColor: context.colors.surface, child: _sidebar()),
      body: Column(
        children: [
          Expanded(
            child: _loadingSession
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _emptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        // Dumbbell shows from send until the first token/
                        // tool result actually arrives, not for the whole
                        // reply — see _streamingMessageId.
                        itemCount: _messages.length + (_sending && _streamingMessageId == null ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i == _messages.length) {
                            return _thinkingBubble();
                          }
                          return _messageBubble(_messages[i]);
                        },
                      ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_error!, style: const TextStyle(color: Color(0xFFF87171), fontSize: 12)),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                padding: const EdgeInsets.only(left: 16, right: 6, top: 4, bottom: 4),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _inputFocus.hasFocus ? context.colors.accent.withValues(alpha: 0.6) : context.colors.lineStrong,
                  ),
                  boxShadow: _inputFocus.hasFocus
                      ? [BoxShadow(color: context.colors.accent.withValues(alpha: 0.18), blurRadius: 16)]
                      : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        focusNode: _inputFocus,
                        enabled: !_sending,
                        decoration: InputDecoration(
                          hintText: _listening ? 'Listening...' : 'Ask your coach anything...',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                        onTapOutside: (_) => _inputFocus.unfocus(),
                      ),
                    ),
                    IconButton(
                      onPressed: _sending ? null : _toggleListening,
                      icon: Icon(_listening ? Icons.mic_rounded : Icons.mic_none_rounded, size: 20),
                      color: _listening ? const Color(0xFFF87171) : context.colors.inkMuted,
                      tooltip: _listening ? 'Stop voice input' : 'Start voice input',
                    ),
                    const SizedBox(width: 4),
                    IconButton.filled(
                      onPressed: _sending ? _stopGenerating : () => _sendMessage(),
                      icon: Icon(_sending ? Icons.stop_rounded : Icons.arrow_upward_rounded, size: 18),
                      tooltip: _sending ? 'Stop generating' : 'Send message',
                      style: IconButton.styleFrom(
                        backgroundColor: context.colors.accent,
                        foregroundColor: context.colors.onAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebar() {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton.icon(
              onPressed: _startNewChat,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('New chat'),
              style: OutlinedButton.styleFrom(side: BorderSide(color: context.colors.lineStrong)),
            ),
          ),
          Expanded(
            child: _sessionsLoading
                ? const Center(child: CircularProgressIndicator())
                : _sessions.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('No past conversations yet.',
                              style: TextStyle(color: context.colors.inkMuted, fontSize: 12)),
                        ),
                      )
                    : ListView(
                        children: [
                          for (final s in _sessions)
                            ListTile(
                              selected: s.id == _activeSessionId,
                              selectedTileColor: context.colors.surfaceHover,
                              title: Text(s.title ?? 'New chat',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: context.colors.ink, fontSize: 13)),
                              subtitle: Text(_formatSessionDate(s.updatedAt),
                                  style: TextStyle(color: context.colors.inkMuted, fontSize: 10)),
                              onTap: () => _openSession(s.id),
                            ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _messageBubble(ChatMessage m) {
    final isUser = m.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? context.colors.accent : context.colors.bg,
          borderRadius: BorderRadius.circular(12),
          border: isUser ? null : Border.all(color: context.colors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser && m.toolPayload != null) ...[
              ToolResultCard(toolName: m.toolName, payload: m.toolPayload!),
              Divider(color: context.colors.line, height: 16),
            ],
            if (isUser)
              Text(m.content, style: TextStyle(color: context.colors.onAccent, fontSize: 13))
            else
              MarkdownMessage(content: m.content),
            const SizedBox(height: 4),
            Text(
              _formatTime(m.createdAt),
              style: TextStyle(
                color: isUser ? context.colors.onAccent.withValues(alpha: 0.7) : context.colors.inkMuted,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thinkingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: context.colors.bg,
            border: Border.all(color: context.colors.line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Purple->emerald signature accent, mirrors the web app's
              // gradient top-bar on the Coach "thinking" bubble.
              Container(height: 2, decoration: BoxDecoration(gradient: context.colors.brandGradient)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: DumbbellSpinner(
                  size: 16,
                  label: 'Thinking...',
                  color: context.colors.accent,
                  labelColor: context.colors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Premium fitness-coach empty state — deliberately no chat-bubble icon
  /// and no suggested-question chips, matching the web app's redesigned
  /// equivalent. The blurred gradient blob behind the pill is the same
  /// purple->emerald "brand signature" placement used there.
  Widget _emptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              top: -20,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.12,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(shape: BoxShape.circle, gradient: context.colors.brandGradient),
                    ),
                  ),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: context.colors.lineStrong),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fitness_center_rounded, color: context.colors.accent, size: 13),
                      const SizedBox(width: 6),
                      Text('GYM AI COACH',
                          style: TextStyle(
                              color: context.colors.inkSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2)),
                      const SizedBox(width: 6),
                      const BetaBadge(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('Your training. Your data. Your coach.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.colors.ink, fontSize: 19, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('Ask anything about your workouts, progress, nutrition, or training.',
                    textAlign: TextAlign.center, style: TextStyle(color: context.colors.inkMuted, fontSize: 13)),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => _inputFocus.requestFocus(),
                  child: const Text('Start a conversation'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
