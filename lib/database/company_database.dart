import 'package:reciclaje_app/model/company.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CompanyDatabase {
  final database = Supabase.instance.client.from('company');

  // create
  Future createCompany(Company newCompany) async {
    await database.insert(newCompany.toMap());
  }

  // read
  final stream = Supabase.instance.client.from('company').stream(
    primaryKey: ['idCompany']
  ).map((data) => data.map((companyMap) => Company.fromMap(companyMap)).toList());

  // update
  Future updateCompany(Company oldCompany) async {
    await database.update(oldCompany.toMap()).eq('idCompany', oldCompany.companyId!);
  }

  // delete
  Future deleteCompany(Company company) async {
    await database.delete().eq('idCompany', company.companyId!);
  }
}