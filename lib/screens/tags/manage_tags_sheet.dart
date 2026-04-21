import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/custom_tag_model.dart';
import '../../providers/tag_provider.dart';

class ManageTagsSheet extends StatefulWidget {
  const ManageTagsSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<TagProvider>(),
      child: const ManageTagsSheet(),
    ),
  );

  @override
  State<ManageTagsSheet> createState() => _ManageTagsSheetState();
}

class _ManageTagsSheetState extends State<ManageTagsSheet> {
  final _nameCtrl = TextEditingController();
  String _emoji = '🏷️';
  Color _color = AppColors.primary;
  bool _saving = false;

  static const _emojis = ['🏷️','🏔️','✈️','🏖️','🎉','🏠','💼','📚','🎮','🚗','🍕','💊','🎵','👗','🌿','💰','🎁','⚽'];
  static const _colors = [
    Color(0xFF2563EB), Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFEF4444),
    Color(0xFF8B5CF6), Color(0xFF06B6D4), Color(0xFFEC4899), Color(0xFF14B8A6),
    Color(0xFFF97316), Color(0xFF6366F1), Color(0xFF64748B), Color(0xFF0F172A),
  ];

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await context.read<TagProvider>().createTag(name: name, emoji: _emoji, color: _color);
      _nameCtrl.clear();
      setState(() { _emoji = '🏷️'; _color = AppColors.primary; });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name already exists')));
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.only(bottom: bottom > 0 ? bottom : 16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(28)),
      child: Consumer<TagProvider>(
        builder: (_, provider, __) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(margin: const EdgeInsets.only(top: 12, bottom: 8), width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(children: [
                Text('Manage Tags', style: GoogleFonts.inter(color: AppColors.text1, fontSize: 18, fontWeight: FontWeight.w800)),
                const Spacer(),
                GestureDetector(onTap: () => Navigator.pop(context),
                  child: Container(width: 32, height: 32, decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.close_rounded, size: 18, color: AppColors.text2))),
              ]),
            ),

            // Create new tag
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('New Tag', style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  // Emoji + name row
                  Row(children: [
                    // Emoji picker (tap to cycle)
                    GestureDetector(
                      onTap: () {
                        final i = _emojis.indexOf(_emoji);
                        setState(() => _emoji = _emojis[(i + 1) % _emojis.length]);
                      },
                      child: Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(color: _color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: _color.withValues(alpha: 0.3))),
                        alignment: Alignment.center,
                        child: Text(_emoji, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(
                      controller: _nameCtrl,
                      style: GoogleFonts.inter(color: AppColors.text1, fontSize: 15, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Tag name (e.g. Himalayas)',
                        hintStyle: GoogleFonts.inter(color: AppColors.text3, fontSize: 14),
                        filled: true, fillColor: AppColors.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    )),
                  ]),
                  const SizedBox(height: 12),
                  // Color picker
                  Wrap(spacing: 8, runSpacing: 8, children: _colors.map((c) {
                    final sel = _color == c;
                    return GestureDetector(
                      onTap: () => setState(() => _color = c),
                      child: AnimatedContainer(duration: const Duration(milliseconds: 150),
                        width: 28, height: 28,
                        decoration: BoxDecoration(color: c, shape: BoxShape.circle,
                          border: Border.all(color: sel ? AppColors.text1 : Colors.transparent, width: 2.5),
                          boxShadow: sel ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 6)] : []),
                        child: sel ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null),
                    );
                  }).toList()),
                  const SizedBox(height: 14),
                  SizedBox(width: double.infinity, child: ElevatedButton(
                    onPressed: _saving ? null : _create,
                    style: ElevatedButton.styleFrom(backgroundColor: _color, foregroundColor: Colors.white, minimumSize: const Size(0, 46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Create Tag', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  )),
                ]),
              ),
            ),

            // Existing tags
            if (provider.tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(alignment: Alignment.centerLeft, child: Text('Your Tags',
                  style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12, fontWeight: FontWeight.w700)))),
              const SizedBox(height: 8),
              SizedBox(
                height: 56,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: provider.tags.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final tag = provider.tags[i];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: tag.color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: tag.color.withValues(alpha: 0.25)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(tag.emoji, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(tag.name, style: GoogleFonts.inter(color: tag.color, fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _confirmDelete(context, provider, tag),
                          child: Icon(Icons.close_rounded, size: 14, color: tag.color.withValues(alpha: 0.7)),
                        ),
                      ]),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext ctx, TagProvider provider, CustomTagModel tag) async {
    final ok = await showDialog<bool>(context: ctx, builder: (d) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Delete "${tag.name}"?', style: GoogleFonts.inter(color: AppColors.text1, fontWeight: FontWeight.w700)),
      content: Text('This tag will be removed from all transactions.', style: GoogleFonts.inter(color: AppColors.text2, fontSize: 13)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense, foregroundColor: Colors.white, minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
          onPressed: () => Navigator.pop(d, true),
          child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        ),
      ],
    ));
    if (ok == true) await provider.deleteTag(tag.id);
  }
}
