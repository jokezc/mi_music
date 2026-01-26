import 'package:flutter/material.dart';
import 'package:mi_music/core/theme/app_colors.dart';
import 'package:mi_music/presentation/pages/settings/disclaimer_page.dart';
import 'package:mi_music/presentation/pages/settings/privacy_policy_page.dart';

/// 隐私协议授权对话框
/// 首次打开应用时显示，用户必须同意后才能继续使用
class PrivacyAgreementDialog extends StatelessWidget {
  final VoidCallback onAgree;
  final VoidCallback? onDisagree;

  const PrivacyAgreementDialog({
    super.key,
    required this.onAgree,
    this.onDisagree,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: false, // 禁止返回键关闭
      child: AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.privacy_tip_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('隐私协议'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '欢迎使用风花雪乐！',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                '我们非常重视您的隐私保护。为了向您提供更好的服务体验，我们需要收集以下信息：',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              _buildPrivacyItem('设备信息', '用于区分不同设备，不包含任何个人身份信息'),
              _buildPrivacyItem('使用统计', '用于了解应用使用情况，帮助改进产品功能'),
              _buildPrivacyItem('错误信息', '用于定位和修复应用问题，提升稳定性'),
              _buildPrivacyItem('友盟统计服务', '集成了友盟统计SDK，用于应用数据分析和错误监控'),
              const SizedBox(height: 16),
              const Text(
                '我们承诺：',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildPromiseItem('不会收集您的登录信息（用户名、密码等）'),
              _buildPromiseItem('不会收集您的音乐内容和个人偏好'),
              _buildPromiseItem('所有数据仅用于产品改进，不会用于其他目的'),
              _buildPromiseItem('友盟数据仅用于统计分析，遵循友盟隐私政策'),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () async {
                  // 使用 Navigator.push 打开新页面，保持弹窗打开
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const PrivacyPolicyPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.description_rounded, size: 16),
                label: const Text('查看完整隐私协议'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  // 使用 Navigator.push 打开新页面，保持弹窗打开
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const DisclaimerPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.gavel_rounded, size: 16),
                label: const Text('查看免责声明'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '继续使用即表示您已充分理解并同意上述隐私政策和免责声明。',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
        actions: [
          // 不同意按钮（可选，如果提供则显示）
          if (onDisagree != null)
            TextButton(
              onPressed: onDisagree,
              child: const Text('不同意'),
            ),
          // 同意按钮
          ElevatedButton(
            onPressed: onAgree,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('同意并继续'),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromiseItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_rounded, size: 14, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
