extends Node2D
## Original playable Cloud Climb vertical-platform prototype.
const WIDTH := 1280.0
const HEIGHT := 720.0
const GRAVITY := 1650.0
const SPEED := 340.0
const JUMP := -660.0
var player := Vector2(120, 550)
var velocity := Vector2.ZERO
var platforms: Array[Rect2] = []
var coins: Array[Vector2] = []
var score := 0
var stage := 1
var hearts := 3
var on_ground := false
var touch_direction := 0.0
var jump_requested := false
var camera_offset := 0.0
var hud: Label
var buttons: Array[Button] = []

func _ready() -> void:
    randomize()
    _create_stage()
    var layer := CanvasLayer.new()
    add_child(layer)
    hud = Label.new()
    hud.position = Vector2(30, 20)
    hud.add_theme_font_size_override("font_size", 30)
    layer.add_child(hud)
    _touch_button(layer, "◀", Vector2(35, 575), func(): touch_direction = -1.0, func(): touch_direction = 0.0)
    _touch_button(layer, "▶", Vector2(160, 575), func(): touch_direction = 1.0, func(): touch_direction = 0.0)
    _touch_button(layer, "JUMP", Vector2(1090, 575), func(): jump_requested = true, func(): pass)

func _touch_button(parent: Node, label: String, pos: Vector2, pressed: Callable, released: Callable) -> void:
    var button := Button.new()
    button.text = label
    button.position = pos
    button.custom_minimum_size = Vector2(110, 105)
    button.add_theme_font_size_override("font_size", 27)
    parent.add_child(button)
    button.button_down.connect(pressed)
    button.button_up.connect(released)
    buttons.append(button)

func _create_stage() -> void:
    platforms.clear()
    coins.clear()
    platforms.append(Rect2(0, 620, 1280, 100))
    for i in range(1, 12):
        var x := float((i * 179) % 950 + 60)
        var y := 590.0 - i * 145.0
        platforms.append(Rect2(x, y, 235, 28))
        coins.append(Vector2(x + 115, y - 35))
    player = Vector2(120, 550)
    velocity = Vector2.ZERO
    camera_offset = 0.0

func _physics_process(delta: float) -> void:
    var direction := Input.get_axis("move_left", "move_right")
    if abs(touch_direction) > 0.1:
        direction = touch_direction
    velocity.x = direction * SPEED
    velocity.y += GRAVITY * delta
    if (Input.is_action_just_pressed("jump") or jump_requested) and on_ground:
        velocity.y = JUMP
        on_ground = false
    jump_requested = false
    var previous_bottom := player.y + 23
    player.x = clampf(player.x + velocity.x * delta, 24, WIDTH - 24)
    player.y += velocity.y * delta
    on_ground = false
    if velocity.y >= 0:
        for platform in platforms:
            if player.x + 18 > platform.position.x and player.x - 18 < platform.end.x:
                if previous_bottom <= platform.position.y + 12 and player.y + 23 >= platform.position.y:
                    player.y = platform.position.y - 23
                    velocity.y = 0
                    on_ground = true
    for i in range(coins.size() - 1, -1, -1):
        if player.distance_to(coins[i]) < 37:
            coins.remove_at(i)
            score += 10
    camera_offset = minf(camera_offset, player.y - 360)
    if player.y > camera_offset + HEIGHT + 160:
        hearts -= 1
        if hearts <= 0:
            hearts = 3
            score = 0
            stage = 1
        _create_stage()
    if player.y < -1050:
        stage += 1
        _create_stage()
    hud.text = "CLOUD CLIMB   Stage %d   Coins %d   Hearts %d" % [stage, score, hearts]
    queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(0, 0, WIDTH, HEIGHT), Color("#172b59"))
    for i in range(12):
        var cloud_y := fposmod(i * 130.0 - camera_offset * 0.2, HEIGHT + 170) - 60
        draw_circle(Vector2(i * 140.0 - 35, cloud_y), 55, Color(0.34, 0.61, 0.87, 0.25))
    for platform in platforms:
        draw_rect(Rect2(platform.position + Vector2(0, -camera_offset), platform.size), Color("#6ddfa2"))
        draw_rect(Rect2(platform.position + Vector2(0, -camera_offset + 12), Vector2(platform.size.x, 16)), Color("#337d75"))
    for coin in coins:
        draw_circle(coin - Vector2(0, camera_offset), 15, Color("#ffdb57"))
        draw_arc(coin - Vector2(0, camera_offset), 10, 0, TAU, 24, Color("#fff7c4"), 3)
    var p := player - Vector2(0, camera_offset)
    draw_circle(p, 23, Color("#ffd37c"))
    draw_circle(p + Vector2(-7, -5), 3, Color("#243052"))
    draw_circle(p + Vector2(7, -5), 3, Color("#243052"))
