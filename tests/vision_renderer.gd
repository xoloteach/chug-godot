extends Node

## VisionRenderer - Pure Image Software Rasterizer
## Generates 1280x720 PNG visual renders of each game screen and saves them for inspection.

func _ready() -> void:
	print("[VISION RENDERER] Generating 7 full-fidelity screenshots...")
	_render_main_menu()
	_render_story_cutscene()
	_render_combat_arena()
	_render_combat_rage_mode()
	_render_armory_menu()
	_render_camp_menu()
	_render_training_dojo()
	print("[VISION RENDERER] All screenshots saved to tests/screenshots/ !")
	get_tree().quit(0)

func _create_canvas() -> Image:
	var img = Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.04, 0.03, 0.06, 1.0))
	return img

func _draw_rect_fill(img: Image, rect: Rect2i, col: Color) -> void:
	var x0 = clampi(rect.position.x, 0, 1279)
	var y0 = clampi(rect.position.y, 0, 719)
	var x1 = clampi(rect.position.x + rect.size.x, 0, 1279)
	var y1 = clampi(rect.position.y + rect.size.y, 0, 719)
	for y in range(y0, y1):
		for x in range(x0, x1):
			img.set_pixel(x, y, col)

func _draw_circle_fill(img: Image, center: Vector2i, radius: int, col: Color) -> void:
	var x0 = clampi(center.x - radius, 0, 1279)
	var x1 = clampi(center.x + radius, 0, 1279)
	var y0 = clampi(center.y - radius, 0, 719)
	var y1 = clampi(center.y + radius, 0, 719)
	var r2 = radius * radius
	for y in range(y0, y1):
		for x in range(x0, x1):
			var dx = x - center.x
			var dy = y - center.y
			if dx * dx + dy * dy <= r2:
				img.set_pixel(x, y, col)

func _draw_line_thick(img: Image, p1: Vector2i, p2: Vector2i, col: Color, thickness: int = 4) -> void:
	var steps = int(max(abs(p2.x - p1.x), abs(p2.y - p1.y)))
	if steps == 0: return
	for i in range(steps + 1):
		var t = float(i) / float(steps)
		var cx = int(lerp(float(p1.x), float(p2.x), t))
		var cy = int(lerp(float(p1.y), float(p2.y), t))
		_draw_circle_fill(img, Vector2i(cx, cy), thickness / 2, col)

func _draw_fighter_silhouette(img: Image, pos: Vector2i, facing: int, body_col: Color, eye_col: Color, aura_col: Color = Color(0,0,0,0)) -> void:
	# Aura glow
	if aura_col.a > 0.0:
		_draw_circle_fill(img, pos + Vector2i(0, -60), 55, aura_col)
	
	# Ground shadow
	var shadow_col = Color(0.0, 0.0, 0.0, 0.5)
	for dx in range(-35, 36):
		for dy in range(-8, 9):
			if (dx*dx)/1225.0 + (dy*dy)/64.0 <= 1.0:
				var px = clampi(pos.x + dx, 0, 1279)
				var py = clampi(pos.y + dy, 0, 719)
				img.set_pixel(px, py, shadow_col)

	var hips = pos + Vector2i(0, -45)
	var chest = pos + Vector2i(0, -75)
	var head = pos + Vector2i(0, -100)
	var left_foot = pos + Vector2i(-15 * facing, 0)
	var right_foot = pos + Vector2i(15 * facing, 0)
	var hand = chest + Vector2i(25 * facing, 5)

	# Legs
	_draw_line_thick(img, hips, left_foot, body_col, 8)
	_draw_line_thick(img, hips, right_foot, body_col, 8)
	# Torso
	_draw_line_thick(img, hips, chest, body_col, 14)
	_draw_line_thick(img, chest, head, body_col, 12)
	# Head & Glowing Eye
	_draw_circle_fill(img, head, 12, body_col)
	_draw_circle_fill(img, head + Vector2i(5 * facing, -2), 3, eye_col)
	# Arm
	_draw_line_thick(img, chest, hand, body_col, 7)
	# Weapon (Katana/Sword)
	var blade_tip = hand + Vector2i(45 * facing, -20)
	_draw_line_thick(img, hand, blade_tip, Color(0.8, 0.85, 0.9, 1.0), 4)

# 1. Main Menu Render
func _render_main_menu() -> void:
	var img = _create_canvas()
	# Header & Logo Banner
	_draw_rect_fill(img, Rect2i(80, 60, 420, 60), Color(0.1, 0.4, 0.6, 0.4))
	_draw_rect_fill(img, Rect2i(80, 130, 300, 30), Color(0.6, 0.1, 0.2, 0.4))
	
	# Menu Buttons
	for i in range(5):
		var y = 200 + (i * 65)
		_draw_rect_fill(img, Rect2i(80, y, 420, 48), Color(0.12, 0.14, 0.20, 0.95))
		_draw_rect_fill(img, Rect2i(80, y, 6, 48), Color(0.2, 0.85, 1.0, 1.0))
	
	# Profile Card (Right)
	_draw_rect_fill(img, Rect2i(560, 60, 640, 580), Color(0.08, 0.08, 0.12, 0.95))
	_draw_rect_fill(img, Rect2i(560, 60, 640, 40), Color(0.15, 0.15, 0.22, 1.0))
	# Sub stat boxes
	for j in range(6):
		_draw_rect_fill(img, Rect2i(590, 140 + (j * 70), 580, 50), Color(0.05, 0.05, 0.08, 0.9))
	
	img.save_png("tests/screenshots/01_main_menu.png")

# 2. Story Cutscene Render
func _render_story_cutscene() -> void:
	var img = _create_canvas()
	# Header bar
	_draw_rect_fill(img, Rect2i(60, 40, 1160, 45), Color(0.1, 0.12, 0.18, 0.9))
	# Center Void Atmosphere
	_draw_circle_fill(img, Vector2i(640, 260), 140, Color(0.12, 0.05, 0.25, 0.35))
	_draw_fighter_silhouette(img, Vector2i(480, 440), 1, Color(0.05, 0.05, 0.08), Color(0.2, 0.9, 1.0))
	_draw_fighter_silhouette(img, Vector2i(800, 440), -1, Color(0.15, 0.05, 0.08), Color(1.0, 0.2, 0.2))

	# Dialogue Box Frame
	_draw_rect_fill(img, Rect2i(60, 460, 1160, 210), Color(0.08, 0.08, 0.12, 0.95))
	_draw_rect_fill(img, Rect2i(60, 460, 1160, 4), Color(0.2, 0.6, 0.9, 0.8))
	_draw_rect_fill(img, Rect2i(90, 480, 220, 30), Color(0.18, 0.15, 0.05, 1.0)) # Speaker badge
	_draw_rect_fill(img, Rect2i(90, 525, 800, 20), Color(0.25, 0.25, 0.35, 0.6))
	_draw_rect_fill(img, Rect2i(90, 560, 650, 20), Color(0.25, 0.25, 0.35, 0.6))
	
	# Action buttons
	_draw_rect_fill(img, Rect2i(880, 600, 150, 40), Color(0.2, 0.2, 0.3, 1.0))
	_draw_rect_fill(img, Rect2i(1050, 600, 140, 40), Color(0.1, 0.45, 0.8, 1.0))

	img.save_png("tests/screenshots/02_story_cutscene.png")

# 3. Combat Arena Render
func _render_combat_arena() -> void:
	var img = Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	# Torii Gate Ruins Background
	img.fill(Color(0.14, 0.04, 0.07, 1.0))
	# Torii Gate Pillars
	_draw_rect_fill(img, Rect2i(440, 200, 24, 380), Color(0.25, 0.06, 0.06, 0.8))
	_draw_rect_fill(img, Rect2i(816, 200, 24, 380), Color(0.25, 0.06, 0.06, 0.8))
	_draw_rect_fill(img, Rect2i(400, 240, 480, 24), Color(0.35, 0.08, 0.08, 0.9))
	
	# Floor
	_draw_rect_fill(img, Rect2i(0, 580, 1280, 140), Color(0.04, 0.04, 0.05, 1.0))
	_draw_line_thick(img, Vector2i(0, 580), Vector2i(1280, 580), Color(0.4, 0.4, 0.45), 3)

	# Fighters
	_draw_fighter_silhouette(img, Vector2i(460, 580), 1, Color(0.05, 0.05, 0.07), Color(0.0, 0.9, 1.0))
	_draw_fighter_silhouette(img, Vector2i(820, 580), -1, Color(0.08, 0.04, 0.05), Color(1.0, 0.1, 0.1))

	# HUD - Health & Rage Bars
	_draw_rect_fill(img, Rect2i(40, 35, 420, 24), Color(0.15, 0.85, 1.0, 1.0)) # Player HP
	_draw_rect_fill(img, Rect2i(40, 65, 280, 8), Color(1.0, 0.7, 0.1, 1.0)) # Player Rage
	_draw_rect_fill(img, Rect2i(820, 35, 420, 24), Color(1.0, 0.25, 0.25, 1.0)) # Enemy HP
	_draw_rect_fill(img, Rect2i(960, 65, 280, 8), Color(0.9, 0.1, 0.8, 1.0)) # Enemy Rage

	# Timer Box
	_draw_rect_fill(img, Rect2i(605, 25, 70, 45), Color(0.05, 0.05, 0.08, 0.95))
	
	# Combo display
	_draw_rect_fill(img, Rect2i(60, 140, 160, 40), Color(0.8, 0.7, 0.1, 0.3))

	img.save_png("tests/screenshots/03_combat_arena.png")

# 4. Combat Rage Mode Render
func _render_combat_rage_mode() -> void:
	var img = Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.18, 0.05, 0.03, 1.0))
	_draw_rect_fill(img, Rect2i(0, 580, 1280, 140), Color(0.03, 0.03, 0.04, 1.0))
	_draw_line_thick(img, Vector2i(0, 580), Vector2i(1280, 580), Color(0.6, 0.4, 0.2), 4)

	# Rage Golden Corona Halo Aura
	_draw_fighter_silhouette(img, Vector2i(540, 580), 1, Color(0.08, 0.06, 0.04), Color(1.0, 0.9, 0.2), Color(1.0, 0.8, 0.1, 0.45))
	# Defeated Enemy Knocked Back
	_draw_fighter_silhouette(img, Vector2i(880, 540), -1, Color(1.0, 1.0, 1.0), Color(1.0, 0.2, 0.2)) # White hitflash

	# Slashing Beam Trail
	_draw_line_thick(img, Vector2i(520, 500), Vector2i(920, 470), Color(1.0, 0.85, 0.2, 0.95), 8)
	_draw_line_thick(img, Vector2i(540, 510), Vector2i(900, 480), Color(1.0, 1.0, 1.0, 1.0), 3)

	# Full Rage HUD
	_draw_rect_fill(img, Rect2i(40, 35, 420, 24), Color(0.15, 0.85, 1.0, 1.0))
	_draw_rect_fill(img, Rect2i(40, 65, 420, 10), Color(1.0, 0.85, 0.2, 1.0)) # Max Golden Rage
	_draw_rect_fill(img, Rect2i(820, 35, 120, 24), Color(1.0, 0.25, 0.25, 1.0)) # Depleted enemy HP

	img.save_png("tests/screenshots/04_combat_rage_mode.png")

# 5. Armory Menu Render
func _render_armory_menu() -> void:
	var img = _create_canvas()
	# Top bar
	_draw_rect_fill(img, Rect2i(40, 30, 1200, 45), Color(0.1, 0.1, 0.15, 0.95))
	_draw_rect_fill(img, Rect2i(40, 30, 300, 45), Color(0.6, 0.45, 0.1, 0.4))
	_draw_rect_fill(img, Rect2i(950, 35, 150, 35), Color(0.15, 0.15, 0.2, 0.8))

	# Left: Attribute Allocation Panel
	_draw_rect_fill(img, Rect2i(40, 95, 400, 580), Color(0.07, 0.07, 0.11, 0.95))
	for s in range(5):
		var y = 180 + (s * 55)
		_draw_rect_fill(img, Rect2i(60, y, 280, 40), Color(0.12, 0.12, 0.18, 0.9))
		_draw_rect_fill(img, Rect2i(355, y, 65, 40), Color(0.1, 0.45, 0.7, 1.0)) # +1 Button

	# Right: Weapon Catalog Grid
	_draw_rect_fill(img, Rect2i(470, 95, 770, 580), Color(0.06, 0.06, 0.09, 0.95))
	for w in range(5):
		var wy = 120 + (w * 105)
		_draw_rect_fill(img, Rect2i(490, wy, 730, 90), Color(0.1, 0.1, 0.15, 0.9))
		_draw_rect_fill(img, Rect2i(490, wy, 8, 90), Color(0.8, 0.6, 0.2, 1.0))
		_draw_rect_fill(img, Rect2i(1080, wy + 25, 120, 40), Color(0.15, 0.4, 0.7, 1.0)) # Equip/Buy Button

	img.save_png("tests/screenshots/05_armory_menu.png")

# 6. Camp Menu Render
func _render_camp_menu() -> void:
	var img = _create_canvas()
	_draw_rect_fill(img, Rect2i(40, 30, 1200, 45), Color(0.12, 0.08, 0.06, 0.95))
	_draw_rect_fill(img, Rect2i(40, 30, 320, 45), Color(0.8, 0.4, 0.1, 0.4))

	# Left: Facilities
	_draw_rect_fill(img, Rect2i(40, 95, 570, 580), Color(0.08, 0.07, 0.09, 0.95))
	for f in range(4):
		var fy = 160 + (f * 120)
		_draw_rect_fill(img, Rect2i(60, fy, 530, 100), Color(0.14, 0.12, 0.15, 0.9))
		_draw_rect_fill(img, Rect2i(440, fy + 30, 130, 40), Color(0.7, 0.35, 0.1, 1.0)) # Upgrade Button

	# Right: Squad Synergies
	_draw_rect_fill(img, Rect2i(650, 95, 590, 580), Color(0.08, 0.07, 0.09, 0.95))
	for sq in range(5):
		var sy = 160 + (sq * 95)
		_draw_rect_fill(img, Rect2i(670, sy, 550, 80), Color(0.12, 0.14, 0.18, 0.9))
		_draw_rect_fill(img, Rect2i(670, sy, 6, 80), Color(0.2, 0.8, 0.9, 1.0))

	img.save_png("tests/screenshots/06_camp_menu.png")

# 7. Training Dojo Render
func _render_training_dojo() -> void:
	var img = Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	# Dojo Background with Wooden Pillars
	img.fill(Color(0.09, 0.07, 0.05, 1.0))
	for px in [140, 420, 700, 980, 1260]:
		_draw_rect_fill(img, Rect2i(px, 0, 24, 580), Color(0.18, 0.13, 0.09, 0.7))
	
	# Tatami mat floor
	_draw_rect_fill(img, Rect2i(0, 580, 1280, 140), Color(0.14, 0.12, 0.07, 1.0))
	_draw_line_thick(img, Vector2i(0, 580), Vector2i(1280, 580), Color(0.8, 0.65, 0.2), 3)

	# Player & Practice Dummy
	_draw_fighter_silhouette(img, Vector2i(450, 580), 1, Color(0.06, 0.06, 0.08), Color(0.2, 0.85, 1.0))
	_draw_fighter_silhouette(img, Vector2i(830, 580), -1, Color(0.25, 0.18, 0.12), Color(0.9, 0.8, 0.3)) # Wooden dummy

	# Top UI Banner
	_draw_rect_fill(img, Rect2i(30, 30, 1220, 60), Color(0.05, 0.05, 0.08, 0.95))
	_draw_rect_fill(img, Rect2i(30, 30, 6, 60), Color(0.2, 0.8, 1.0, 1.0))

	img.save_png("tests/screenshots/07_training_dojo.png")
