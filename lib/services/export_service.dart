import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_saver/file_saver.dart';
import 'package:file_picker/file_picker.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 

import '../models/book.dart';

class ExportService {
  
  // --- HELPER METHOD: Generates the CSV string ---
  static Future<String> _generateCsvString() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';

    // Fetch books from Firestore instead of Isar
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('books')
        .get();

    final books = snapshot.docs.map((doc) => Book.fromMap(doc.data(), doc.id)).toList();

    List<List<dynamic>> rows = [];
    rows.add([
      'Title', 'Author', 'Format', 'Status', 'Original Pub. Date',
      'Edition', 'ISBN', 'Total Pages', 'Current Page',
    ]);

    for (var book in books) {
      rows.add([
        book.title ?? '',
        book.author ?? '',
        book.format.displayName,
        book.status.displayName,
        book.datePublished ?? '',
        book.edition ?? '',
        book.isbn ?? '',
        book.totalPages ?? '',
        book.currentPage ?? '',
      ]);
    }

    // FIX: Removed 'const' here
    return CsvCodec().encode(rows);
  }

  // --- OPTION 1: Share Menu ---
  static Future<void> shareLibraryCsv() async {
    String csvData = await _generateCsvString();
    if (csvData.isEmpty) return;

    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/my_library_inventory.csv';
    final file = File(path);
    await file.writeAsString(csvData);

    await Share.shareXFiles([XFile(path)], text: 'Here is my latest library inventory backup!');
  }

  // --- OPTION 2: Download Locally ---
  static Future<void> downloadLibraryCsvLocally() async {
    String csvData = await _generateCsvString();
    if (csvData.isEmpty) return;
    
    Uint8List bytes = Uint8List.fromList(utf8.encode(csvData));
    
    await FileSaver.instance.saveFile(
      name: 'my_library_inventory',
      bytes: bytes,
      fileExtension: 'csv',
      mimeType: MimeType.custom,
      customMimeType: 'text/csv',
    );
  }

  // --- OPTION 3: Import CSV (Restore Data) ---
  static Future<bool> importLibraryCsv() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        
        final csvString = await file.readAsString();
        
        // FIX: Removed 'const' here
        List<List<dynamic>> csvTable = CsvCodec().decode(csvString);
        
        if (csvTable.isEmpty || csvTable.length <= 1) return false;

        final booksRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('books');

        // Use a Firestore Batch to upload all the books efficiently
        final batch = FirebaseFirestore.instance.batch();
        
        for (int i = 1; i < csvTable.length; i++) {
          final row = csvTable[i];
          if (row.length < 9) continue; 
          
          final book = Book()
            ..title = row[0].toString()
            ..author = row[1].toString()
            ..format = _parseFormat(row[2].toString())
            ..status = _parseStatus(row[3].toString())
            ..datePublished = row[4].toString()
            ..edition = row[5].toString()
            ..isbn = row[6].toString()
            ..totalPages = int.tryParse(row[7].toString())
            ..currentPage = int.tryParse(row[8].toString());

          // Create a new document reference and add it to the batch
          final newDocRef = booksRef.doc(); 
          batch.set(newDocRef, book.toMap());
        }

        // Commit all the books to the cloud at once!
        await batch.commit();

        return true; 
      }
      return false; 
    } catch (e) {
      print("Error importing CSV: $e");
      return false;
    }
  }

  // --- HELPER METHODS FOR IMPORTING ENUMS ---
  static BookFormat _parseFormat(String name) {
    switch (name) {
      case 'Mass Market': return BookFormat.massMarket;
      case 'Paperback': return BookFormat.paperback;
      case 'Hardbound': return BookFormat.hardbound;
      case 'eBook': return BookFormat.ebook;
      case 'Audiobook': return BookFormat.audiobook;
      default: return BookFormat.other;
    }
  }

  static ReadingStatus _parseStatus(String name) {
    switch (name) {
      case 'Read': return ReadingStatus.read;
      case 'Currently Reading': return ReadingStatus.currentlyReading;
      case 'Plan to Read': return ReadingStatus.planToRead;
      case 'Borrowed': return ReadingStatus.borrowed;
      case 'Abandoned': return ReadingStatus.abandoned;
      case 'Did Not Finish': return ReadingStatus.didNotFinish;
      default: return ReadingStatus.planToRead;
    }
  }
}