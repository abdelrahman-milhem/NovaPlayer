import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/vault_service.dart';
import '../utils/app_settings.dart';

class VaultProgressWidget extends StatelessWidget {
  const VaultProgressWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VaultProgressState?>(
      valueListenable: VaultService.instance.progressNotifier,
      builder: (context, state, child) {
        if (state == null) return const SizedBox.shrink();

        final String lang = AppSettings.languageNotifier.value;
        final bool isAr = lang == 'ar';
        final Color primaryColor = Theme.of(context).primaryColor;

        if (state.isMinimized) {
          return _buildMinimizedPill(context, state, isAr, primaryColor);
        } else {
          return _buildExpandedOverlay(context, state, isAr, primaryColor);
        }
      },
    );
  }

  Widget _buildMinimizedPill(
    BuildContext context,
    VaultProgressState state,
    bool isAr,
    Color primaryColor,
  ) {
    final int percent = (state.overallProgress * 100).clamp(0, 100).toInt();

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2C).withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primaryColor.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  value: state.isCompleted ? 1.0 : state.overallProgress,
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    state.isCompleted ? Colors.greenAccent : primaryColor,
                  ),
                  backgroundColor: Colors.white10,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.taskTitle,
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      state.isCompleted
                          ? (isAr ? 'تمت العملية بنجاح! ✅' : 'Completed successfully! ✅')
                          : '${state.currentFileName} ($percent%) • ⏱️ ${state.getFormattedEta(isAr)}',
                      style: GoogleFonts.cairo(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => VaultService.instance.toggleMinimize(),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.open_in_full_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedOverlay(
    BuildContext context,
    VaultProgressState state,
    bool isAr,
    Color primaryColor,
  ) {
    final int percent = (state.overallProgress * 100).clamp(0, 100).toInt();

    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.86,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2C),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: primaryColor.withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          state.operationType == VaultOperationType.hide
                              ? Icons.lock_clock
                              : Icons.unarchive_rounded,
                          color: primaryColor,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.taskTitle,
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!state.isCompleted)
                    TextButton.icon(
                      onPressed: () => VaultService.instance.toggleMinimize(),
                      icon: const Icon(Icons.visibility_off_outlined, size: 16, color: Colors.white70),
                      label: Text(
                        isAr ? 'إخفاء بالخلفية' : 'Minimize',
                        style: GoogleFonts.cairo(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        backgroundColor: Colors.white12,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (state.currentFileName.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${isAr ? "الملف الحالي: " : "Current File: "}${state.currentFileName}',
                    style: GoogleFonts.cairo(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: state.isCompleted ? 1.0 : state.overallProgress,
                  minHeight: 10,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    state.isCompleted ? Colors.greenAccent : primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${state.currentFileIndex} / ${state.totalFiles} ${isAr ? "ملفات" : "files"}',
                    style: GoogleFonts.cairo(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    state.isCompleted ? (isAr ? 'اكتمل ✅' : 'Done ✅') : '$percent%',
                    style: GoogleFonts.cairo(
                      color: state.isCompleted ? Colors.greenAccent : primaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (!state.isCompleted) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 14, color: primaryColor),
                    const SizedBox(width: 6),
                    Text(
                      state.getFormattedEta(isAr),
                      style: GoogleFonts.cairo(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
