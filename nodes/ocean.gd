extends Node3D

@export var wind_strength: float = 0.7: set = set_wind_strength

var time = 0.0
var wind_modified = 1.0

var visual_material

var gerstner_height
var gerstner_normal
var gerstner_stretch
var gerstner_2_height
var gerstner_2_normal
var gerstner_2_stretch
var bubble_amount
var foam_amount
var bubble_gerstner
var foam_gerstner
var detail_normal_intensity
var shift_vector
var curl_strength

func _ready():
	visual_material = $waterplane.material_override
	
	gerstner_height = visual_material.get_shader_parameter("gerstner_height")
	gerstner_normal = visual_material.get_shader_parameter("gerstner_normal")
	gerstner_stretch = visual_material.get_shader_parameter("gerstner_stretch")
	gerstner_2_height = visual_material.get_shader_parameter("gerstner_2_height")
	gerstner_2_normal = visual_material.get_shader_parameter("gerstner_2_normal")
	gerstner_2_stretch = visual_material.get_shader_parameter("gerstner_2_stretch")
	bubble_amount = visual_material.get_shader_parameter("bubble_amount")
	foam_amount = visual_material.get_shader_parameter("foam_amount")
	detail_normal_intensity = visual_material.get_shader_parameter("detail_normal_intensity")
	bubble_gerstner = visual_material.get_shader_parameter("bubble_gerstner")
	foam_gerstner = visual_material.get_shader_parameter("foam_gerstner")
	
	shift_vector = $render_targets.shift_vector
	curl_strength = $render_targets.curl_strength

func update_water(wind):
	visual_material.set_shader_parameter("gerstner_height", gerstner_height * wind)
	visual_material.set_shader_parameter("gerstner_normal", gerstner_normal * wind)
	visual_material.set_shader_parameter("gerstner_stretch", gerstner_stretch * wind)
	visual_material.set_shader_parameter("gerstner_2_height", gerstner_2_height * wind)
	visual_material.set_shader_parameter("gerstner_2_normal", gerstner_2_normal * wind)
	visual_material.set_shader_parameter("gerstner_2_stretch", gerstner_2_stretch * wind)
	visual_material.set_shader_parameter("bubble_amount", bubble_amount * wind)
	visual_material.set_shader_parameter("foam_amount", foam_amount * wind)
	visual_material.set_shader_parameter("detail_normal_intensity", detail_normal_intensity * wind)
	visual_material.set_shader_parameter("bubble_gerstner", bubble_gerstner * wind)
	visual_material.set_shader_parameter("foam_gerstner", foam_gerstner * wind)
	
	$render_targets.shift_vector = shift_vector * wind
	$render_targets.curl_strength = curl_strength * clamp(wind, 1.0, 1.2)

func set_wind_strength(value):
	wind_strength = value

func get_files_in_directory(path):
	var files = []
	var dir = DirAccess.open(path)
	dir.list_dir_begin() # TODOConverter3To4 fill missing arguments https://github.com/godotengine/godot/pull/40547
	
	while true:
		var file = dir.get_next()
		if file == "":
			break
		elif not file.begins_with("."):
			files.append(file)

	dir.list_dir_end()
	return files

func set_water_style(value):
	var style_path = "res://textures/water/gradients"
	var style_list = get_files_in_directory(style_path)
	var gradient = GradientTexture2D.new()
	
	gradient.gradient = load(style_path + "/" + style_list[value])
	visual_material.set_shader_parameter("water_color", gradient)
	
func set_subsurface_scattering(value):
	visual_material.set_shader_parameter("sss_strength", value);

func _physics_process(delta):
	time += 0.005
	wind_modified = wind_modified + ((wind_strength + sin(time) * 0.2) - wind_modified) * delta * 0.5
	
	# DEBUG WIND VAR
	#print(wind_modified)
	
	update_water(wind_modified)
