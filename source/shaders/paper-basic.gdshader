// NOTE: Shader automatically converted from Godot Engine 4.4.beta1's StandardMaterial3D.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx, depth_prepass_alpha;

#include "./noise.gdshaderinc"
#include "./wind.gdshaderinc"

uniform bool fake_depth = false;
uniform bool flip_normals;

#include "./params.gdshaderinc"

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
}

void fragment() {
	vec2 base_uv = UV;
	vec4 albedo_tex = texture(albedo_texture, UV);
	vec4 normal_tex;

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
	ALBEDO = mix(paper_color.rgb, ALBEDO, float(FRONT_FACING));
	ALPHA *= albedo_color.a * albedo_tex.a;
	if(COLOR.a<1.){
		ALPHA *= COLOR.a;
	}
	ALPHA_SCISSOR_THRESHOLD = 0.2;

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

	EMISSION = emission_color.rgb * emission_strength;
}
