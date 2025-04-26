import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/recent_scan.dart';

class FirestoreService {
  final CollectionReference _scans =
      FirebaseFirestore.instance.collection('recent_scans');

  Future<List<RecentScan>> getRecentScans() async {
    try {
      final snapshot =
          await _scans.orderBy('timestamp', descending: true).get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return RecentScan.fromJson(data, id: doc.id);
      }).toList();
    } catch (e) {
      print('Error getting recent scans: $e');
      return [];
    }
  }

  Future<void> addScan(RecentScan scan) async {
    try {
      await _scans.add(scan.toJson());
    } catch (e) {
      print('Error adding scan: $e');
      throw Exception('Failed to add scan: $e');
    }
  }

  Future<void> deleteScan(String id) async {
    try {
      await _scans.doc(id).delete();
    } catch (e) {
      print('Error deleting scan: $e');
      throw Exception('Failed to delete scan: $e');
    }
  }

  Future<void> clearScans() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final snapshot = await _scans.get();

      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      print('Error clearing scans: $e');
      throw Exception('Failed to clear scans: $e');
    }
  }

  Future<void> addScans(List<RecentScan> scans) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      for (var scan in scans) {
        final docRef = _scans.doc();
        batch.set(docRef, scan.toJson());
      }

      await batch.commit();
    } catch (e) {
      print('Error adding multiple scans: $e');
      throw Exception('Failed to add multiple scans: $e');
    }
  }
}
