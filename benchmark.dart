import 'dart:async';

Future<void> simulateIO(int ms) async {
  await Future.delayed(Duration(milliseconds: ms));
}

Future<void> runSequential() async {
  final stopwatch = Stopwatch()..start();
  await simulateIO(50);
  await simulateIO(50);
  stopwatch.stop();
  print('Sequential time: ${stopwatch.elapsedMilliseconds} ms');
}

Future<void> runParallel() async {
  final stopwatch = Stopwatch()..start();
  await Future.wait([
    simulateIO(50),
    simulateIO(50),
  ]);
  stopwatch.stop();
  print('Parallel time: ${stopwatch.elapsedMilliseconds} ms');
}

void main() async {
  print('Running benchmarks...');
  print('---');
  await runSequential();
  await runParallel();
  print('---');
}
