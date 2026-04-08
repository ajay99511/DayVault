/// Security questions pool for PIN recovery
/// 
/// These questions are used when users set up their PIN for the first time.
/// Users select 3 questions and provide answers that are securely hashed.
/// 
/// Best practices followed:
/// - Questions are common enough to be memorable
/// - Answers are case-insensitive (normalized to lowercase)
/// - Questions cover diverse life aspects to avoid overlap
class SecurityQuestions {
  static const List<String> allQuestions = [
    "What is the name of your first pet?",
    "What city were you born in?",
    "What is your mother's maiden name?",
    "What elementary school did you attend?",
    "What is the name of your favorite childhood friend?",
    "What was your childhood nickname?",
    "What is the make of your first car?",
    "What was the first movie you saw in a theater?",
    "What is your father's middle name?",
    "What street did you grow up on?",
    "What is the name of your favorite teacher?",
    "What was your dream job as a child?",
    "What is your favorite sports team?",
    "What is the name of your first boss?",
    "What city did you have your first date?",
    "What is your favorite book from childhood?",
    "What is the name of your sibling?",
    "What high school did you attend?",
    "What is your favorite food?",
    "What is the name of your favorite vacation spot?",
    "What was your first job?",
    "What is the name of the hospital where you were born?",
    "What is your favorite movie of all time?",
    "What is the name of your best friend in high school?",
    "What is your favorite musical artist or band?",
  ];

  /// Get a random subset of questions for selection
  static List<String> getRandomQuestions({int count = 5}) {
    final shuffled = List<String>.from(allQuestions)..shuffle();
    return shuffled.take(count).toList();
  }

  /// Normalize answer for consistent hashing
  static String normalizeAnswer(String answer) {
    return answer.trim().toLowerCase();
  }
}
