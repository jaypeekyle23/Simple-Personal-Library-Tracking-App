import 'dart:convert';
import 'package:http/http.dart' as http;

class GoogleBooksApi {
  static Future<List<Map<String, dynamic>>> searchBooks(String query) async {
    print('🚨 --- SEARCH INITIATED --- 🚨');
    print('🚨 1. User searched for: "$query"');
    
    final formattedQuery = query.replaceAll(' ', '+');
    final url = Uri.parse('https://www.googleapis.com/books/v1/volumes?q=$formattedQuery');
    
    print('🚨 2. Contacting Google at: $url');
    
    try {
      final response = await http.get(url);
      
      print('🚨 3. Google responded with Status Code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List<dynamic>?; 
        
        print('🚨 4. Number of books Google returned: ${items?.length ?? 0}');
        
        if (items == null) {
          print('🚨 5. Google sent back 200 OK, but the items list was null!');
          return []; 
        }

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
        
      } else {
        print('🚨 ERROR: Google rejected the request!');
        print('🚨 Reason: ${response.body}'); // This will tell us if we are rate-limited or blocked
        return [];
      }
    } catch (e) {
      print('🚨 NETWORK ERROR CATCH BLOCK TRIGGERED:');
      print('🚨 $e');
      return [];
    }
  }
}