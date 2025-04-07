extends Label

# Animation parameters
var velocity = Vector2(0, -80)  # Initial upward movement
var fade_rate = 2.0             # How quickly the text fades out
var life_time = 1.0             # How long the text lasts

func _ready():
	# Start the life timer for this text
	var timer = Timer.new()
	timer.wait_time = life_time
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	add_child(timer)
	timer.start()

func _process(delta):
	# Move the text upward
	position += velocity * delta
	
	# Slow down the upward movement over time
	velocity.y += 70 * delta
	
	# Fade out the text
	modulate.a -= fade_rate * delta
