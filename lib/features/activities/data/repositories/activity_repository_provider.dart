import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/activity_repository.dart';
import 'mock_activity_repository.dart';

/// Only the mock exists so far; swap in the API implementation here later.
final activityRepositoryProvider = Provider<ActivityRepository>((ref) => MockActivityRepository());
