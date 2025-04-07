extends Node

# Player Resources
var money = 10.0  # Start with a small amount to buy first food
var calories = 0.0
var audience_size = 5  # Start with a small audience

# Charlie's stats
var energy = 100.0  # Maximum energy
var max_energy = 100.0
var energy_regen_rate = 5.0  # Energy regenerated per second
var is_performing_action = false
var current_action = ""
var action_progress = 0.0
var action_duration = 0.0

# Food Types
var food_inventory = {
	"cat_food": {
		"name": "Basic Cat Food",
		"count": 0,
		"calories": 1.0,
		"cost": 0.0,
		"description": "Basic cat food. Free but not very nutritious."
	},
	"dog_food": {
		"name": "Dog Food",
		"count": 0,
		"calories": 2.0,
		"cost": 1.0,
		"description": "Charlie loves dog food! Gives more calories than basic food."
	},
	"tuna": {
		"name": "Tuna",
		"count": 0,
		"calories": 5.0,
		"cost": 3.0,
		"description": "Fancy salmon bits. Very nutritious!"
	},
	"salmon": {
		"name": "Salmon",
		"count": 0, 
		"calories": 10.0,
		"cost": 7.0,
		"description": "The finest cat cuisine. Extremely calorie-rich."
	}
}

# Tricks
var tricks = {
	"sit": {
		"name": "Sit",
		"unlocked": true,  # Start with this trick
		"calorie_cost": 1.0,
		"energy_cost": 10.0,
		"duration": 1.0,  # Seconds to perform
		"money_reward": 1.0,
		"audience_gain": 0.01,
		"description": "Charlie sits on command. Basic but cute!"
	},
	"roll_over": {
		"name": "Roll Over",
		"unlocked": false,
		"unlock_cost": 25.0,
		"calorie_cost": 3.0,
		"energy_cost": 20.0,
		"duration": 3.0,
		"money_reward": 3.0,
		"audience_gain": 0.03,
		"description": "Charlie rolls over. Adorable!"
	},
	"jump": {
		"name": "Jump Through Hoop",
		"unlocked": false,
		"unlock_cost": 100.0,
		"calorie_cost": 8.0,
		"energy_cost": 30.0,
		"duration": 4.0,
		"money_reward": 10.0,
		"audience_gain": 0.07,
		"description": "Charlie jumps through a small hoop. Impressive!"
	},
	"balance": {
		"name": "Balance Act",
		"unlocked": false,
		"unlock_cost": 500.0,
		"calorie_cost": 15.0,
		"energy_cost": 50.0,
		"duration": 6.0,
		"money_reward": 25.0,
		"audience_gain": .15,
		"description": "Charlie balances on a ball. The crowd goes wild!"
	}
}

# Employees
var employees = {
	"feeder": {
		"name": "Feeder",
		"count": 0,
		"base_cost": 50.0,
		"current_cost": 50.0,
		"description": "Automatically feeds Charlie the best food in your inventory"
	},
	"trainer": {
		"name": "Trainer",
		"count": 0,
		"base_cost": 150.0,
		"current_cost": 150.0,
		"tricks_per_second": 0.2,  # Chance to perform a trick each second
		"description": "Makes Charlie perform tricks automatically"
	},
	"promoter": {
		"name": "Promoter",
		"count": 0,
		"base_cost": 300.0, 
		"current_cost": 300.0,
		"audience_per_second": 0.1,
		"description": "Grows your audience automatically"
	}
}

# Special Items (we'll implement these later)
var special_items = {}

# Current selected food
var selected_food = "cat_food"

# UI References
@onready var money_label = $UI/TopBar/MoneyLabel
@onready var calories_label = $UI/TopBar/CaloriesLabel
@onready var audience_label = $UI/TopBar/AudienceLabel
@onready var tab_container = $UI/RightPanel/TabContainer

# Timers
var passive_timer

func _ready():
	# Initialize UI
	update_ui()
	
	# Set up the passive timer for employee effects
	passive_timer = Timer.new()
	passive_timer.wait_time = 1.0
	passive_timer.autostart = true
	passive_timer.timeout.connect(on_passive_tick)
	add_child(passive_timer)
	
	# Set up the energy regeneration timer
	var energy_timer = Timer.new()
	energy_timer.wait_time = 0.1  # Update more frequently for smoother bar movement
	energy_timer.autostart = true
	energy_timer.timeout.connect(on_energy_tick)
	add_child(energy_timer)
	
	# Set up the action progress timer
	var action_timer = Timer.new()
	action_timer.wait_time = 0.05  # Update very frequently for smooth progress bar
	action_timer.autostart = true
	action_timer.timeout.connect(on_action_tick)
	add_child(action_timer)
	
	# Fill the UI tabs with content
	initialize_inventory_tab()
	initialize_tricks_tab()
	initialize_shop_tab()
	initialize_hire_tab()
	
	# Give player some starting cat food
	food_inventory["cat_food"]["count"] = 10

func _process(delta):
	# Safety check - if an action has no duration but is_performing_action is true, reset it
	if is_performing_action and (action_duration <= 0 or current_action == ""):
		is_performing_action = false
		current_action = ""
		action_progress = 0.0
		action_duration = 0.0
	
	# Update UI every frame
	update_ui()

func update_ui():
	# Update resource labels
	money_label.text = "Money: $" + str(snappedf(money, 0.01))
	calories_label.text = "Calories: " + str(snappedf(calories, 0.1))
	audience_label.text = "Audience: " + str(floor(audience_size))
	
	# Update energy bar
	update_energy_bar()
	
	# Update action progress bar
	update_action_bar()
	
	# Update other UI elements based on current tab
	var current_tab = tab_container.current_tab
	match current_tab:
		0:  # Inventory tab
			update_inventory_tab()
		1:  # Tricks tab
			update_tricks_tab()
		2:  # Shop tab
			update_shop_tab()
		3:  # Hire tab
			update_hire_tab()

func update_energy_bar():
	var energy_bar = $UI/EnergyBar
	energy_bar.value = (energy / max_energy) * 100.0
	energy_bar.get_node("Label").text = "Energy: " + str(int(energy)) + "/" + str(int(max_energy))

func update_action_bar():
	var action_bar = $UI/ActionBar
	
	if is_performing_action:
		action_bar.visible = true
		action_bar.value = (action_progress / action_duration) * 100.0
		
		# Set appropriate text for the action
		var action_text = ""
		if current_action.begins_with("trick_"):
			var trick_id = current_action.substr(6)
			action_text = "Performing: " + tricks[trick_id]["name"]
		elif current_action == "eating":
			action_text = "Eating"
			
		action_bar.get_node("Label").text = action_text
	else:
		action_bar.visible = false

func initialize_inventory_tab():
	var inventory_container = tab_container.get_node("Inventory/ScrollContainer/VBoxContainer")
	
	# Create buttons for each food type
	for food_id in food_inventory:
		var food = food_inventory[food_id]
		
		var hbox = HBoxContainer.new()
		var button = Button.new()
		var label = Label.new()
		
		button.text = food["name"]
		button.pressed.connect(func(): select_food(food_id))
		button.custom_minimum_size = Vector2(150, 40)
		
		label.text = "Count: " + str(food["count"]) + " | Calories: " + str(food["calories"])
		
		hbox.add_child(button)
		hbox.add_child(label)
		inventory_container.add_child(hbox)

func initialize_tricks_tab():
	var tricks_container = tab_container.get_node("Tricks/ScrollContainer/VBoxContainer")
	
	# Create buttons and info for each trick
	for trick_id in tricks:
		var trick = tricks[trick_id]
		
		var hbox = HBoxContainer.new()
		var button = Button.new()
		var label = Label.new()
		
		if trick["unlocked"]:
			button.text = "Perform: " + trick["name"]
			button.pressed.connect(func(): perform_trick(trick_id))
		else:
			button.text = "Unlock: " + trick["name"] + " ($" + str(trick["unlock_cost"]) + ")"
			button.pressed.connect(func(): unlock_trick(trick_id))
		
		button.custom_minimum_size = Vector2(200, 40)
		
		if trick["unlocked"]:
			label.text = "Cost: " + str(trick["calorie_cost"]) + " cal, " + str(trick["energy_cost"]) + " energy | Reward: $" + str(trick["money_reward"])
		else:
			label.text = trick["description"]
		
		hbox.add_child(button)
		hbox.add_child(label)
		tricks_container.add_child(hbox)

func initialize_shop_tab():
	var shop_container = tab_container.get_node("Shop/ScrollContainer/VBoxContainer")
	
	# Create purchase buttons for each food type
	for food_id in food_inventory:
		var food = food_inventory[food_id]
		
		if food["cost"] > 0:  # Only show items that cost money
			var hbox = HBoxContainer.new()
			var button = Button.new()
			var label = Label.new()
			
			button.text = "Buy: " + food["name"]
			button.pressed.connect(func(): buy_food(food_id))
			button.custom_minimum_size = Vector2(150, 40)
			
			label.text = "Cost: $" + str(food["cost"]) + " | " + food["description"]
			
			hbox.add_child(button)
			hbox.add_child(label)
			shop_container.add_child(hbox)

func initialize_hire_tab():
	var hire_container = tab_container.get_node("Hire/ScrollContainer/VBoxContainer")
	
	# Create hiring buttons for each employee type
	for employee_id in employees:
		var employee = employees[employee_id]
		
		var hbox = HBoxContainer.new()
		var button = Button.new()
		var label = Label.new()
		
		button.text = "Hire: " + employee["name"]
		button.pressed.connect(func(): hire_employee(employee_id))
		button.custom_minimum_size = Vector2(150, 40)
		
		label.text = "Cost: $" + str(employee["current_cost"]) + " | Count: " + str(employee["count"])
		
		hbox.add_child(button)
		hbox.add_child(label)
		hire_container.add_child(hbox)

func update_inventory_tab():
	var inventory_container = tab_container.get_node("Inventory/ScrollContainer/VBoxContainer")
	
	# Update each food item display
	for i in range(inventory_container.get_child_count()):
		var hbox = inventory_container.get_child(i)
		var button = hbox.get_child(0)
		var label = hbox.get_child(1)
		var food_id = food_inventory.keys()[i]
		var food = food_inventory[food_id]
		
		if food_id == "cat_food":
			label.text = "Count: Unlimited | Calories: " + str(food["calories"])
		else:
			label.text = "Count: " + str(food["count"]) + " | Calories: " + str(food["calories"])
		
		# Highlight the selected food
		if food_id == selected_food:
			button.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
		else:
			button.remove_theme_color_override("font_color")

func update_tricks_tab():
	var tricks_container = tab_container.get_node("Tricks/ScrollContainer/VBoxContainer")
	
	# Update each trick button and label
	for i in range(tricks_container.get_child_count()):
		var hbox = tricks_container.get_child(i)
		var button = hbox.get_child(0)
		var label = hbox.get_child(1)
		var trick_id = tricks.keys()[i]
		var trick = tricks[trick_id]
		
		if trick["unlocked"]:
			button.text = "Perform: " + trick["name"]
			label.text = "Cost: " + str(trick["calorie_cost"]) + " cal, " + str(trick["energy_cost"]) + " energy | Reward: $" + str(trick["money_reward"])
			button.disabled = calories < trick["calorie_cost"] or energy < trick["energy_cost"] or is_performing_action
		else:
			button.text = "Unlock: " + trick["name"] + " ($" + str(trick["unlock_cost"]) + ")"
			button.disabled = money < trick["unlock_cost"]

func update_shop_tab():
	var shop_container = tab_container.get_node("Shop/ScrollContainer/VBoxContainer")
	
	# Update each shop item
	for i in range(shop_container.get_child_count()):
		var hbox = shop_container.get_child(i)
		var button = hbox.get_child(0)
		
		# Get the corresponding food ID (adjusted for only showing purchasable foods)
		var purchasable_foods = []
		for food_id in food_inventory:
			if food_inventory[food_id]["cost"] > 0:
				purchasable_foods.append(food_id)
		
		var food_id = purchasable_foods[i]
		var food = food_inventory[food_id]
		
		# Disable button if not enough money
		button.disabled = money < food["cost"]

func update_hire_tab():
	var hire_container = tab_container.get_node("Hire/ScrollContainer/VBoxContainer")
	
	# Update each employee hiring option
	for i in range(hire_container.get_child_count()):
		var hbox = hire_container.get_child(i)
		var button = hbox.get_child(0)
		var label = hbox.get_child(1)
		var employee_id = employees.keys()[i]
		var employee = employees[employee_id]
		
		label.text = "Cost: $" + str(snappedf(employee["current_cost"], 0.01)) + " | Count: " + str(employee["count"])
		button.disabled = money < employee["current_cost"]

func on_passive_tick():
	# Feeders attempt to feed Charlie with the best available food
	var feeder_count = employees["feeder"]["count"]
	
	for i in range(feeder_count):
		# Find the best food in inventory
		var best_food_id = find_best_available_food()
		
		# Feed Charlie if food was found
		if best_food_id != "":
			var food = food_inventory[best_food_id]
			food["count"] -= 1
			calories += food["calories"]
	
	# Trainers attempt to perform tricks
	var trainer_count = employees["trainer"]["count"]
	var trainer_chance = employees["trainer"]["tricks_per_second"]
	
	# For each trainer, try to perform a trick
	for i in range(trainer_count):
		if randf() <= trainer_chance:
			# Find the best trick the cat can perform based on calories
			var best_trick = find_best_available_trick()
			
			# Perform the trick if one was found
			if best_trick != "":
				perform_trick(best_trick, true)  # true = automated
	
	# Promoters grow audience
	var promoter_effect = employees["promoter"]["count"] * employees["promoter"]["audience_per_second"]
	audience_size += promoter_effect

# Helper function to find the best available food in inventory
func find_best_available_food():
	var best_food_id = ""
	var best_calories = 0
	
	for food_id in food_inventory:
		var food = food_inventory[food_id]
		if food["count"] > 0 and food["calories"] > best_calories:
			best_food_id = food_id
			best_calories = food["calories"]
	
	return best_food_id

# Helper function to find the best available trick
func find_best_available_trick():
	var best_trick_id = ""
	var best_reward = 0
	
	for trick_id in tricks:
		var trick = tricks[trick_id]
		if trick["unlocked"] and trick["calorie_cost"] <= calories and trick["money_reward"] > best_reward:
			best_trick_id = trick_id
			best_reward = trick["money_reward"]
	
	return best_trick_id

func select_food(food_id):
	selected_food = food_id
	update_ui()

func feed_charlie():
	# Check if Charlie is already performing an action
	if is_performing_action:
		# Show feedback that Charlie is busy
		$UI/CharlieFeedback.text = "Charlie is busy!"
		$UI/CharlieFeedback.visible = true
		await get_tree().create_timer(1.0).timeout
		$UI/CharlieFeedback.visible = false
		return
		
	var food = food_inventory[selected_food]
	
	if selected_food == "cat_food" or food["count"] > 0:
		# Start the eating action - if it returns false, an action is already in progress
		if not start_action("eating", 0.5):  # Eating takes 0.5 seconds
			return
			
		# Apply the effects immediately
		if selected_food != "cat_food":
			food["count"] -= 1
		calories += food["calories"]
		
		# Visual feedback is handled in complete_action()

func buy_food(food_id):
	var food = food_inventory[food_id]
	
	if money >= food["cost"]:
		money -= food["cost"]
		food["count"] += 1

func perform_trick(trick_id, automated = false):
	var trick = tricks[trick_id]
	
	# Check if Charlie is already performing an action
	if is_performing_action and not automated:
		# Show feedback that Charlie is busy
		$UI/CharlieFeedback.text = "Charlie is busy!"
		$UI/CharlieFeedback.visible = true
		await get_tree().create_timer(1.0).timeout
		$UI/CharlieFeedback.visible = false
		return
	
	# Check if Charlie has enough calories and energy
	if calories >= trick["calorie_cost"] and energy >= trick["energy_cost"]:
		# Deduct calories and energy
		calories -= trick["calorie_cost"]
		energy -= trick["energy_cost"]
		
		if not automated:
			# Start the action
			if not start_action("trick_" + trick_id, trick["duration"]):
				# If start_action returns false, it means an action is already in progress
				return
				
			# Visual feedback
			$UI/CharlieFeedback.text = "Performing trick..."
			$UI/CharlieFeedback.visible = true
		else:
			# For automated tricks, apply rewards immediately
			apply_trick_rewards(trick_id)
	else:
		if not automated:
			# Show feedback about not enough resources
			var feedback = ""
			if calories < trick["calorie_cost"]:
				feedback = "Not enough calories!"
			else:
				feedback = "Charlie is too tired!"
				
			$UI/CharlieFeedback.text = feedback
			$UI/CharlieFeedback.visible = true
			await get_tree().create_timer(1.0).timeout
			$UI/CharlieFeedback.visible = false

func apply_trick_rewards(trick_id):
	var trick = tricks[trick_id]
	
	# Calculate reward based on audience size
	var base_reward = trick["money_reward"]
	var audience_bonus = 1.0 + (audience_size / 100.0)  # Audience gives a bonus
	var total_reward = base_reward * audience_bonus
	
	money += total_reward
	audience_size += trick["audience_gain"]

func start_action(action_name, duration):
	# Set a guard to prevent starting a new action if one is already in progress
	if is_performing_action:
		return false
		
	is_performing_action = true
	current_action = action_name
	action_progress = 0.0
	action_duration = duration
	
	# Hide feedback if it's showing
	$UI/CharlieFeedback.visible = false
	
	# Force an immediate UI update to show the action has started
	update_ui()
	
	# Action successfully started
	return true

func complete_action():
	# Set flag to false first to prevent new actions from starting
	is_performing_action = false
	
	# Store the action we're completing
	var completed_action = current_action
	
	# Reset action state before applying effects
	current_action = ""
	action_progress = 0.0
	action_duration = 0.0
	
	# Apply effects based on the completed action
	if completed_action.begins_with("trick_"):
		var trick_id = completed_action.substr(6)  # Remove "trick_" prefix
		apply_trick_rewards(trick_id)
		
		# Show success feedback
		$UI/CharlieFeedback.text = "Amazing trick!"
		$UI/CharlieFeedback.visible = true
		await get_tree().create_timer(1.0).timeout
		$UI/CharlieFeedback.visible = false
	elif completed_action == "eating":
		# Eating effects are already applied when starting the action
		# Just show feedback
		$UI/CharlieFeedback.text = "Yum!"
		$UI/CharlieFeedback.visible = true
		await get_tree().create_timer(1.0).timeout
		$UI/CharlieFeedback.visible = false
	
	# Update UI to reflect the completion
	update_ui()

func unlock_trick(trick_id):
	var trick = tricks[trick_id]
	
	if money >= trick["unlock_cost"]:
		money -= trick["unlock_cost"]
		trick["unlocked"] = true
		
		# We need to rebuild the tricks tab to update the signal connections
		var tricks_container = tab_container.get_node("Tricks/ScrollContainer/VBoxContainer")
		
		# Remove all existing children
		for child in tricks_container.get_children():
			tricks_container.remove_child(child)
			child.queue_free()
		
		# Rebuild the tricks tab
		initialize_tricks_tab()

func hire_employee(employee_id):
	var employee = employees[employee_id]
	
	if money >= employee["current_cost"]:
		money -= employee["current_cost"]
		employee["count"] += 1
		
		# Increase cost for next hire
		employee["current_cost"] = employee["base_cost"] * pow(1.15, employee["count"])

func _input(event):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Check if click is in Charlie's area (will implement proper collision later)
			var charlie_area = $UI/CharlieArea
			if charlie_area.get_global_rect().has_point(event.position):
				feed_charlie()
				

func on_energy_tick():
	# Regenerate energy over time, but only if not performing an action
	if not is_performing_action and energy < max_energy:
		energy += energy_regen_rate * 0.1  # Adjusted for 0.1 second interval
		energy = min(energy, max_energy)  # Cap at maximum
		update_ui()

func on_action_tick():
	# Only update action progress if an action is in progress
	if is_performing_action and action_duration > 0:
		action_progress += 0.05  # Adjusted for 0.05 second interval
		
		# Check if action is complete
		if action_progress >= action_duration:
			complete_action()
		
		# Update UI to show current progress
		update_ui()

func save_game():
	var save_data = {
		"money": money,
		"calories": calories,
		"audience_size": audience_size,
		"energy": energy,
		"max_energy": max_energy,
		"food_inventory": food_inventory,
		"tricks": tricks,
		"employees": employees,
		"selected_food": selected_food,
		# Don't save action state since it will reset on load anyway
	}
	
	var save_file = FileAccess.open("user://charlie_circus_save.save", FileAccess.WRITE)
	save_file.store_line(JSON.stringify(save_data))

func load_game():
	if FileAccess.file_exists("user://charlie_circus_save.save"):
		var save_file = FileAccess.open("user://charlie_circus_save.save", FileAccess.READ)
		var json_string = save_file.get_line()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			var save_data = json.get_data()
			
			money = save_data["money"]
			calories = save_data["calories"]
			audience_size = save_data["audience_size"]
			energy = save_data["energy"]
			max_energy = save_data["max_energy"]
			food_inventory = save_data["food_inventory"]
			tricks = save_data["tricks"]
			employees = save_data["employees"]
			selected_food = save_data["selected_food"]
			
			# Reset action state
			is_performing_action = false
			current_action = ""
			action_progress = 0.0
			action_duration = 0.0
