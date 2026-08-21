import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum AppViewMode {
  cSourceCompiler,
  executableAnalyzer,
  theLab,
}

class AppModeSwitcher extends StatelessWidget {
  final AppViewMode currentMode;
  final ValueChanged<AppViewMode> onSelectMode;

  const AppModeSwitcher({
    super.key,
    required this.currentMode,
    required this.onSelectMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.base,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.surface0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabButton(
            title: 'C Source Compiler',
            icon: Icons.code,
            mode: AppViewMode.cSourceCompiler,
          ),
          _buildTabButton(
            title: 'Executable Analyzer',
            icon: Icons.biotech,
            mode: AppViewMode.executableAnalyzer,
          ),
          _buildTabButton(
            title: 'The Lab (Workbench)',
            icon: Icons.science,
            mode: AppViewMode.theLab,
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required IconData icon,
    required AppViewMode mode,
  }) {
    final isSelected = currentMode == mode;
    return InkWell(
      onTap: () => onSelectMode(mode),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surface0 : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? AppColors.peach : AppColors.subtext0),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? AppColors.peach : AppColors.subtext0,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
