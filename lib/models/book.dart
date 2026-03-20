import 'package:isar/isar.dart';
part 'book.g.dart';

@collection
class Book {
  Id id = Isar.autoIncrement;

  String? title;
  String? author;

  String? datePublished;
  String? edition;
  String? isbn;
  int? totalPages;
  
  String? coverUrl; 
  
  // NEW: A list to hold our genres/tags!
  List<String>? genres;

  int? currentPage;
  double? readPercentage;

  @enumerated
  ReadingStatus status = ReadingStatus.planToRead;

  @enumerated
  BookFormat format = BookFormat.paperback; 
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