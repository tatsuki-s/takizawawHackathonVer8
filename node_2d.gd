extends Node2D

@onready var players = [$Player1, $Player2]
@onready var positions = $Positions.get_children()
@onready var dice_label = $DiceLabel
@onready var status_label = $StatusLabel
@onready var turn_label = $TurnLabel
@onready var roll_button = $RollButton

var player_indices = [0, 0]    # 各プレイヤーのマス番号
var current_turn: int = 0      # 0 = プレイヤー1, 1 = Bot
var is_moving: bool = false    # 移動中フラグ

func _ready() -> void:
	randomize()
	# 初期配置
	for i in range(players.size()):
		players[i].position = positions[player_indices[i]].position
		status_label.text = "準備中"
	update_turn_label()
	# ボタンの接続
	roll_button.connect("pressed", Callable(self, "on_player_roll"))

func update_turn_label() -> void:
	var name = "プレイヤー1" if current_turn == 0 else "Bot"
	turn_label.text = "ターン: " + name

# --- 人間側ボタンが押されたとき ---
func on_player_roll() -> void:
	if is_moving or current_turn != 0:
		return
	# 非同期で処理を開始（中で await を使うので関数内部で非同期に動きます）
	do_roll()

# --- 人間のサイコロ実行（非同期）---
func do_roll() -> void:
	if is_moving:
		return
	is_moving = true
	roll_button.disabled = true
	var dice = randi() % 6 + 1
	dice_label.text = "出た目：" + str(dice)
	var game_over = await move_player_stepwise(current_turn, dice)
	if game_over:
		return
	# 次のターンがBotならBotの処理へ、そうでなければボタン再有効化
	if current_turn == 1:
		await get_tree().create_timer(0.5).timeout
		await do_bot_turn()
	else:
		roll_button.disabled = false

# --- Bot のターン処理（非同期）---
func do_bot_turn() -> void:
	if is_moving:
		return
	is_moving = true
	roll_button.disabled = true
	status_label.text = "Bot が考え中..."
	await get_tree().create_timer(0.6).timeout  # 思考演出
	var dice = randi() % 6 + 1
	dice_label.text = "出た目：" + str(dice)
	var game_over = await move_player_stepwise(1, dice)
	if game_over:
		return
	# 次が人間ならボタンを有効化
	if current_turn == 0:
		roll_button.disabled = false

# --- 1マスずつ順に移動する処理。移動後にターンを回し、
#     ゴールしたら true を返す（ゲーム終了） ---
func move_player_stepwise(player_id: int, steps: int) -> bool:
	status_label.text = "移動中"
	for i in range(steps):
		if player_indices[player_id] >= positions.size() - 1:
			break
		player_indices[player_id] += 1
		players[player_id].position = positions[player_indices[player_id]].position
		await get_tree().create_timer(0.3).timeout

	# ゴール判定
	if player_indices[player_id] == positions.size() - 1:
		var winner_name = "プレイヤー1" if player_id == 0 else "Bot"
		status_label.text = winner_name + " ゴール！"
		roll_button.disabled = true
		is_moving = false
		return true

	# 移動終了（ゴールでない）
	var current_pos_name = positions[player_indices[player_id]].name
	status_label.text = "停止中（" + current_pos_name + "）"
	current_turn = (current_turn + 1) % players.size()
	update_turn_label()
	is_moving = false
	return false
