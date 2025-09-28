extends Node2D

@onready var players = [$Player1, $Player2]
@onready var positions = $Positions.get_children()
@onready var dice_label = $DiceLabel
@onready var status_label = $StatusLabel
@onready var turn_label = $TurnLabel
@onready var roll_button = $RollButton
@onready var player_position = [$Player1Status/Position, $Player2Status/Position]
@onready var player_picture = [$Player1Status/Picture, $Player2Status/Picture]
@onready var starButton = $StartButton
@onready var camera = $Camera2D

var no_image = preload("res://pictures/no_image_yoko.jpg")

var player_indices = [0, 0]    # 各プレイヤーのマス番号
var current_turn: int = 0      # 0 = プレイヤー1, 1 = Bot
var is_moving: bool = false    # 移動中フラグ

func _ready() -> void:
	randomize()
	# 初期配置
	for i in range(players.size()):
		players[i].position = positions[player_indices[i]].position
		status_label.text = "準備中"
	var default_text = positions[0].get_node("description").text
	var default_picture = positions[0].get_node("picture").texture
	player_position[0].text = default_text
	player_position[1].text = default_text
	player_picture[0].texture = default_picture
	player_picture[1].texture = default_picture
	
	#if(not camera.global_position == Vector2(0, -720)):

	
	player_indices = [0, 0]    # 各プレイヤーのマス番号
	current_turn = 0      # 0 = プレイヤー1, 1 = Bot
	is_moving = false
	roll_button.text = "さいころを\nまわす"
	
	for i in players:
		i.position = positions[0].position
	
	update_turn_label()
	# ボタンの接続
	roll_button.connect("pressed", Callable(self, "on_player_roll"))

func update_turn_label() -> void:
	var name = "You" if current_turn == 0 else "Bot"
	turn_label.text = "ターン: " + name

# --- 人間側ボタンが押されたとき ---
func on_player_roll() -> void:
	if is_moving:
		return
	
	if roll_button.text == "もう一度プレイ":
		_ready()
		return
	
	if current_turn != 0:
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
	$diceSE.play()
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
	status_label.text = "Botのターン"
	await get_tree().create_timer(0.6).timeout 
	var dice = randi() % 6 + 1
	dice_label.text = "出た目：" + str(dice)
	$diceSE.play()
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
	# 移動終了（ゴールでない）
	for i in range(steps):
		if player_indices[player_id] >= positions.size() - 1:
			break
		$moveSE.play()
		player_indices[player_id] += 1
		players[player_id].position = positions[player_indices[player_id]].position
		player_position[player_id].text = str(positions[player_indices[player_id]].get_node("description").text)		
		player_picture[player_id].texture = (positions[player_indices[player_id]].get_node("picture").texture if positions[player_indices[player_id]].get_node("picture").texture else load("res://pictures/no_image_yoko.jpg"))
		await get_tree().create_timer(0.3).timeout

	# ゴール判定
	if player_indices[player_id] == positions.size() - 1:
		var winner_name = "You" if player_id == 0 else "Bot"
		status_label.text = winner_name + " ゴール！"
		roll_button.text = "もう一度プレイ"
		roll_button.disabled = false
		is_moving = false
		return true
		
	var current_pos_name = positions[player_indices[player_id]].name
	status_label.text = "停止中（" + current_pos_name + "）"
	current_turn = (current_turn + 1) % players.size()
	update_turn_label()
	is_moving = false
	return false


func _on_start_button_pressed() -> void:
	#print("カメラの global_position: ", camera.global_position)
	camera.offset = Vector2(0, 0)
	$titleBGM.stop()
	$playBGM.play()
