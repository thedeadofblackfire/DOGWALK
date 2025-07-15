// NOTE: Shader automatically converted from Godot Engine 4.4.beta1's StandardMaterial3D.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx, depth_prepass_alpha;

#include "./noise.gdshaderinc"
#include "./wind.gdshaderinc"

uniform bool fake_depth = false;
uniform bool flip_normals;

uniform bool depth_blend = false;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture;

#include "./params.gdshaderinc"

varying vec3 view_space_tangent;
varying vec3 view_space_normal;

const int bayer_n = 4;

void vertex() {
	UV = UV * uv1_scale.xy + uv1_offset.xy;
	UV2 = UV2 * uv2_scale.xy + uv2_offset.xy;

	if(normal_use_uv2)
	{
		UV_normal = UV2;
	}
	else
	{
		UV_normal = UV;
	}

	// dodging trees
	if(false)
	{
		vec3 view_space_coord = (MODELVIEW_MATRIX * vec4(VERTEX, 1.)).xyz;
		vec3 trimmed_view_space_coord = (MODELVIEW_MATRIX * vec4(VERTEX * vec3(0.,1.,0.), 1.)).xyz;
		vec3 world_coord = (INV_VIEW_MATRIX * vec4(trimmed_view_space_coord, 1.)).xyz;
		vec3 view_position = (INV_VIEW_MATRIX * vec4(vec3(0.), 1.)).xyz;
		float height_falloff = world_coord.y;
		float morph_distance = 5.;
		float blend = clamp((morph_distance - length(world_coord.xz-view_position.xz))/morph_distance, 0., 1.) * height_falloff * .5;
		vec3 offset = normalize(trimmed_view_space_coord * vec3(1.,0.,.01));
		VERTEX = (inverse(MODELVIEW_MATRIX) * vec4(view_space_coord + offset * blend, 1.)).xyz;
	}

	view_space_tangent = normalize(mat3(MODELVIEW_MATRIX) * TANGENT);
	view_space_normal = normalize(mat3(MODELVIEW_MATRIX) * NORMAL);

	vec3 global_pos = (inverse(MODEL_MATRIX) * vec4(VERTEX, 1.)).xyz;
	VERTEX += inverse(MODEL_NORMAL_MATRIX) * wind_offset(global_pos, displacement_strength * length(VERTEX), displacemnent_scale);

	//if (chocomel_bloat != 0.) {
		//vec3 chocomel_difference = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - chocomel_position;
		//vec3 warp_offset = mix(1., 0., clamp(length(chocomel_difference) / 2., 0., 1.)) * normalize(chocomel_difference);
		//VERTEX += inverse(MODEL_NORMAL_MATRIX) * warp_offset * chocomel_bloat * .5;
	//}
}

void fragment() {
	vec2 base_uv = UV;
	vec4 albedo_tex = texture(albedo_texture, UV);
	vec4 emission_tex = texture(emission_texture, UV);
	vec4 normal_tex;

	if(depth_blend)
	{
		ivec2 pixel_coord = ivec2(FRAGCOORD.xy);

		float bayer_matrix_0[4] = float[4](-0.5,0.,-0.375,0.125);
		float bayer_matrix_1[4] = float[4](0.25,-0.25,0.375,-0.125);
		float bayer_matrix_2[4] = float[4](-0.3125,0.1875,-0.4375,0.0625);
		float bayer_matrix_3[4] = float[4](0.4375,-0.0625,0.3125,-0.1875);

		float bayer_tex;
		if(pixel_coord.y % 4 == 0)
		{
			bayer_tex = bayer_matrix_0[(pixel_coord.x-pixel_coord.y) % 4];
		}
		else if(pixel_coord.y % 4 == 1)
		{
			bayer_tex = bayer_matrix_1[(pixel_coord.x-pixel_coord.y) % 4];
		}
		else if(pixel_coord.y % 4 == 2)
		{
			bayer_tex = bayer_matrix_2[(pixel_coord.x-pixel_coord.y) % 4];
		}
		else if(pixel_coord.y % 4 == 3)
		{
			bayer_tex = bayer_matrix_3[(pixel_coord.x-pixel_coord.y) % 4];
		}

		bayer_tex += random(vec2(pixel_coord.xy)).x * .1;

		float depth = -VERTEX.z;

		float distance_min = 7.;
		float distance_max = 8.5;

		float blend = (depth-distance_min) / (distance_max-distance_min);

		blend += pow(abs(SCREEN_UV.x - .5) * 3., 2.) ;

		if(blend < bayer_tex)
		{
			discard;
		}
	}

	if(fake_depth && albedo_tex.a<.9)
	{
		// Height: Enabled
		vec3 view_dir = normalize(normalize(-VERTEX + EYE_OFFSET) * mat3(TANGENT, -BINORMAL, NORMAL));

		// Height Deep Parallax: Enabled
		float num_layers = mix(float(heightmap_max_layers), float(heightmap_min_layers), abs(dot(vec3(0.0, 0.0, 1.0), view_dir)));
		float layer_depth = 1.0 / num_layers;
		float current_layer_depth = 0.0;
		vec2 dimension_scale = vec2(albedo_texture_size) / float(max(albedo_texture_size.x, albedo_texture_size.y));
		vec2 p = view_dir.xy * heightmap_scale * 0.01 * dimension_scale;
		vec2 delta = p / num_layers;
		vec2 ofs = base_uv;
		float depth = 1.0 - texture(albedo_texture, ofs).a;

		float current_depth = 0.0;
		while (current_depth < depth) {
			ofs -= delta;
			depth = 1.0 - texture(albedo_texture, ofs).a;

			current_depth += layer_depth;
		}

		vec2 prev_ofs = ofs + delta;
		float after_depth = depth - current_depth;
		float before_depth = (1.0 - texture(albedo_texture, prev_ofs).a) - current_depth + layer_depth;

		float weight = after_depth / (after_depth - before_depth);
		ofs = mix(ofs, prev_ofs, weight);

		vec2 rim_normal = vec2(dot(TANGENT, view_dir),dot(-BINORMAL, view_dir));
		vec3 view_tangent = vec3(rim_normal.x, rim_normal.y, sqrt(1.f-pow(rim_normal.x, 2.f)-pow(rim_normal.y, 2.f)));

		float texsize = 1024.f;
		float offset = 2./texsize;
		vec2 offsetX = vec2(offset, 0.);
		vec2 offsetY = vec2(0., offset);
		vec2 height_grad = vec2(0,0);
		int count = 0;
		vec2 shift[9] = vec2[9](
			vec2(0,0),
			vec2(0,1),
			vec2(1,1),
			vec2(1,0),
			vec2(1,-1),
			vec2(0,-1),
			vec2(-1,-1),
			vec2(-1,0),
			vec2(-1,1)
			);
		for(int i=0;i<9;++i)
		{
			vec2 coord = ofs+shift[i]/texsize;
			height_grad += vec2((texture(albedo_texture, coord-offsetX).r-texture(albedo_texture, coord+offsetX).r), (texture(albedo_texture, coord+offsetY).r-texture(albedo_texture, coord-offsetY).r));
			count += int(length(height_grad) > 0.);
		}
		height_grad = normalize(mix(vec2(0., 1.), height_grad, float(length(height_grad)>0.)));
		vec3 normal_map = vec3(height_grad, 0.)*0.5f+0.5f;
		float lerp_floor = 0.1f;
		NORMAL_MAP = mix(vec3(.5f, .5f, 1.f), normal_map, pow(max(depth/(1.f-lerp_floor)-lerp_floor, 0.), 0.2));
		albedo_tex = texture(albedo_texture, ofs);
		albedo_tex.rgb = mix(albedo_color.rgb * albedo_tex.rgb, paper_color.rgb, max(min(depth*50.f-.5f, 1.f), 0.f));
	}
	else
	{
		normal_tex = texture(normal_texture, UV_normal);
		normal_tex -= .5;
		if(invert_normal)
		{
			normal_tex *= vec4(-1,-1,1,1);
		}
		normal_tex *= vec4(normal_strength,normal_strength,1,1);
		normal_tex += .5;
		NORMAL_MAP = normal_tex.rgb;
	}
	ALBEDO = albedo_color.rgb * albedo_tex.rgb;
	if(!backface_color)
	{
		ALBEDO = mix(paper_color.rgb, ALBEDO, float(FRONT_FACING));
	}
	ALPHA *= albedo_color.a * albedo_tex.a;


	// Edge Rim
	if(fake_depth)
	{
		float rim_depth = 400.;

		rim_depth *= 2. * heightmap_scale;

		vec3 view_dir = VIEW;

		float depth = texture(DEPTH_TEXTURE, SCREEN_UV).r;
		vec3 offset = view_dir - view_space_normal*(dot(view_dir, view_space_normal));
		offset += noise2(UV * vec2(albedo_texture_size), 1., 2., 1.) * .2;
		vec2 offset_view;
		if (offset.z > 0.){
			offset_view = offset.xy;
		}
		offset_view = offset_view*rim_depth*depth/VIEWPORT_SIZE * vec2(-1., 1.);

		float depth_ref = texture(DEPTH_TEXTURE, SCREEN_UV-offset_view).r;

		float diff = max(0., (depth-depth_ref)*10.);
		float rim = min(max((diff-.001)*10., 0.), 1.);

		vec2 delta = rim_depth/VIEWPORT_SIZE*depth;
		vec2 depth_gradient = vec2(depth-texture(DEPTH_TEXTURE, SCREEN_UV+vec2(delta.x, 0.)).r, depth-texture(DEPTH_TEXTURE, SCREEN_UV+vec2(0., delta.y)).r);
		depth_gradient *= vec2(1., -1.);

		vec3 rim_normal = vec3(depth_gradient, 0.);
		rim_normal = rim_normal-dot(rim_normal, NORMAL)*NORMAL;

		rim_normal = vec3(dot(TANGENT, rim_normal), dot(BINORMAL, rim_normal), 0.);
		vec3 normal_map = rim_normal;
		normal_map = normal_map*.5+.5;

		ALBEDO = mix(ALBEDO, paper_color.rgb, rim * ALPHA);
		NORMAL_MAP = mix(NORMAL_MAP, normal_map, rim * ALPHA);
		ALPHA = pow(ALPHA, 0.1);
		//ALPHA_ANTIALIASING_EDGE = .01;
	}

	float metallic_tex = texture(metallic_texture, base_uv).r;
	METALLIC = metallic_tex * metallic;
	SPECULAR = specular;

	vec4 roughness_texture_channel = vec4(1.0, 0.0, 0.0, 0.0);
	float roughness_tex = texture(roughness_texture, base_uv).r;
	ROUGHNESS = roughness_tex * roughness;

	// PAPER WEAR
	float wear_mask = COLOR.g;
	wear_mask = wear_mask * (wear_mask + wear_distortion_strength * noise2(UV, wear_distortion_scale, 1., 1.));
	if(wear_end > wear_start)
	{
		wear_mask = (wear_mask - wear_start) / (wear_end - wear_start);
	}
	wear_mask = clamp(wear_mask, 0., 1.);
	wear_mask *= wear_strength;
	ALBEDO = mix(ALBEDO, paper_color.rgb, wear_mask);
	ROUGHNESS = ROUGHNESS + wear_mask;

	if(COLOR.a<1.){
		ALPHA *= COLOR.a;
	}

	// Edge Texture
	float edge_alpha;
	if(edge_use_alpha)
	{
		edge_alpha = texture(edge_texture, UV2).a;
	}
	else
	{
		edge_alpha = texture(edge_texture, UV2).r;
	}
	ALPHA *= edge_alpha;

	if(flip_normals)
	{
		NORMAL = ((NORMAL * 2. - 1.) * -1. + 1. )*.5;
	}

	EMISSION = emission_color.rgb * emission_tex.rgb * emission_strength;

}
