
#include "./noise.gdshaderinc"

vec3 wind_offset(vec3 position, float strength, float scale) {

	float stepped_time = TIME - mod(TIME, .08);

	vec4 co = vec4(position, 0.)*.1;
	co.w = stepped_time * .8;

	vec4 co2 = co;
	vec4 co3 = co;
	co2.x = co.y;
	co2.y = co.z;
	co2.z = co.x;
	co3.x = co.z;
	co3.y = co.x;
	co3.z = co.y;

	int detail = int(strength * 1.);
	float persistance = .2;
	vec3 offset = vec3(pNoise(co, detail, persistance), pNoise(co2, detail, persistance), pNoise(co3, detail, persistance));

	offset += vec3(cnoise(co + stepped_time * .1), 0., cnoise(co2 + stepped_time * .1)) * 4.;

	return offset * strength * .01;
}