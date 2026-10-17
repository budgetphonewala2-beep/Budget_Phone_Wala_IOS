import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_exception.dart';

/// The only door to the backend. Repositories depend on this interface so tests can use a fake.
/// All failures are converted to [AppException] (user-safe messages, stable codes).
abstract class Gateway {
  String? get userId;
  String? get userEmail;
  Stream<String?> get userIdChanges;

  Future<dynamic> rpc(String fn, [Map<String, dynamic>? params]);

  Future<List<Map<String, dynamic>>> select(
    String table, {
    String columns = '*',
    Map<String, Object>? eq,
    String? orderBy,
    bool ascending = true,
    int? limit,
  });

  Future<void> insert(String table, Map<String, dynamic> row);
  Future<void> updateRow(String table, Map<String, dynamic> values, Map<String, Object> eq);
  Future<void> deleteRow(String table, Map<String, Object> eq);

  /// Calls an Edge Function with the signed-in user's JWT. Returns the decoded JSON body.
  Future<Map<String, dynamic>> invoke(String fn, Map<String, dynamic> body, {Map<String, String>? headers});

  Future<void> uploadBytes(String bucket, String path, Uint8List bytes, String contentType);
}

class SupabaseGateway implements Gateway {
  SupabaseGateway(this._c);
  final SupabaseClient _c;

  @override
  String? get userId => _c.auth.currentUser?.id;
  @override
  String? get userEmail => _c.auth.currentUser?.email;
  @override
  Stream<String?> get userIdChanges => _c.auth.onAuthStateChange.map((s) => s.session?.user.id).distinct();

  Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f().timeout(const Duration(seconds: 30));
    } catch (e) {
      throw toAppException(e);
    }
  }

  @override
  Future<dynamic> rpc(String fn, [Map<String, dynamic>? params]) => _guard(() => _c.rpc(fn, params: params));

  @override
  Future<List<Map<String, dynamic>>> select(String table,
      {String columns = '*', Map<String, Object>? eq, String? orderBy, bool ascending = true, int? limit}) {
    return _guard(() async {
      PostgrestFilterBuilder<List<Map<String, dynamic>>> q = _c.from(table).select(columns);
      eq?.forEach((k, v) => q = q.eq(k, v));
      PostgrestTransformBuilder<List<Map<String, dynamic>>> t = q;
      if (orderBy != null) t = t.order(orderBy, ascending: ascending);
      if (limit != null) t = t.limit(limit);
      return await t;
    });
  }

  @override
  Future<void> insert(String table, Map<String, dynamic> row) => _guard(() async {
        await _c.from(table).insert(row);
      });

  @override
  Future<void> updateRow(String table, Map<String, dynamic> values, Map<String, Object> eq) => _guard(() async {
        var q = _c.from(table).update(values);
        eq.forEach((k, v) => q = q.eq(k, v));
        await q;
      });

  @override
  Future<void> deleteRow(String table, Map<String, Object> eq) => _guard(() async {
        var q = _c.from(table).delete();
        eq.forEach((k, v) => q = q.eq(k, v));
        await q;
      });

  @override
  Future<Map<String, dynamic>> invoke(String fn, Map<String, dynamic> body, {Map<String, String>? headers}) => _guard(() async {
        final r = await _c.functions.invoke(fn, body: body, headers: headers);
        final d = r.data;
        if (d is Map) return Map<String, dynamic>.from(d);
        return <String, dynamic>{};
      });

  @override
  Future<void> uploadBytes(String bucket, String path, Uint8List bytes, String contentType) => _guard(() async {
        await _c.storage.from(bucket).uploadBinary(path, bytes, fileOptions: FileOptions(contentType: contentType));
      });
}
