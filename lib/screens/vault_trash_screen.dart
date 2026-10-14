import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/vault_service.dart';
import '../utils/app_settings.dart';

class VaultTrashScreen extends StatefulWidget {
  const VaultTrashScreen({super.key});

  @override
  State<VaultTrashScreen> createState() => _VaultTrashScreenState();
}

class _VaultTrashScreenState extends State<VaultTrashScreen> {
  List<TrashItem> _trashItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrash();
  }

  Future<void> _loadTrash() async {
    setState(() => _isLoading = true);
    final items = await VaultService.instance.getTrashItems();
    if (mounted) {
      setState(() {
        _trashItems = items;
        _isLoading = false;
      });
    }
  }

  Future<void> _restoreItem(TrashItem item) async {
    final success = await VaultService.instance.restoreFromTrash(item);
    if (success && mounted) {
      _loadTrash();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppSettings.languageNotifier.value == 'ar'
                ? 'تم استرجاع الملف بنجاح'
                : 'File restored successfully',
          ),
        ),
      );
    } else if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppSettings.languageNotifier.value == 'ar'
                ? 'تعذر استرجاع الملف'
                : 'Failed to restore file',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _deleteItem(TrashItem item) async {
    final success = await VaultService.instance.deletePermanently(item);
    if (success && mounted) {
      _loadTrash();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppSettings.languageNotifier.value;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFF141824),
      appBar: AppBar(
        title: Text(
          lang == 'ar' ? 'سلة المهملات' : 'Trash Bin',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trashItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline_rounded, size: 80, color: Colors.white24),
                      const SizedBox(height: 16),
                      Text(
                        lang == 'ar' ? 'سلة المهملات فارغة' : 'Trash is empty',
                        style: GoogleFonts.cairo(fontSize: 18, color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        lang == 'ar'
                            ? 'الملفات المحذوفة تظل هنا لمدة 30 يوماً قبل حذفها نهائياً.'
                            : 'Deleted files remain here for 30 days before permanent deletion.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(fontSize: 12, color: Colors.white38),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _trashItems.length,
                  itemBuilder: (context, index) {
                    final item = _trashItems[index];
                    final daysLeft = 30 - DateTime.now().difference(item.deletedAt).inDays;

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: Material(
                        color: const Color(0xFF1B2030),
                        borderRadius: BorderRadius.circular(16),
                        clipBehavior: Clip.antiAlias,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: primaryColor.withValues(alpha: 0.15),
                              child: Icon(Icons.delete_sweep_rounded, color: primaryColor),
                            ),
                            title: Text(
                              item.fileName,
                              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              lang == 'ar'
                                  ? 'متبقي للحذف النهائي: $daysLeft يوم'
                                  : 'Days left: $daysLeft days',
                              style: GoogleFonts.cairo(fontSize: 11, color: Colors.orangeAccent),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.restore_from_trash_rounded, color: Colors.greenAccent),
                                  tooltip: lang == 'ar' ? 'استرجاع' : 'Restore',
                                  onPressed: () => _restoreItem(item),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                                  tooltip: lang == 'ar' ? 'حذف نهائي' : 'Delete Permanently',
                                  onPressed: () => _deleteItem(item),
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
