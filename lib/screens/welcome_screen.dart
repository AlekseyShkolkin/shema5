import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isLandscape = constraints.maxWidth > constraints.maxHeight;

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue.shade800,
                  Colors.blue.shade600,
                  Colors.white,
                ],
              ),
            ),
            child: Center(
              child: Card(
                color: Colors.white,
                margin: const EdgeInsets.all(20),
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: isLandscape
                      ? _buildLandscapeLayout(context)
                      : _buildPortraitLayout(context),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPortraitLayout(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 250,
          height: 250,
          child: Image.asset(
            'assets/images/logoWelcomeScreen.png',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'МНЕМОСХЕМА',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'тренажёр энергетика',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),

        // const Text(
        //   'Выберите режим работы приложения',
        //   style: TextStyle(
        //     fontSize: 16,
        //     color: Colors.black87,
        //   ),
        // ),
        const SizedBox(height: 32),

        _buildModeButton(
          context,
          icon: Icons.school,
          text: 'Тренажёр',
          color: Colors.blue,
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/scheme');
          },
        ),
        // const SizedBox(height: 16),
        // _buildModeButton(
        //   context,
        //   icon: Icons.work,
        //   text: 'Работа',
        //   color: Colors.grey,
        //   onPressed: () {
        //     ScaffoldMessenger.of(context).showSnackBar(
        //       SnackBar(
        //         content: Text('Режим "Работа" в разработке'),
        //         backgroundColor: Colors.orange.shade400,
        //       ),
        //     );
        //   },
        // ),
        // const SizedBox(height: 16),
        // _buildModeButton(
        //   context,
        //   icon: Icons.iso,
        //   text: 'ЭХЗ',
        //   color: Colors.grey,
        //   onPressed: () {
        //     ScaffoldMessenger.of(context).showSnackBar(
        //       SnackBar(
        //         content: Text('Режим "ЭХЗ" в разработке'),
        //         backgroundColor: Colors.orange.shade400,
        //       ),
        //     );
        //   },
        // ),
      ],
    );
  }

  Widget _buildLandscapeLayout(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 150,
          height: 150,
          child: Image.asset(
            'assets/images/logoWelcomeScreen.png',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 32),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Text(
                'МНЕМОСХЕМА - тренажёр энергетика',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              // const Text(
              //   'Выберите режим работы приложения',
              //   style: TextStyle(
              //     fontSize: 14,
              //     color: Colors.black87,
              //   ),
              // ),
              const SizedBox(height: 24),

              _buildModeButton(
                context,
                icon: Icons.school,
                text: 'Тренажёр',
                color: Colors.blue,
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/scheme');
                },
              ),
              // const SizedBox(height: 12),
              // _buildModeButton(
              //   context,
              //   icon: Icons.work,
              //   text: 'Работа',
              //   color: Colors.grey,
              //   onPressed: () {
              //     ScaffoldMessenger.of(context).showSnackBar(
              //       SnackBar(
              //         content: Text('Режим "Работа" в разработке'),
              //         backgroundColor: Colors.orange.shade400,
              //       ),
              //     );
              //   },
              // ),
              // const SizedBox(height: 12),
              // _buildModeButton(
              //   context,
              //   icon: Icons.iso,
              //   text: 'ЭХЗ',
              //   color: Colors.grey,
              //   onPressed: () {
              //     ScaffoldMessenger.of(context).showSnackBar(
              //       SnackBar(
              //         content: Text('Режим "ЭХЗ" в разработке'),
              //         backgroundColor: Colors.orange.shade400,
              //       ),
              //     );
              //   },
              // ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModeButton(
    BuildContext context, {
    required IconData icon,
    required String text,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
