import 'dart:convert';
import 'package:http/http.dart' as http;
// 1. ADD THIS IMPORT:
import 'package:flutter_dotenv/flutter_dotenv.dart'; 

class GoogleBooksApi {
  // 2. CHANGE THIS LINE: 
  // It no longer has your real key. It securely fetches it from the hidden .env file!
  static String get _apiKey => dotenv.env['BOOKS_API_KEY'] ?? ''; 

  static Future<List<Map<String, dynamic>>> searchBooks(String query) async {
    print('🚨 --- SEARCH INITIATED --- 🚨');
    print('🚨 1. User searched for: "$query"');
    
    final url = Uri.https(
      'www.googleapis.com', 
      '/books/v1/volumes', 
      {
        'q': query,
        'key': _apiKey, // This now uses the safe, hidden key
      }
    );
    
    print('🚨 2. Contacting Google at: $url');
    
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      
      print('🚨 3. Google responded with Status Code: ${response.statusCode}');
      
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
      } else {
        print('🚨 ERROR: Google rejected the request! Status: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('🚨 NETWORK ERROR CATCH BLOCK TRIGGERED:');
      print('🚨 Details: $e');
      return [];
    }
  }
}