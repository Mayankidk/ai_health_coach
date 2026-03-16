import 'dart:io';
import 'dart:convert';

void main() async {
  print('--- Gemini Model Discovery Tool (Pure Dart) ---');

  // 1. Manually parse .env to avoid package:flutter conflicts
  String? apiKey;
  try {
    final envFile = File('.env');
    if (await envFile.exists()) {
      final lines = await envFile.readAsLines();
      for (var line in lines) {
        if (line.trim().startsWith('GEMINI_API_KEY=')) {
          apiKey = line.split('=')[1].trim();
          break;
        }
      }
    }
  } catch (e) {
    print('Error reading .env: $e');
  }

  if (apiKey == null) {
    print('Error: GEMINI_API_KEY not found in .env. Please ensure it is set.');
    return;
  }

  final client = HttpClient();
  final baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  print('Fetching models from Google AI...');

  try {
    // 2. List Models
    final request = await client.getUrl(Uri.parse('$baseUrl?key=$apiKey'));
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    
    if (response.statusCode != 200) {
      print('API Error: ${response.statusCode}');
      print(responseBody);
      return;
    }

    final data = jsonDecode(responseBody);
    final List models = data['models'] ?? [];
    List<String> compatibleModels = [];

    print('\nCompatible Models:');
    for (var model in models) {
      final name = model['name'] as String;
      final shortName = name.split('/').last;
      final methods = List<String>.from(model['supportedGenerationMethods'] ?? []);

      if (methods.contains('generateContent')) {
        compatibleModels.add(shortName);
        print(' - $shortName [${model['displayName']}]');
      }
    }

    // 3. Health Check (Ping)
    print('\nVerifying models with a test message:');
    String? recommendedFlash;

    for (var modelName in compatibleModels) {
      stdout.write(' Testing $modelName... ');
      try {
        final pingUri = Uri.parse('$baseUrl/$modelName:generateContent?key=$apiKey');
        final pingRequest = await client.postUrl(pingUri);
        pingRequest.headers.contentType = ContentType.json;
        pingRequest.write(jsonEncode({
          'contents': [{'parts': [{'text': 'hi'}]}]
        }));
        
        final pingResponse = await pingRequest.close();
        if (pingResponse.statusCode == 200) {
          print('[OK]');
          if (recommendedFlash == null && modelName.contains('flash')) {
            recommendedFlash = modelName;
          }
        } else {
          final errBody = await pingResponse.transform(utf8.decoder).join();
          print('[FAIL: ${pingResponse.statusCode}]');
          // print('   Reason: $errBody');
        }
      } catch (e) {
        print('[ERROR: $e]');
      }
    }

    print('\n' + '=' * 40);
    if (recommendedFlash != null) {
      print('RECOMMENDED LIGHT MODEL: "$recommendedFlash"');
      print('You should use this for fast, low-latency health coaching.');
    } else if (compatibleModels.isNotEmpty) {
      print('RECOMMENDED MODEL: "${compatibleModels.first}"');
    }
    print('=' * 40);

  } catch (e) {
    print('\nGeneral Error: $e');
  } finally {
    client.close();
  }
}
