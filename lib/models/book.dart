class Book {
  String? id; // Changed from Isar's int Id to a Firestore String id

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

  ReadingStatus status;
  BookFormat format;

  // Constructor
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
      'status': status.name, // Saves 'planToRead' instead of a confusing number
      'format': format.name, // Saves 'paperback'
    };
  }

  // 2. Creates a Book object from Firestore data
  factory Book.fromMap(Map<String, dynamic> map, String documentId) {
    return Book(
      id: documentId, // We grab the ID straight from the Firestore document
      title: map['title'] as String?,
      author: map['author'] as String?,
      datePublished: map['datePublished'] as String?,
      edition: map['edition'] as String?,
      isbn: map['isbn'] as String?,
      totalPages: map['totalPages'] as int?,
      coverUrl: map['coverUrl'] as String?,
      // Safely turn the dynamic list back into a List<String>
      genres: (map['genres'] as List<dynamic>?)?.map((e) => e as String).toList(),
      currentPage: map['currentPage'] as int?,
      // Sometimes Firestore saves doubles as ints if they are whole numbers, so we parse it safely
      readPercentage: (map['readPercentage'] as num?)?.toDouble(),
      
      // Parse the strings back into your Enums safely
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