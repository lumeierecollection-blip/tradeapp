import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auto_refresh_service.dart';

class SignalsScreen extends StatelessWidget {
  const SignalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<AutoRefreshService>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (service.latestSignals != null) ...[
              Text(
                'Latest Signal: ${service.latestSignals!['signals'][0]['signal']}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Confidence: ${service.latestSignals!['signals'][0]['confidence']}',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                'Price: \$${service.latestSignals!['signals'][0]['price']}',
                style: const TextStyle(fontSize: 16),
              ),
            ] else ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
              const Text('Loading signals...'),
            ],
          ],
        ),
      ),
    );
  }
}