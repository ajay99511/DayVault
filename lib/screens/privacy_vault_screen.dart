import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../config/constants.dart';
import '../models/types.dart';
import '../services/storage_service.dart';
import '../services/vault_security_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/glass_widgets.dart';
import 'journal_viewer_screen.dart';
import 'vault_passcode_setup_screen.dart';
import 'vault_unlock_view.dart';

enum _VaultPhase { checking, needsSetup, locked, unlocked }

/// The Privacy Vault: shows vaulted (isPrivate) stories/events behind a
/// separate passcode.
///
/// Lock-on-leave: the unlocked flag lives only in this State object — popping
/// the route destroys it, so every visit requires the passcode again. As extra
/// hardening the vault also re-locks when the app is backgrounded; this is
/// local to this screen and unrelated to the app-level lock (which is
/// deliberately cold-start-only, see main.dart).
class PrivacyVaultScreen extends ConsumerStatefulWidget {
  const PrivacyVaultScreen({super.key});

  @override
  ConsumerState<PrivacyVaultScreen> createState() => _PrivacyVaultScreenState();
}

class _PrivacyVaultScreenState extends ConsumerState<PrivacyVaultScreen>
    with WidgetsBindingObserver {
  _VaultPhase _phase = _VaultPhase.checking;
  List<JournalEntry> _entries = [];
  bool _loadingEntries = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkSetup();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _phase == _VaultPhase.unlocked) {
      setState(() => _phase = _VaultPhase.locked);
    }
  }

  Future<void> _checkSetup() async {
    final isSet =
        await ref.read(vaultSecurityServiceProvider).isPasscodeSet();
    if (!mounted) return;
    setState(
        () => _phase = isSet ? _VaultPhase.locked : _VaultPhase.needsSetup);
  }

  Future<void> _startSetup() async {
    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const VaultPasscodeSetupScreen()),
    );
    if (done == true && mounted) {
      // Fresh setup just proved identity — go straight to the (empty) vault.
      _onUnlocked();
    }
  }

  void _onUnlocked() {
    setState(() => _phase = _VaultPhase.unlocked);
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() => _loadingEntries = true);
    final entries = await ref
        .read(storageServiceProvider)
        .getJournal(privacy: PrivacyFilter.onlyPrivate);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loadingEntries = false;
    });
  }

  Future<void> _removeFromVault(JournalEntry entry) async {
    final storage = ref.read(storageServiceProvider);
    await storage.saveJournalEntry(entry.copyWith(isPrivate: false));
    ref.read(journalRevisionProvider.notifier).bump();
    if (!mounted) return;
    _loadEntries();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(
        content: Text('Entry moved back to your journal'),
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _openEntry(JournalEntry entry) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => JournalViewerScreen(entry: entry)),
    );
    // Edits/deletes inside the viewer bump the revision; reload regardless so
    // the vault list is always fresh on return.
    if (mounted && _phase == _VaultPhase.unlocked) _loadEntries();
  }

  // ─── Passcode management (only reachable while unlocked) ─────────────────

  Future<void> _changePasscode() async {
    final result = await _showPasscodeFieldsDialog(
      title: 'Change Vault Passcode',
      fields: const ['Current passcode', 'New passcode', 'Confirm new passcode'],
    );
    if (result == null) return;

    final (old, newPin, confirm) = (result[0], result[1], result[2]);
    if (newPin != confirm) {
      _showSnack('New passcodes do not match', isError: true);
      return;
    }

    final change = await ref
        .read(vaultSecurityServiceProvider)
        .changePasscode(old, newPin);
    if (!mounted) return;
    if (change.success) {
      HapticFeedback.heavyImpact();
      _showSnack('Vault passcode changed');
    } else {
      _showSnack(change.error ?? 'Passcode change failed', isError: true);
    }
  }

  Future<void> _resetVaultSecurity() async {
    final count = _entries.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.slate900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Vault Security?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          count > 0
              ? 'Your vault passcode and recovery questions will be deleted, '
                  'and your $count vaulted ${count == 1 ? 'entry' : 'entries'} '
                  'will be moved back to your journal (visible everywhere).'
              : 'Your vault passcode and recovery questions will be deleted.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove',
                style: TextStyle(color: AppColors.rose500)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await _showPasscodeFieldsDialog(
      title: 'Confirm Vault Passcode',
      fields: const ['Vault passcode'],
    );
    if (result == null) return;

    final removal =
        await ref.read(vaultSecurityServiceProvider).removePasscode(result[0]);
    if (!mounted) return;
    if (!removal.success) {
      _showSnack(removal.error ?? 'Passcode verification failed',
          isError: true);
      return;
    }

    // Never leave isPrivate rows behind with no vault: un-vault everything.
    final storage = ref.read(storageServiceProvider);
    final vaulted =
        await storage.getJournal(privacy: PrivacyFilter.onlyPrivate);
    if (vaulted.isNotEmpty) {
      await storage.putManyJournalEntries(
          vaulted.map((e) => e.copyWith(isPrivate: false)).toList());
    }
    ref.read(journalRevisionProvider.notifier).bump();

    if (!mounted) return;
    Navigator.pop(context);
  }

  /// Dialog with obscured digit fields; returns the values or null on cancel.
  Future<List<String>?> _showPasscodeFieldsDialog({
    required String title,
    required List<String> fields,
  }) async {
    final controllers = List.generate(fields.length, (_) => TextEditingController());
    try {
      return await showDialog<List<String>>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.slate900,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < fields.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: controllers[i],
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: SecurityConstants.pinLength,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: fields[i],
                      labelStyle: const TextStyle(
                          color: AppColors.slate400, fontSize: 13),
                      counterText: '',
                      filled: true,
                      fillColor: AppColors.slate800.withValues(alpha: 0.5),
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(
                  ctx, controllers.map((c) => c.text).toList()),
              child: const Text('Confirm',
                  style: TextStyle(color: AppColors.fuchsia500)),
            ),
          ],
        ),
      );
    } finally {
      for (final c in controllers) {
        c.dispose();
      }
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? AppColors.rose500 : null,
      ));
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Credential phases are always-dark per the security-screen convention;
    // the unlocked content list uses normal theme tokens like other tabs.
    switch (_phase) {
      case _VaultPhase.checking:
        return const Scaffold(
          backgroundColor: AppColors.slate950,
          body: Center(
            child: CircularProgressIndicator(color: AppColors.fuchsia500),
          ),
        );
      case _VaultPhase.needsSetup:
        return _buildSetupPrompt();
      case _VaultPhase.locked:
        return Scaffold(
          backgroundColor: AppColors.slate950,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: SafeArea(
            child: VaultUnlockView(onUnlocked: _onUnlocked),
          ),
        );
      case _VaultPhase.unlocked:
        return _buildVaultContent();
    }
  }

  Widget _buildSetupPrompt() {
    return Scaffold(
      backgroundColor: AppColors.slate950,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ResponsiveCenter(
              maxWidth: 440,
              child: Column(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppColors.fuchsia500.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.fuchsia500.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(Icons.shield_moon_outlined,
                        color: AppColors.fuchsia500, size: 44),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'PRIVACY VAULT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Keep selected stories and events hidden from your '
                    'journal, calendar, search and stats — visible only here, '
                    'behind a separate passcode.\n\n'
                    'You\'ll pick recovery questions in case you ever forget '
                    'the passcode.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.slate400,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _startSetup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.fuchsia500,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'SET UP VAULT PASSCODE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVaultContent() {
    final tokens = context.tokens;
    return Scaffold(
      backgroundColor: tokens.surfaceBase,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: tokens.textPrimary),
        title: Row(
          children: [
            const Icon(Icons.shield_moon_outlined,
                color: AppColors.fuchsia500, size: 20),
            const SizedBox(width: 8),
            Text(
              'PRIVACY VAULT',
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: tokens.textSecondary),
            color: AppColors.slate900,
            onSelected: (value) {
              if (value == 'change') _changePasscode();
              if (value == 'reset') _resetVaultSecurity();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'change',
                child: Text('Change passcode',
                    style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
              PopupMenuItem(
                value: 'reset',
                child: Text('Remove vault security',
                    style:
                        TextStyle(color: AppColors.rose500, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: _loadingEntries
            ? const Center(
                child:
                    CircularProgressIndicator(color: AppColors.fuchsia500))
            : _entries.isEmpty
                ? _buildEmptyState(tokens)
                : RefreshIndicator(
                    onRefresh: _loadEntries,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _entries.length,
                      itemBuilder: (context, index) =>
                          _buildEntryTile(_entries[index], tokens),
                    ),
                  ),
      ),
    );
  }

  Widget _buildEmptyState(AppTokens tokens) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.visibility_off_outlined,
                color: tokens.textTertiary, size: 48),
            const SizedBox(height: 16),
            Text(
              'Your vault is empty',
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Move a story or event here from its viewer or the editor '
              'using "Move to Privacy Vault".',
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.textTertiary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryTile(JournalEntry entry, AppTokens tokens) {
    final isStory = entry.type == EntryType.story;
    final accent = isStory ? AppColors.indigo500 : AppColors.emerald500;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        child: ListTile(
          onTap: () => _openEntry(entry),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Text(
              moodIcons[entry.mood] ?? '😐',
              style: const TextStyle(fontSize: 18),
            ),
          ),
          title: Text(
            entry.headline,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tokens.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            '${isStory ? 'Story' : 'Event'} · '
            '${DateFormat.yMMMd().format(entry.date)}',
            style: TextStyle(color: tokens.textTertiary, fontSize: 11),
          ),
          trailing: IconButton(
            tooltip: 'Move back to journal',
            icon: Icon(Icons.visibility_outlined,
                color: tokens.textTertiary, size: 20),
            onPressed: () => _removeFromVault(entry),
          ),
        ),
      ),
    );
  }
}
