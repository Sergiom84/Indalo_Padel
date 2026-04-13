import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class LoadingSpinner extends StatelessWidget {
  final double size;
  const LoadingSpinner({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          strokeWidth: 3,
        ),
      ),
    );
  }
}

class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.dark,
      body: Center(child: LoadingSpinner()),
    );
  }
}
