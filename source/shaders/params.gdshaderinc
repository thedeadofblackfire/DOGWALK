
uniform vec4 paper_color : source_color = vec4(1.,1.,1.,1.);
uniform bool backface_color;
uniform vec4 albedo_color : source_color = vec4(1,1,1,1);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D edge_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool edge_use_alpha = true;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_strength: hint_range(0.,10.,.01) = 1.;
uniform bool invert_normal;
uniform bool normal_use_uv2;
uniform ivec2 albedo_texture_size;
uniform float point_size : hint_range(0.1, 128.0, 0.1);

uniform float specular : hint_range(0.0, 1.0, 0.01) = .5;
uniform float roughness : hint_range(0.0, 1.0) = .5;
uniform sampler2D roughness_texture : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform float metallic : hint_range(0.0, 1.0, 0.01) = 0.;
uniform sampler2D metallic_texture : hint_default_white, filter_linear_mipmap, repeat_enable;

uniform float wear_strength : hint_range(0., 1., 0.01) = 0.;
uniform float wear_start : hint_range(0., 1., 0.01) = 0.;
uniform float wear_end : hint_range(0., 1., 0.01) = 1.;
uniform float wear_distortion_scale : hint_range(0., 100., 0.01) = 100.;
uniform float wear_distortion_strength : hint_range(0., 1., 0.01) = 1.;

uniform float emission_strength;
uniform sampler2D emission_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 emission_color : source_color = vec4(0, 0, 0, 1);

uniform float displacement_strength : hint_range(0., 1., 0.01) = 0.;
uniform float displacemnent_scale : hint_range(0., 1., 0.01) = 1.;

uniform float heightmap_scale : hint_range(0., 16.0, 0.001) = .5;
uniform int heightmap_min_layers : hint_range(1, 64) = 4;
uniform int heightmap_max_layers : hint_range(1, 64) = 16;

uniform vec3 uv1_scale = vec3(1,1,1);
uniform vec3 uv1_offset;
uniform vec3 uv2_scale = vec3(1,1,1);
uniform vec3 uv2_offset;

//global uniform vec3 chocomel_position;
//global uniform vec3 pinda_position;

//instance uniform float chocomel_bloat = 0.;

varying vec2 UV_normal;