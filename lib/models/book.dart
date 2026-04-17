import 'package:cloud_firestore/cloud_firestore.dart';

class Book {
  String? id; 
  String? title;
  String? author;

  String? datePublished;
  String? edition;
  String? isbn;
  int? totalPages;
  
  String? coverUrl; 
  
  List<String>? genres;

  int? currentPage;
  double? readPercentage;

  // --- NEW FIELDS FOR REVIEWS ---
  int? rating;    // 1-10 rating
  String? review; // The text review
  // ------------------------------

  ReadingStatus status;
  BookFormat format;

  Book({
    this.id,
    this.title,
    this.author,
    this.datePublished,
    this.edition,
    this.isbn,
    this.totalPages,
    this.coverUrl,
    this.genres,
    this.currentPage,
    this.readPercentage,
    this.rating, // Added to constructor
    this.review, // Added to constructor
    this.status = ReadingStatus.planToRead,
    this.format = BookFormat.paperback,
  });

  // 1. Converts your Book object into a Map for Firestore to save
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'author': author,
      'datePublished': datePublished,
      'edition': edition,
      'isbn': isbn,
      'totalPages': totalPages,
      'coverUrl': coverUrl,
      'genres': genres,
      'currentPage': currentPage,
      'readPercentage': readPercentage,
      'rating': rating, // Added to Map
      'review': review, // Added to Map
      'status': status.name, 
      'format': format.name, 
    };
  }

  // 2. Creates a Book object from Firestore data
  factory Book.fromMap(Map<String, dynamic> map, String documentId) {
    return Book(
      id: documentId, 
      title: map['title'] as String?,
      author: map['author'] as String?,
      datePublished: map['datePublished'] as String?,
      edition: map['edition'] as String?,
      isbn: map['isbn'] as String?,
      totalPages: map['totalPages'] as int?,
      coverUrl: map['coverUrl'] as String?,
      genres: (map['genres'] as List<dynamic>?)?.map((e) => e as String).toList(),
      currentPage: map['currentPage'] as int?,
      readPercentage: (map['readPercentage'] as num?)?.toDouble(),
      
      // Load the new fields safely
      rating: map['rating'] as int?,
      review: map['review'] as String?,
      
      status: ReadingStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ReadingStatus.planToRead,
      ),
      format: BookFormat.values.firstWhere(
        (e) => e.name == map['format'],
        orElse: () => BookFormat.paperback,
      ),
    );
  }
}

enum ReadingStatus {
  read,
  currentlyReading,
  planToRead,
  borrowed,
  abandoned,
  didNotFinish
}

extension ReadingStatusExtension on ReadingStatus {
  String get displayName {
    switch (this) {
      case ReadingStatus.read: return 'Read';
      case ReadingStatus.currentlyReading: return 'Currently Reading';
      case ReadingStatus.planToRead: return 'Plan to Read';
      case ReadingStatus.borrowed: return 'Borrowed';
      case ReadingStatus.abandoned: return 'Abandoned';
      case ReadingStatus.didNotFinish: return 'Did Not Finish';
    }
  }
}

enum BookFormat {
  massMarket,
  paperback,
  hardbound,
  ebook,
  audiobook,
  other
}

extension BookFormatExtension on BookFormat {
  String get displayName {
    switch (this) {
      case BookFormat.massMarket: return 'Mass Market';
      case BookFormat.paperback: return 'Paperback';
      case BookFormat.hardbound: return 'Hardbound';
      case BookFormat.ebook: return 'eBook';
      case BookFormat.audiobook: return 'Audiobook';
      case BookFormat.other: return 'Other';
    }
  }
}