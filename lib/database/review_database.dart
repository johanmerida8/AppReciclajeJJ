import 'package:reciclaje_app/model/review.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewDatabase {
  final database = Supabase.instance.client.from('reviews'); 

  // create
  Future createReviews(Review newReview) async {
    await database.insert(newReview.toMap());
  }

  // read
  final stream = Supabase.instance.client.from('reviews').stream(
    primaryKey: ['idReview']
  ).map((data) => data.map((reviewMap) => Review.fromMap(reviewMap)).toList());

  // update
  Future updateReview(Review oldReview) async {
    await database.update(oldReview.toMap()).eq('idReview', oldReview.id!);
  }

  // delete
  Future deleteReview(Review review) async {
    await database.delete().eq('idReview', review.id!);
  }
}