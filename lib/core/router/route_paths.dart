/// Centralized route path constants, referenced by the router and by
/// features that need to navigate (avoids magic strings scattered around).
class RoutePaths {
  RoutePaths._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';

  // Cerca flow.
  static const String welcome = '/welcome';
  static const String techDocs = '/tech/docs';
  static const String techProfile = '/tech/profile';
  static const String technicianJobs = '/tech/jobs';
  static const String technicianJobDetail = '/tech/jobs/detail';
  static const String home = '/home';
  static const String providerProfile = '/provider';
  static const String jobMode = '/job/mode';
  static const String jobDirect = '/job/direct';
  static const String jobBidding = '/job/bidding';
  static const String jobProjectQuote = '/job/project-quote';
  static const String jobFee = '/job/fee';
  static const String chat = '/chat';
  static const String clientChats = '/chats';
  static const String technicianChats = '/tech/chats';
  static const String tracking = '/tracking';
  static const String jobRating = '/job/rating';
  static const String clientAccount = '/account';

  /// The thread of one job; `?job=` keeps it reachable without relying on
  /// whichever job happens to be in the shared session.
  static String chatFor(String jobId) => '$chat?job=${Uri.encodeQueryComponent(jobId)}';
}
