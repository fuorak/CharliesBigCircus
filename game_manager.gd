# GameManager.gd
extends Node2D

var score: int = 0
var time_elapsed: float = 0
var score_increment_interval: float = 1.0
var score_label: Label
var box: ColorRect
var random = RandomNumberGenerator.new()
var particles: CPUParticles2D

func _ready():
	random.randomize()
	
	# Create score label in top-left
	score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.text = "Score: 0"
	score_label.position = Vector2(20, 20)
	add_child(score_label)
	
	# Create box in the center
	box = ColorRect.new()
	box.name = "Box"
	box.color = Color(0.2, 0.6, 0.8)  # Initial blue color
	box.size = Vector2(100, 100)
	
	# Add glow effect to box
	var glow = CanvasItemMaterial.new()
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	box.material = glow
	
	# Position box in center of screen
	var viewport_size = get_viewport_rect().size
	box.position = Vector2(viewport_size.x/2 - 50, viewport_size.y/2 - 50)
	add_child(box)
	
	# Add particle system
	particles = CPUParticles2D.new()
	particles.position = Vector2(viewport_size.x/2, viewport_size.y/2)
	particles.emitting = false
	particles.amount = 50
	particles.lifetime = 1.
	particles.explosiveness = 1
	particles.direction = Vector2(0, -1)
	particles.spread = 100
	particles.gravity = Vector2(0, 98)
	particles.initial_velocity_min = 100
	particles.initial_velocity_max = 150
	# Fixed particle scale properties for Godot 4
	particles.scale_amount_min = 7
	particles.scale_amount_max = 7
	particles.color = Color(1, 1, 1, 0.8)
	add_child(particles)

func _process(delta):
	time_elapsed += delta
	
	if time_elapsed >= score_increment_interval:
		time_elapsed = 0
		score += 10
		score_label.text = "Score: " + str(score)
		
		# Create floating score number
		create_score_popup(10)
		
		# Animate box with random color
		pulse_box()

func pulse_box():
	# Generate random color
	var new_color = Color(
		random.randf_range(0.2, 1.0),
		random.randf_range(0.2, 1.0),
		random.randf_range(0.2, 1.0)
	)
	
	# Store original values
	var original_size = box.size
	var original_position = box.position
	
	# Create tween
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_OUT)
	
	# First shrink slightly (anticipation)
	tween.tween_property(box, "size", original_size * 0.9, 0.1)
	tween.parallel().tween_property(box, "position", 
								  Vector2(original_position.x + 5, original_position.y + 5), 0.1)
	
	# Then grow dramatically with color change
	tween.tween_property(box, "size", original_size * 1.3, 0.2)
	tween.parallel().tween_property(box, "position", 
								  Vector2(original_position.x - 15, original_position.y - 15), 0.2)
	tween.parallel().tween_property(box, "color", new_color, 0.2)
	
	# Emit particles
	tween.tween_callback(emit_particles.bind(new_color))
	
	# Return to original size and position, keep new color
	tween.tween_property(box, "size", original_size, 0.2)
	tween.parallel().tween_property(box, "position", original_position, 0.2)
	
	# Apply a rotation effect
	var current_rotation = box.rotation
	tween.parallel().tween_property(box, "rotation", current_rotation + 0.05, 0.2)
	tween.tween_property(box, "rotation", current_rotation, 0.2)

func emit_particles(color: Color):
	# Update particle color to match the box
	particles.color = color
	particles.emitting = true

func create_score_popup(value: int):
	# Create a label for the popup score
	var popup = Label.new()
	popup.text = "+" + str(value)
	popup.add_theme_font_size_override("font_size", 24)
	
	# Random horizontal offset
	var offset_x = random.randf_range(-30, 30)
	
	# Position it above the box
	popup.position = Vector2(
		box.position.x + box.size.x/2 - 15 + offset_x,  # Center horizontally above box
		box.position.y - 40                            # Above the box
	)
	
	# Add shadow for better visibility
	popup.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	popup.add_theme_constant_override("shadow_offset_x", 2)
	popup.add_theme_constant_override("shadow_offset_y", 2)
	
	# Random color matching box color but brighter
	popup.add_theme_color_override("font_color", Color(
		random.randf_range(0.7, 1.0),
		random.randf_range(0.7, 1.0),
		random.randf_range(0.7, 1.0)
	))
	
	add_child(popup)
	
	# Create tween for popup animation
	var tween = create_tween()
	
	# Start animation: Scale up and slight movement
	tween.tween_property(popup, "scale", Vector2(1.5, 1.5), 0.2).from(Vector2(0.5, 0.5))
	
	# Float upward and fade out
	tween.parallel().tween_property(popup, "position:y", 
								  popup.position.y - 100, 1.0)
	tween.tween_property(popup, "modulate:a", 0, 0.5)
	
	# Remove the label when animation is done
	tween.tween_callback(popup.queue_free)
