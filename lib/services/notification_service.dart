/// backend-free notification abstraction.
/// The production version will use the Node.js API + web/mobile push provider.
class NotificationService {
  Future<void> initializeForUser(String uid) async {}
}
