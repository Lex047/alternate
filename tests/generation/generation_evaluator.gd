extends Node
class_name GenerationEvaluator


@export_category("Testing")
@export_range(1, 10000, 1, "or_greater") var test_count: int = 100
@export var auto_quit_on_finish: bool = true
const BASE_SEED: int = 100000


@onready var generator: LevelGenerator = $LevelGenerator


var current_run: int = 0
var current_start_time: int = 0

var successful_runs: int = 0
var failed_runs: int = 0

var results: Array[Dictionary] = []


func _ready() -> void:
	generator.generation_finished.connect(
		_on_generation_finished
	)

	generator.generation_failed.connect(
		_on_generation_failed
	)

	_start_next_test()


func _start_next_test() -> void:
	if current_run >= test_count:
		_finish_evaluation()
		return

	var test_seed: int = (
		BASE_SEED + current_run
	)

	generator.use_random_seed = false
	generator.generation_seed = test_seed

	current_start_time = Time.get_ticks_usec()

	generator.generate_level()


func _on_generation_finished(
	generation_seed: int
) -> void:
	var elapsed_usec: int = (
		Time.get_ticks_usec()
		- current_start_time
	)

	var elapsed_ms: float = (
		float(elapsed_usec) / 1000.0
	)

	var unresolved_sockets: int = (
		generator.chunk_tools.count_open_sockets(
			generator.context.placed_chunks
		)
	)

	results.append({
		"run": current_run + 1,
		"generation_seed": generation_seed,
		"success": true,
		"time_ms": elapsed_ms,
		"backtracks":
			generator.context.solver_backtracks,
		"physical_chunks":
			generator.context.placed_chunks.size(),
		"goal_route_length":
			generator.get_goal_route().size(),
		"unresolved_sockets":
			unresolved_sockets,
	})

	successful_runs += 1
	current_run += 1

	await get_tree().process_frame
	await get_tree().process_frame

	_start_next_test()


func _on_generation_failed() -> void:
	var elapsed_usec: int = (
		Time.get_ticks_usec()
		- current_start_time
	)

	results.append({
		"run": current_run + 1,
		"generation_seed": generator.generation_seed,
		"success": false,
		"time_ms":
			float(elapsed_usec) / 1000.0,
	})

	failed_runs += 1
	current_run += 1

	await get_tree().process_frame
	await get_tree().process_frame

	_start_next_test()


func _finish_evaluation() -> void:
	print("================================")
	print("GENERATION EVALUATION COMPLETE")
	print("================================")
	print("Runs: ", test_count)
	print("Successful: ", successful_runs)
	print("Failed: ", failed_runs)

	_print_summary()
	_save_results_csv()

	if auto_quit_on_finish:
		print("Exiting application...")
		get_tree().quit()


func _print_summary() -> void:
	if successful_runs == 0:
		return

	var total_time: float = 0.0
	var total_backtracks: int = 0
	var total_route_length: int = 0

	var min_time: float = INF
	var max_time: float = 0.0

	for result: Dictionary in results:
		if not result["success"]:
			continue

		var time_ms: float = result["time_ms"]

		total_time += time_ms
		total_backtracks += result["backtracks"]
		total_route_length += (
			result["goal_route_length"]
		)

		min_time = min(
			min_time,
			time_ms
		)

		max_time = max(
			max_time,
			time_ms
		)

	print(
		"Success rate: ",
		float(successful_runs)
			/ float(test_count)
			* 100.0,
		"%"
	)

	print(
		"Average generation time: ",
		total_time / successful_runs,
		" ms"
	)

	print(
		"Fastest generation: ",
		min_time,
		" ms"
	)

	print(
		"Slowest generation: ",
		max_time,
		" ms"
	)

	print(
		"Average backtracks: ",
		float(total_backtracks)
			/ successful_runs
	)

	print(
		"Average goal route length: ",
		float(total_route_length)
			/ successful_runs
	)


func _save_results_csv() -> void:
	var file := FileAccess.open(
		"user://generation_evaluation.csv",
		FileAccess.WRITE
	)

	if not file:
		push_error("Could not create evaluation CSV.")
		return

	# 1. Write Table Header
	file.store_line(
		"run,generation_seed,success,time_ms,"
		+ "backtracks,physical_chunks,"
		+ "goal_route_length,"
		+ "unresolved_sockets"
	)

	# 2. Write Per-Run Rows
	for result: Dictionary in results:
		file.store_line(
			"%s,%s,%s,%s,%s,%s,%s,%s"
			% [
				result.get("run", ""),
				result.get("generation_seed", ""),
				result.get("success", ""),
				result.get("time_ms", ""),
				result.get("backtracks", ""),
				result.get("physical_chunks", ""),
				result.get("goal_route_length", ""),
				result.get("unresolved_sockets", ""),
			]
		)

	# 3. Compute Summary Metrics
	if successful_runs > 0:
		var total_time: float = 0.0
		var total_backtracks: int = 0
		var total_route_length: int = 0
		var min_time: float = INF
		var max_time: float = 0.0

		for result: Dictionary in results:
			if not result["success"]:
				continue

			var time_ms: float = result["time_ms"]
			total_time += time_ms
			total_backtracks += result["backtracks"]
			total_route_length += result["goal_route_length"]
			min_time = min(min_time, time_ms)
			max_time = max(max_time, time_ms)

		var success_rate: float = (float(successful_runs) / float(test_count)) * 100.0
		var avg_time: float = total_time / float(successful_runs)
		var avg_backtracks: float = float(total_backtracks) / float(successful_runs)
		var avg_route_len: float = float(total_route_length) / float(successful_runs)

		# 4. Append Summary Section
		file.store_line("")
		file.store_line("--- SUMMARY STATISTICS ---")
		file.store_line("total_runs,%d" % test_count)
		file.store_line("successful_runs,%d" % successful_runs)
		file.store_line("failed_runs,%d" % failed_runs)
		file.store_line("success_rate_percent,%.2f" % success_rate)
		file.store_line("avg_time_ms,%.3f" % avg_time)
		file.store_line("min_time_ms,%.3f" % min_time)
		file.store_line("max_time_ms,%.3f" % max_time)
		file.store_line("avg_backtracks,%.2f" % avg_backtracks)
		file.store_line("avg_goal_route_length,%.2f" % avg_route_len)

	file.close()

	print(
		"Saved evaluation to: ",
		ProjectSettings.globalize_path(
			"user://generation_evaluation.csv"
		)
	)

	print(
		"Saved evaluation to: ",
		ProjectSettings.globalize_path(
			"user://generation_evaluation.csv"
		)
	)
