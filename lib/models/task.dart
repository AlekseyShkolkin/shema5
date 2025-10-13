class TrainingTask {
  final String id;
  final String title;
  final String description;
  final List<TaskStep> steps;
  final int maxScore;
  final String difficulty;

  TrainingTask({
    required this.id,
    required this.title,
    required this.description,
    required this.steps,
    this.maxScore = 5,
    this.difficulty = 'medium',
  });
}

class TaskStep {
  final String apparatusId;
  final String requiredAction;
  final String requiredState;
  final int order;
  final String description;
  final String safetyNote;
  final String? requiredSafetyMeasure;

  TaskStep({
    required this.apparatusId,
    required this.requiredAction,
    required this.requiredState,
    required this.order,
    required this.description,
    required this.safetyNote,
    this.requiredSafetyMeasure, // Может быть null для обычных действий
  });
}

class TaskResult {
  final int maxScore;
  final int earnedScore;
  final List<String> correctSteps;
  final List<String> mistakes;
  final List<String> safetyViolations;
  final bool isCompleted;
  final int totalSteps;
  final int completedCorrectly;

  TaskResult({
    required this.maxScore,
    required this.earnedScore,
    required this.correctSteps,
    required this.mistakes,
    required this.safetyViolations,
    required this.isCompleted,
    required this.totalSteps,
    required this.completedCorrectly,
  });

  // Метод для расчета процента выполнения
  double get percentage => totalSteps > 0 ? (earnedScore / maxScore) * 100 : 0;
}
