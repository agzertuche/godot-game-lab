extends Node2D

const MAX_PLOTS := 6
const WIN_TOTAL := 500.0
const MANUAL_COINS := 1.0
const BASE_PLOT_OUTPUT := 1.0
const PLOT_BASE_COST := 10.0
const WATER_BASE_COST := 25.0

var coins := 0.0
var total_earned := 0.0
var plots_owned := 1
var watering_level := 1
var game_won := false

@onready var coins_label: Label = $CanvasLayer/CoinsLabel
@onready var total_label: Label = $CanvasLayer/TotalLabel
@onready var production_label: Label = $CanvasLayer/ProductionLabel
@onready var plots_label: Label = $CanvasLayer/PlotsLabel
@onready var watering_label: Label = $CanvasLayer/WateringLabel
@onready var status_label: Label = $CanvasLayer/StatusLabel
@onready var tend_button: Button = $CanvasLayer/TendButton
@onready var buy_plot_button: Button = $CanvasLayer/BuyPlotButton
@onready var water_button: Button = $CanvasLayer/WaterButton
@onready var income_timer: Timer = $IncomeTimer
@onready var plots_root: Node2D = $Plots


func _ready() -> void:
	tend_button.pressed.connect(_on_tend_pressed)
	buy_plot_button.pressed.connect(_on_buy_plot_pressed)
	water_button.pressed.connect(_on_water_pressed)
	income_timer.timeout.connect(_on_income_timer_timeout)
	_update_ui()


func _input(event: InputEvent) -> void:
	if game_won and event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


func _on_tend_pressed() -> void:
	if game_won:
		return

	_add_coins(MANUAL_COINS)
	status_label.text = "You tended the garden."


func _on_buy_plot_pressed() -> void:
	if game_won:
		return

	var cost := _plot_cost()
	if plots_owned >= MAX_PLOTS or coins < cost:
		return

	coins -= cost
	plots_owned += 1
	status_label.text = "A new plot is growing."
	_update_ui()


func _on_water_pressed() -> void:
	if game_won:
		return

	var cost := _water_cost()
	if coins < cost:
		return

	coins -= cost
	watering_level += 1
	status_label.text = "Watering improved."
	_update_ui()


func _on_income_timer_timeout() -> void:
	if game_won:
		return

	_add_coins(_coins_per_second())


func _add_coins(amount: float) -> void:
	coins += amount
	total_earned += amount
	if total_earned >= WIN_TOTAL:
		_win_game()
	else:
		_update_ui()


func _coins_per_second() -> float:
	return plots_owned * BASE_PLOT_OUTPUT * watering_level


func _plot_cost() -> float:
	return PLOT_BASE_COST + float(plots_owned - 1) * 12.0


func _water_cost() -> float:
	return WATER_BASE_COST + float(watering_level - 1) * 20.0


func _win_game() -> void:
	game_won = true
	income_timer.stop()
	status_label.text = "Garden complete! Press R to restart."
	_update_ui()


func _update_ui() -> void:
	coins_label.text = "Coins: %d" % floori(coins)
	total_label.text = "Total earned: %d / %d" % [floori(total_earned), int(WIN_TOTAL)]
	production_label.text = "Production: %d coins/sec" % floori(_coins_per_second())
	plots_label.text = "Plots: %d / %d" % [plots_owned, MAX_PLOTS]
	watering_label.text = "Watering: level %d" % watering_level

	tend_button.disabled = game_won
	buy_plot_button.text = "Buy plot (%d)" % floori(_plot_cost())
	buy_plot_button.disabled = game_won or plots_owned >= MAX_PLOTS or coins < _plot_cost()
	water_button.text = "Improve watering (%d)" % floori(_water_cost())
	water_button.disabled = game_won or coins < _water_cost()

	_update_plots()


func _update_plots() -> void:
	for index in range(plots_root.get_child_count()):
		var plot := plots_root.get_child(index) as Polygon2D
		if plot == null:
			continue

		if index < plots_owned:
			plot.color = Color(0.38, 0.77, 0.39, 1)
		else:
			plot.color = Color(0.31, 0.22, 0.15, 1)
