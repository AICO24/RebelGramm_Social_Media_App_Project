import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reel_model.dart';
import 'package:uuid/uuid.dart';

class ReelService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createReel(ReelModel reel) async {
    final id = Uuid().v4();
    final data = reel.toMap();
    data['timestamp'] = Timestamp.fromDate(reel.timestamp);
    await _db.collection('reels').doc(id).set(data);
  }

  Stream<List<ReelModel>> fetchReels() {
    return _db.collection('reels')
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
        .map((doc) => ReelModel.fromMap(doc.data(), doc.id))
        .toList());
  }
}
