import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart'; 

class GoogleBooksApi {

  static String get _apiKey => dotenv.env['BOOKS_API_KEY'] ?? ''; 

  static Future<List<Map<String, dynamic>>> searchBooks(String query) async {
    print('🚨 --- SEARCH INITIATED --- 🚨');
    print('🚨 1. User searched for: "$query"');
    
    final url = Uri.https(
      'www.googleapis.com', 
      '/books/v1/volumes', 
      {
        'q': query,
        'key': _apiKey, 
      }
    );
    
    print('🚨 2. Contacting Google at: $url');
    
    const maxRetries = 3; // 👈 NEW: Set a maximum number of attempts

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await http.get(url).timeout(const Duration(seconds: 10));
        
        print('🚨 3. Google responded with Status Code: ${response.statusCode} (Attempt $attempt)');
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final items = data['items'] as List<dynamic>?; 
          
          print('🚨 4. Number of books Google returned: ${items?.length ?? 0}');
          
          if (items == null) return []; 

          return items.map((item) {
            final volumeInfo = item['volumeInfo'] ?? {};
            return {
              'title': volumeInfo['title'] ?? 'Unknown Title',
              'author': (volumeInfo['authors'] as List<dynamic>?)?.join(', ') ?? 'Unknown Author',
              'totalPages': volumeInfo['pageCount'],
              'coverUrl': volumeInfo['imageLinks']?['thumbnail'], 
              'datePublished': volumeInfo['publishedDate'],
              'genres': (volumeInfo['categories'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
            };
          }).toList();
          
        } else if (response.statusCode == 429) {
          print('🚨 ERROR: Rate Limited! You are sending too many requests.');
          return [];
        } else if (response.statusCode >= 500 && response.statusCode <= 599) {
          // 👈 NEW: If Google has a server issue (like 503), catch it and retry!
          print('🚨 ERROR: Google Server Error (${response.statusCode}). Retrying...');
          
          if (attempt < maxRetries) {
            // Wait for a moment before trying again (1 second, then 2 seconds)
            await Future.delayed(Duration(seconds: attempt));
            continue; // Loop back and try again
          } else {
            print('🚨 ERROR: Failed after $maxRetries attempts.');
            return [];
          }
        } else {
          print('🚨 ERROR: Google rejected the request! Status: ${response.statusCode}');
          return [];
        }
      } catch (e) {
        print('🚨 NETWORK ERROR CATCH BLOCK TRIGGERED (Attempt $attempt):');
        print('🚨 Details: $e');
        
        // 👈 NEW: Also retry on network timeouts!
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt));
          continue; 
        } else {
          return [];
        }
      }
    }
    
    return []; // Failsafe return
  }
}