shader_type spatial;
render_mode diffuse_lambert;
render_mode specular_schlick_ggx;

uniform sampler2D water_color : source_color;
uniform sampler2D vector_map;
uniform sampler2D bubble_normal_map : hint_normal;
uniform sampler2D bubble_albedo_map : source_color;
uniform sampler2D foam_normal_map : hint_normal;
uniform sampler2D foam_albedo_map : source_color;
uniform sampler2D underwater_albedo_map : source_color;
uniform sampler2D swimthings_albedo_map : source_color;
uniform sampler2D beach_waves_map;
uniform sampler2D gerstner_height_map;
uniform sampler2D gerstner_normal_map : hint_normal;
uniform sampler2D detail_normal_map : hint_normal;
uniform sampler2D water_highlight_map : source_color;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float gerstner_height = 0.4;
uniform float gerstner_normal = 0.25;
uniform float gerstner_stretch = 1.5;
uniform float gerstner_tiling = 0.1;
uniform float gerstner_2_height = 1.0;
uniform float gerstner_2_normal = 0.4;
uniform float gerstner_2_stretch = 1.0;
uniform float gerstner_2_tiling = 0.412;
uniform float gerstner_distance_fadeout = 50.0;
uniform vec2 gerstner_speed = vec2(0.011, 0.014);
uniform vec2 gerstner_2_speed = vec2(0.003, 0.008);

uniform float normal_base_intensity = 0.7;
uniform float normal_peak_intensity = 1.5;
uniform float normal_dist_fadeout = 10.0;
uniform float detail_normal_intensity = 0.05;
uniform float detail_normal_tiling = 10.0;
uniform float detail_normal_speed = 12.0;

uniform float foam_ramp = 0.2;
uniform float foam_amount = 3.0;
uniform int foam_tiling = 8;
uniform float foam_gerstner = 0.7;
uniform float bubble_ramp = 0.1;
uniform float bubble_amount = 1.0;
uniform int bubble_tiling = 3;
uniform float bubble_gerstner = 2.0;
uniform float wave_height = 0.3;
uniform float wave_z_offset = -0.15;
uniform float underwater_tex_border = 4.0;
uniform float underwater_texture = 0.14;
uniform float underwater_color = 0.8;
uniform int underwater_tiling = 2;
uniform float beach_alpha_fadeout = 0.05;
uniform float beach_normal_fadeout = 0.3;
uniform float beach_foam_depth = 2.0;
uniform float beach_foam_distortion = 3.74;
uniform float beach_foam_amount = 0.7;
uniform float swimthings_depth = 1.5;
uniform float swimthings_intensity = 0.8;
uniform int swimthings_tiling = 3;
uniform float flow_blend_timing = 1.0;
uniform float flow_blend_stretch = 0.35;
uniform float water_color_depth = 1.0;
uniform float sss_strength = 5.0;

float get_height(sampler2D tex, vec2 uv, float offset) {
	vec2 v1 = vec2(0.0, 1.0);
	vec2 v2 = vec2(0.866025, 0.5);
	vec2 v3 = vec2(0.866025, -0.5);

	float p1 = texture(tex, fract( uv + v1 * offset ) ).z;
	float p2 = texture(tex, fract( uv + v1 * -offset ) ).z;
	float p3 = texture(tex, fract( uv + v2 * offset ) ).z;
	float p4 = texture(tex, fract( uv + v2 * -offset ) ).z;
	float p5 = texture(tex, fract( uv + v3 * offset ) ).z;
	float p6 = texture(tex, fract( uv + v3 * -offset ) ).z;

	return (p1 + p2 + p3 + p4 + p5 + p6) / 6.0;
}

vec3 get_normal(sampler2D tex, vec2 uv, float offset, float intensity) {
	float p_up = texture (tex, fract( uv + vec2(0.0, -offset) ) ).z;
	float p_right = texture (tex, fract( uv + vec2(offset, 0.0) ) ).z;
	float p_down = texture (tex, fract( uv + vec2(0.0, offset) ) ).z;
	float p_left = texture (tex, fract( uv + vec2(-offset, 0.0) ) ).z;

	float red = mix(p_left * intensity, 1.0 - p_right * intensity, 0.5);
	float green = mix(p_down * intensity, 1.0 - p_up * intensity, 0.5);

	return vec3(red, green, clamp( 1.0 - abs(0.5 - red) - abs(0.5 - green), 0.5, 1.0));
}

void vertex() {
	vec2 uv = UV + MODEL_MATRIX[3].xz * 0.25;

	vec2 uv_gerstner = uv * gerstner_tiling + TIME * gerstner_speed;
	vec2 uv_gerstner_2 = uv_gerstner * gerstner_2_tiling + TIME * gerstner_2_speed;

	vec2 gerstner_normal_read = ( texture(gerstner_normal_map, uv_gerstner).xy - 0.5 ) * gerstner_height;
	vec2 gerstner_2_normal_read = ( texture(gerstner_normal_map, uv_gerstner_2).xy - 0.5 ) * gerstner_2_height;

	vec3 gerstner = vec3(-gerstner_normal_read.x * gerstner_stretch, (pow( texture(gerstner_height_map, uv_gerstner).x, 0.4545) - 0.5) * gerstner_height, gerstner_normal_read.y * gerstner_stretch);
	vec3 gerstner_2 = vec3(-gerstner_2_normal_read.x * gerstner_2_stretch, (pow( texture(gerstner_height_map, uv_gerstner_2).x, 0.4545) - 0.5) * gerstner_2_height, gerstner_2_normal_read.y * gerstner_2_stretch);

	float height = get_height(vector_map, fract(uv), 0.07);

	VERTEX += vec3(0.0, height + wave_z_offset, 0.0) * wave_height + gerstner + gerstner_2;
	COLOR[0] = length(INV_VIEW_MATRIX[3].xyz + MODEL_MATRIX[3].xyz - VERTEX);
}

void fragment() {
	vec2 uv = UV + MODEL_MATRIX[3].xz * 0.25;
	vec2 uv_gerstner = uv * gerstner_tiling + TIME * gerstner_speed;
	vec2 uv_gerstner_2 = uv_gerstner * gerstner_2_tiling + TIME * gerstner_2_speed;

	float height = texture(vector_map, uv).z;
	vec2 flow_map = texture(vector_map, uv).xy - 0.5;

	// GERSTNER WAVES
	vec3 normal_gerstner = texture(gerstner_normal_map, uv_gerstner).xyz - vec3(0.5, 0.5, 1.0);
	vec3 normal_gerstner_2 = texture(gerstner_normal_map, uv_gerstner_2).xyz - vec3(0.5, 0.5, 1.0);
	vec3 height_gerstner = texture(gerstner_height_map, uv_gerstner).xyz;
	vec3 height_gerstner_2 = texture(gerstner_height_map, uv_gerstner_2).xyz;

	vec3 normal_output = get_normal(vector_map, uv, 0.000976, 4.0 * normal_peak_intensity); // 1.0 / 1024.0
	normal_output += get_normal(vector_map, uv, 0.001953, 3.0 * normal_peak_intensity); // 1.0 / 512.0
	normal_output += get_normal(vector_map, uv, 0.003906, 2.0 * normal_base_intensity); // 1.0 / 256.0
	normal_output += get_normal(vector_map, uv, 0.007812, 2.0 * normal_base_intensity); // 1.0 / 128.0
	normal_output += get_normal(vector_map, uv, 0.015625, 1.0 * normal_base_intensity); // 1.0 / 64.0
	normal_output += get_normal(vector_map, uv, 0.03125, 1.0 * normal_base_intensity); // 1.0 / 32.0

	normal_output /= 6.0;

	// DETAIL NORMAL
	normal_output = mix(normal_output, vec3(0.5, 0.5, 1.0), 1.0 - smoothstep(0.0, COLOR[0], normal_dist_fadeout) );
	normal_output += ( texture(detail_normal_map, uv_gerstner * detail_normal_tiling - TIME * gerstner_speed * detail_normal_speed ).xyz - vec3(0.5, 0.5, 1.0) ) * detail_normal_intensity;

	// ADDING SECOND GERSTNER WAVE
	normal_output += normal_gerstner * gerstner_normal + normal_gerstner_2 * gerstner_2_normal;
	normal_output = mix(normal_output, vec3(0.5, 0.5, 1.0), 1.0 - smoothstep(0.0, COLOR[0], gerstner_distance_fadeout) );

	// FLOW TIMING FOR FLOW MAPS (USED IN FOAM AND BUBBLES) 2 UVs BLENDED TOGETHER
	float flow_timing = TIME * flow_blend_timing;
	float flow_timing_a = flow_timing;
	float flow_timing_b = flow_timing + 0.5;

	vec2 uv_detail_a = uv + flow_map * -flow_timing_a * flow_blend_stretch;
	vec2 uv_detail_b = uv + flow_map * -flow_timing_b * flow_blend_stretch;

	// UNDERWATER
	float depth = texture(DEPTH_TEXTURE, SCREEN_UV).r; // LOOSING SS-REFLECTIONS

	// DEPTH REPROJECTION FROM NDC Z to VIEW Z Axis
	depth = PROJECTION_MATRIX[3][2] / (depth - PROJECTION_MATRIX[2][2]); // NDC Z Depth to VIEW Space Z
	depth = depth + VERTEX.z;

	// NORMAL APPLIED TO DEPTH AND READ FROM BUFFER AGAIN (DISTORTED Z-DEPTH)
	depth = texture(DEPTH_TEXTURE, SCREEN_UV + (normal_output.xy - 0.5) * clamp(depth * 0.2, 0.0, 0.1) ).r;
	depth = PROJECTION_MATRIX[3][2] / (depth - PROJECTION_MATRIX[2][2]); // NDC Z Depth to VIEW Space Z
	depth = depth + VERTEX.z;

	float depth_mask = clamp(depth * underwater_tex_border, 0.0, 1.0);

	// WATER COLOR GRADIENT
	vec3 water_gradient = texture(water_color, vec2(0.0, depth * water_color_depth)).xyz;
	vec3 albedo_output = water_gradient;

	// UV PARALLAX APPLY DEPTH FOR UNDERWATER TEXTURE
	vec2 uv_underwater = uv * float(underwater_tiling);
	uv_underwater.x = uv_underwater.x + dot(INV_VIEW_MATRIX[1], vec4(1.0, 0.0, 0.0, 0.0)) * clamp(depth, 0.0, 1.0) * 0.5;
	uv_underwater.y = uv_underwater.y + dot(INV_VIEW_MATRIX[2], vec4(0.0, 0.0, -1.0, 0.0)) * clamp(depth, 0.0, 1.0) * 0.5;

	// UV PARALLAX FOR FLOATING PIECES IN WATER
	vec2 uv_swimthings = uv * float(swimthings_tiling) + vec2(TIME * 0.015, TIME * 0.008) - (normal_output.xy - vec2(0.5, 0.5)) * 0.4;
	uv_swimthings.x = uv_swimthings.x + dot(INV_VIEW_MATRIX[1], vec4(1.0, 0.0, 0.0, 0.0)) * 0.1;
	uv_swimthings.y = uv_swimthings.y + dot(INV_VIEW_MATRIX[2], vec4(0.0, 0.0, -1.0, 0.0)) * 0.1;

	// NORMAL WIGGLE
	uv_underwater = uv_underwater - (normal_output.xy - vec2(0.5, 0.5)) * clamp(depth, 0.0, 0.5) * 2.0;

	vec4 albedo_swimthings = texture(swimthings_albedo_map, uv_swimthings);
	vec3 albedo_underwater = texture(underwater_albedo_map, uv_underwater).xyz;
	albedo_underwater = pow(albedo_underwater, vec3(0.4545, 0.4545, 0.4545)) * 2.0;

	vec3 screen = textureLod(SCREEN_TEXTURE, SCREEN_UV + ((normal_output.xy - 0.5) * clamp(depth, 0.0, 0.1) ), 0.0).xyz; // LOOSING SS-REFLECTIONS

	albedo_output = albedo_output + (albedo_underwater - 0.5) * underwater_texture;
	albedo_output = mix(screen, albedo_output, depth_mask);
	albedo_output = mix(albedo_output, water_gradient, 1.0 - smoothstep(0.0, depth, 1.0 - underwater_color));
	albedo_output = mix(albedo_output, albedo_swimthings.xyz, ( albedo_swimthings.a * clamp(0.0, depth * swimthings_depth, 1.0) * swimthings_intensity ) );

	// BEACH WAVES MASK
	float mask_beach_waves = pow( texture(beach_waves_map, vec2(clamp(depth * beach_foam_depth + (normal_output.y - 0.5) * beach_foam_distortion, 0.0, 1.0), 0.0)).x, 2.2) * beach_foam_amount;

	// WATER DETAIL BUBBLES
	vec3 albedo_bubbles_a = texture(bubble_albedo_map, uv_detail_a * float(bubble_tiling) ).xyz;
	vec3 albedo_bubbles_b = texture(bubble_albedo_map, uv_detail_b * float(bubble_tiling) ).xyz;

	// USED FOR THE TWO SHIFTED FLOW MAPS TO BLEND BETWEEN EACH OTHER
	float time_mask = cos(flow_timing_a * 2.0*PI) / 2.0 + 0.5;

	albedo_bubbles_a = mix(albedo_bubbles_a, albedo_bubbles_b, time_mask );

	vec3 normal_bubbles_a = texture(bubble_normal_map, uv_detail_a * float(bubble_tiling)).xyz - vec3(0.5, 0.5, 1.0);
	vec3 normal_bubbles_b = texture(bubble_normal_map, uv_detail_b * float(bubble_tiling)).xyz - vec3(0.5, 0.5, 1.0);

	float albedo_bubbles_mask = 1.0 - smoothstep(0.0, height, bubble_ramp);
	albedo_bubbles_mask *= smoothstep(0.0, COLOR[0], normal_dist_fadeout);

	normal_bubbles_a = mix(normal_bubbles_a, normal_bubbles_b, time_mask );

	albedo_output = mix(albedo_output, albedo_output + albedo_bubbles_a, albedo_bubbles_mask * bubble_amount + mask_beach_waves * 5.0 + (height_gerstner.y + height_gerstner_2.y) * bubble_gerstner );
	normal_output = mix(normal_output, normal_output + normal_bubbles_a, albedo_bubbles_mask * bubble_amount + mask_beach_waves * 5.0 + (height_gerstner.y + height_gerstner_2.y) * bubble_gerstner );

	// FOAM
	vec3 albedo_foam_a = texture(foam_albedo_map, uv_detail_a * float(foam_tiling) ).xyz;
	vec3 albedo_foam_b = texture(foam_albedo_map, uv_detail_b * float(foam_tiling) ).xyz;

	albedo_foam_a = mix(albedo_foam_a, albedo_foam_b, time_mask );

	vec3 normal_foam_a = texture(foam_normal_map, uv_detail_a * float(foam_tiling) ).xyz - vec3(0.5, 0.5, 1.0);
	vec3 normal_foam_b = texture(foam_normal_map, uv_detail_b * float(foam_tiling) ).xyz - vec3(0.5, 0.5, 1.0);

	normal_foam_a = mix(normal_foam_a, normal_foam_b, time_mask );

	float mask_foam = 1.0 - smoothstep(-0.4, height, foam_ramp);
	mask_foam *= smoothstep(0.0, COLOR[0], normal_dist_fadeout);
	height_gerstner.y = smoothstep(0.0, 0.05, pow(height_gerstner.y, 4.0));
	height_gerstner_2.y = smoothstep(0.0, 0.05, pow(height_gerstner_2.y, 4.0));

	albedo_output = mix(albedo_output, albedo_output + albedo_foam_a, (mask_foam * foam_amount + mask_beach_waves) + (height_gerstner.y + height_gerstner_2.y) * foam_gerstner );
	normal_output = mix(normal_output, normal_output + normal_foam_a, (mask_foam * foam_amount + mask_beach_waves) + (height_gerstner.y + height_gerstner_2.y) * foam_gerstner );

	// BEACH
	normal_output = mix(normal_output, vec3(0.5, 0.5, 1.0), clamp(smoothstep(0.0, depth, beach_normal_fadeout) + mask_beach_waves, 0.5, 1.0)); // smooth out
	float alpha_output = 1.0 - smoothstep(0.0, depth, beach_alpha_fadeout);

	ALBEDO = clamp(albedo_output, 0.0, 1.0);
	NORMAL_MAP = clamp(normal_output, 0.0, 1.0);
	SPECULAR = 0.6;
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	ALPHA = alpha_output;
}

void light() {
	// LAMBER DIFFUSE LIGHTING
	float water_highlight_mask_1 = texture(water_highlight_map, ( UV - (MODEL_MATRIX[3].xz * 0.25) + TIME * 0.051031 ) ).x;
	float water_highlight_mask_2 = texture(water_highlight_map, ( UV - (MODEL_MATRIX[3].xz * 0.25) + TIME * -0.047854) * 2.0 ).x;

	// SUBSURFACE SCATTERING
	float sss = clamp( smoothstep(0.65, 0.7, dot(NORMAL, VIEW) * 0.5 + 0.5 ) * smoothstep(0.5, 1.0, (dot(-LIGHT, VIEW) * 0.5 + 0.5) ) * ( dot (-VIEW_MATRIX[2].xyz, vec3(0.0, 1.0, 0.0)) * 0.5 + 0.5), 0.0, 1.0) * sss_strength;

	float lambert = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float spec = clamp( pow( dot( reflect(LIGHT, NORMAL), -VIEW), 1000.0), 0.0, 1.0) * 2.0;
	float spec_glare = clamp( pow( dot( reflect(LIGHT, NORMAL), -VIEW), 100.0), 0.0, 1.0) * smoothstep(0.0, 0.1, water_highlight_mask_1 * water_highlight_mask_2) * 30.0;

	DIFFUSE_LIGHT += (LIGHT_COLOR * ALBEDO * ATTENUATION / PI) * lambert;
	DIFFUSE_LIGHT += (LIGHT_COLOR * ALBEDO * ATTENUATION / PI) * sss;
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * (spec + spec_glare);
}