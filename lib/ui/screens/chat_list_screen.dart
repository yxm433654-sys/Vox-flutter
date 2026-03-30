import 'package:dynamic_photo_chat_flutter/models/user.dart';
import 'package:dynamic_photo_chat_flutter/state/app_state.dart';
import 'package:dynamic_photo_chat_flutter/ui/screens/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  Future<void> _addPeer() async {
    final controller = TextEditingController();
    UserProfile? foundUser;
    String? error;
    bool searching = false;

    final selectedUser = await showDialog<UserProfile>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setInnerState) => AlertDialog(
            title: const Text('Add conversation'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    hintText: 'Search by username',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (_) async {
                    setInnerState(() {
                      searching = true;
                      error = null;
                      foundUser = null;
                    });
                    final user = await context
                        .read<AppState>()
                        .findUserByUsername(controller.text.trim());
                    setInnerState(() {
                      searching = false;
                      foundUser = user;
                      error = user == null ? 'User not found.' : null;
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (searching)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(),
                  )
                else if (foundUser != null)
                  _FoundUserCard(user: foundUser!)
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      error ?? 'Enter a username to start a conversation.',
                      style: const TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: foundUser == null
                    ? null
                    : () => Navigator.of(dialogContext).pop(foundUser),
                child: const Text('Add'),
              ),
            ],
          ),
        );
      },
    );

    if (selectedUser == null || !mounted) return;
    final appState = context.read<AppState>();
    await appState.addPeer(selectedUser.userId);
    await appState.prefetchUser(selectedUser.userId);
  }

  Future<bool> _confirmDelete(BuildContext context, int peerId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove conversation'),
        content: Text(
          'Remove the conversation with ${context.read<AppState>().displayNameFor(peerId)} from the list?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Color _avatarColor(int id) {
    final colors = <Color>[
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFF8B5CF6),
      const Color(0xFFEF4444),
    ];
    return colors[id.abs() % colors.length];
  }

  String _avatarText(String name, int id) {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) return trimmed.characters.first;
    return id.toString();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final session = state.session;
    final username = session?.username ?? 'Guest';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F7FB),
        scrolledUnderElevation: 0,
        elevation: 0,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              username,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Text(
              'Conversations',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Add by username',
            onPressed: _addPeer,
            icon: const Icon(Icons.person_add_alt_1_rounded),
          ),
          PopupMenuButton<String>(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (value) async {
              if (value == 'add') {
                await _addPeer();
              } else if (value == 'logout') {
                await state.logout();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'add',
                child: Text('Add conversation'),
              ),
              PopupMenuItem<String>(
                value: 'logout',
                child: Text('Log out'),
              ),
            ],
          ),
        ],
      ),
      body: state.peers.isEmpty
          ? const _EmptyConversationState()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: state.peers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final peerId = state.peers[index];
                state.prefetchUser(peerId);
                final unread = state.unreadCount(peerId);
                final name = state.displayNameFor(peerId);
                final avatarUrl = state.avatarUrlFor(peerId);

                return Dismissible(
                  key: ValueKey('peer-$peerId'),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) => _confirmDelete(context, peerId),
                  onDismissed: (_) => state.removePeer(peerId),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () {
                        state.clearUnread(peerId);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(peerId: peerId),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            avatarUrl == null
                                ? CircleAvatar(
                                    radius: 24,
                                    backgroundColor: _avatarColor(peerId),
                                    child: Text(
                                      _avatarText(name, peerId),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  )
                                : CircleAvatar(
                                    radius: 24,
                                    backgroundImage: NetworkImage(avatarUrl),
                                  ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    unread > 0
                                        ? '$unread unread messages'
                                        : 'Tap to open the conversation',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Color(0xFF9CA3AF),
                                ),
                                const SizedBox(height: 8),
                                if (unread > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      unread > 99 ? '99+' : unread.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _FoundUserCard extends StatelessWidget {
  const _FoundUserCard({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            child: Text(user.username.trim().characters.first),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.username,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'User ID ${user.userId}',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyConversationState extends StatelessWidget {
  const _EmptyConversationState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFE0E7FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 32,
                color: Color(0xFF4338CA),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No conversations yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use the add button in the top right to search for a username and start chatting.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
