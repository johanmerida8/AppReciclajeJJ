// ignore_for_file: avoid_print

import 'package:reciclaje_app/model/users.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UsersDatabase {
  // database --> users
  final database = Supabase.instance.client.from('users');

  // create
  Future createUser(Users newUser) async {
    try {
      await database.insert(newUser.toMap());
      print('User created successfully: ${newUser.email}');
    } catch (e) {
      print('Error creating user: $e');
      rethrow;
    }
  }

  // read all
  Stream<List<Users>> getAllUsers() {
    return database.stream(primaryKey: ['idUser']).map((maps) =>
        maps.map((map) => Users.fromMap(map)).toList());
  }

  // get user Id
  Future<Users?> getUserById(int? userID) async {
    if (userID == null) return null;

    try {
      final res = await database
          .select()
          .eq('idUser', userID)
          .maybeSingle();
      
      if (res == null) {
        print('No user found with ID: $userID');
        return null;
      }

      return Users.fromMap(res);
    } catch (e) {
      print('Error fetching user by ID: $e');
      return null;
    }
  }

  Future<Users?> getUserByEmail(String email) async {
    try {
      final res = await database
          .select()
          .eq('email', email)
          .maybeSingle();
      
      if (res == null) {
        print('No user found with email: $email');
        return null;
      }

      return Users.fromMap(res);
    } catch (e) {
      print('Error fetching user by email: $e');
      return null;
    }
  }

  // update user
  Future updateUser(Users oldUser) async {
    try {
      if (oldUser.id == null) {
        throw Exception('User ID is required for update');
      }

      await database.update(oldUser.toMap()).eq('idUser', oldUser.id!);
      print('User updated successfully: ${oldUser.email}');
    } catch (e) {
      print('Error updating user: $e');
      rethrow;
    }
  }

  // delete user
  Future deleteUser(Users user) async {
    try {
      if (user.id == null) {
        throw Exception('User ID is required for deletion');
      }

      final res = await database.update({'state': 0}).eq('idUser', user.id!);
      print('Usuario eliminada: $res');
      return res;
    } catch (e) {
      print('Error deleting user: $e');
      rethrow;
    }
  }
}