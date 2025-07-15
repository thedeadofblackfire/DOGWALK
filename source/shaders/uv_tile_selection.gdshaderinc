uniform int rows = 1;
uniform int columns = 1;
uniform int tile_index;
uniform bool random_tile_index;

vec2 select_uv_tile(vec2 uv, int index) {
	int i_x = index % columns;
	int i_y = int(index / columns);
	uv += vec2(float(i_x), float(i_y));
	uv /= vec2(float(columns), float(rows));
	return uv;
}