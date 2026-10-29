import 'package:supabase_flutter/supabase_flutter.dart';
class ConversationService {
  static Future<String> open(String otherUserId) async {
    final result = await Supabase.instance.client.rpc('app_open_conversation', params: {'other_user': otherUserId});
    return result.toString();
  }
}
