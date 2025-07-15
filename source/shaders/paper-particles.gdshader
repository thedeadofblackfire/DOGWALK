shader_type spatial;
render_mode blend_mix, depth_test_disabled, cull_disabled, diffuse_burley, specular_schlick_ggx, depth_prepass_alpha;

uniform bool flip_normals;

uniform vec4 paper_color : source_color = vec4(1.,1.,1.,1.);
uniform vec4 albedo_color : source_color = vec4(1,1,1,1);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_strength: hint_range(0.,10.,.01) = 1.;
uniform bool invert_normal;
uniform ivec2 albedo_texture_size;
uniform float point_size : hint_range(0.1, 128.0, 0.1);

uniform float specular : hint_range(0.0, 1.0, 0.01) = .5;
uniform float roughness : hint_range(0.0, 1.0) = .5;
uniform sampler2D roughness_texture : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform float metallic : hint_range(0.0, 1.0, 0.01) = 0.;
uniform sampler2D metallic_texture : hint_default_white, filter_linear_mipmap, repeat_enable;

uniform float heightmap_scale : hint_range(0., 16.0, 0.001) = .5;
uniform int heightmap_min_layers : hint_range(1, 64) = 4;
uniform int heightmap_max_layers : hint_range(1, 64) = 16;

uniform vec3 uv1_scale = vec3(1,1,1);
uniform vec3 uv1_offset;
uniform vec3 uv2_scale = vec3(1,1,1);
uniform vec3 uv2_offset;

#include "./uv_tile_selection.gdshaderinc"

vec2 random(vec2 uv){
    uv = vec2( dot(uv, vec2(127.1,311.7) ),
               dot(uv, vec2(269.5,183.3) ) );
    return -1.0 + 2.0 * fract(sin(uv) * 43758.5453123);
}

void vertex() {
	UV = UV * uv1_scale.xy + uv1_offset.xy;
	UV2 = UV2 * uv2_scale.xy + uv2_offset.xy;

	int uv_tile_index = tile_index;
	if (random_tile_index) {
		uv_tile_index = int(random(vec2(COLOR.r)).x * float(rows * columns - 1));
	}

	UV = select_uv_tile(UV, uv_tile_index);
}

void fragment() {
	vec2 base_uv = UV;
	vec4 albedo_tex = texture(albedo_texture, UV);
	vec4 normal_tex;

	{
		normal_tex = texture(normal_texture, UV);
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

	float metallic_tex = texture(metallic_texture, base_uv).r;
	METALLIC = metallic_tex * metallic;
	SPECULAR = specular;

	vec4 roughness_texture_channel = vec4(1.0, 0.0, 0.0, 0.0);
	float roughness_tex = texture(roughness_texture, base_uv).r;
	ROUGHNESS = roughness_tex * roughness;

	if(flip_normals)
	{
		NORMAL = ((NORMAL * 2. - 1.) * -1. + 1. )*.5;
	}
}
