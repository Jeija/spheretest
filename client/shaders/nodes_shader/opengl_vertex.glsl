uniform mat4 mWorldViewProj;
uniform mat4 mInvWorld;
uniform mat4 mTransWorld;
uniform mat4 mWorld;

uniform float dayNightRatio;
uniform vec3 eyePosition;
uniform float animationTimer;

varying vec3 vPosition;
varying vec3 worldPosition;

varying vec3 eyeVec;
varying vec3 lightVec;
varying vec3 tsEyeVec;
varying vec3 tsLightVec;
varying float area_enable_parallax;

const float e = 2.718281828459;
const float BS = 10.0;


float smoothCurve(float x)
{
	return x * x * (3.0 - 2.0 * x);
}


float triangleWave(float x)
{
	return abs(fract(x + 0.5) * 2.0 - 1.0);
}


float smoothTriangleWave(float x)
{
	return smoothCurve(triangleWave(x)) * 2.0 - 1.0;
}

/*
 * inverse(mat4 m) function:
 * This GLSL version doesn't have inverse builtin, using version from https://github.com/stackgl/glsl-inverse
 * (c) 2014 Mikola Lysenko. MIT License
 */
mat4 inverse(mat4 m) {
	float
		a00 = m[0][0], a01 = m[0][1], a02 = m[0][2], a03 = m[0][3],
		a10 = m[1][0], a11 = m[1][1], a12 = m[1][2], a13 = m[1][3],
		a20 = m[2][0], a21 = m[2][1], a22 = m[2][2], a23 = m[2][3],
		a30 = m[3][0], a31 = m[3][1], a32 = m[3][2], a33 = m[3][3],

		b00 = a00 * a11 - a01 * a10,
		b01 = a00 * a12 - a02 * a10,
		b02 = a00 * a13 - a03 * a10,
		b03 = a01 * a12 - a02 * a11,
		b04 = a01 * a13 - a03 * a11,
		b05 = a02 * a13 - a03 * a12,
		b06 = a20 * a31 - a21 * a30,
		b07 = a20 * a32 - a22 * a30,
		b08 = a20 * a33 - a23 * a30,
		b09 = a21 * a32 - a22 * a31,
		b10 = a21 * a33 - a23 * a31,
		b11 = a22 * a33 - a23 * a32,

		det = b00 * b11 - b01 * b10 + b02 * b09 + b03 * b08 - b04 * b07 + b05 * b06;

	return mat4(
		a11 * b11 - a12 * b10 + a13 * b09,
		a02 * b10 - a01 * b11 - a03 * b09,
		a31 * b05 - a32 * b04 + a33 * b03,
		a22 * b04 - a21 * b05 - a23 * b03,
		a12 * b08 - a10 * b11 - a13 * b07,
		a00 * b11 - a02 * b08 + a03 * b07,
		a32 * b02 - a30 * b05 - a33 * b01,
		a20 * b05 - a22 * b02 + a23 * b01,
		a10 * b10 - a11 * b08 + a13 * b06,
		a01 * b08 - a00 * b10 - a03 * b06,
		a30 * b04 - a31 * b02 + a33 * b00,
		a21 * b02 - a20 * b04 - a23 * b00,
		a11 * b07 - a10 * b09 - a12 * b06,
		a00 * b09 - a01 * b07 + a02 * b06,
		a31 * b01 - a30 * b03 - a32 * b00,
		a20 * b03 - a21 * b01 + a22 * b00) / det;
}

void main(void)
{
	gl_TexCoord[0] = gl_MultiTexCoord0;
	//TODO: make offset depending on view angle and parallax uv displacement
	//thats for textures that doesnt align vertically, like dirt with grass
	//gl_TexCoord[0].y += 0.008;

	//Allow parallax/relief mapping only for certain kind of nodes
	//Variable is also used to control area of the effect
#if (DRAW_TYPE == NDT_NORMAL || DRAW_TYPE == NDT_LIQUID || DRAW_TYPE == NDT_FLOWINGLIQUID)
	area_enable_parallax = 1.0;
#else
	area_enable_parallax = 0.0;
#endif


float disp_x;
float disp_z;
#if (MATERIAL_TYPE == TILE_MATERIAL_WAVING_LEAVES && ENABLE_WAVING_LEAVES) || (MATERIAL_TYPE == TILE_MATERIAL_WAVING_PLANTS && ENABLE_WAVING_PLANTS)
	vec4 pos2 = mWorld * gl_Vertex;
	float tOffset = (pos2.x + pos2.y) * 0.001 + pos2.z * 0.002;
	disp_x = (smoothTriangleWave(animationTimer * 23.0 + tOffset) +
		smoothTriangleWave(animationTimer * 11.0 + tOffset)) * 0.4;
	disp_z = (smoothTriangleWave(animationTimer * 31.0 + tOffset) +
		smoothTriangleWave(animationTimer * 29.0 + tOffset) +
		smoothTriangleWave(animationTimer * 13.0 + tOffset)) * 0.5;
#endif

	vec4 pos = gl_Vertex;

#ifdef ENABLE_PLANET
	mat4 viewModel = inverse(gl_ModelViewMatrix);
	vec3 camPos = viewModel[3].xyz;

	// Step 1: Transform normal coordinates into coordinates as if they were on a sphere
	float radius = PLANET_RADIUS * BS * 16 + pos.y;
	float xangle = (pos.x - camPos.x) / (PLANET_RADIUS * BS * 16);
	float zangle = (pos.z - camPos.z) / (PLANET_RADIUS * BS * 16);
	float distangle = pow(xangle * xangle + zangle * zangle, 0.5);

	// Step 2: Transform back from spherical coordinates to cartesian system with
	// the center of the planet in the origin of the coordinate system.
	float planet_x = sin(xangle) * radius;
	float planet_z = sin(zangle) * radius;
	float planet_y = cos(distangle) * radius;

	// Step 3: Translate coordinates so that they are relative to the camera, not the planet center
	// The planet center is *always* position PLANET_RADIUS underneath the player
	pos.y = planet_y - (PLANET_RADIUS * BS * 16);
	pos.x = camPos.x + planet_x;
	pos.z = camPos.z + planet_z;
#endif

#if (MATERIAL_TYPE == TILE_MATERIAL_LIQUID_TRANSPARENT || MATERIAL_TYPE == TILE_MATERIAL_LIQUID_OPAQUE) && ENABLE_WAVING_WATER
	pos.y -= 2.0;
	float posYbuf = (pos.z / WATER_WAVE_LENGTH + animationTimer * WATER_WAVE_SPEED * WATER_WAVE_LENGTH);
	pos.y -= sin(posYbuf) * WATER_WAVE_HEIGHT + sin(posYbuf / 7.0) * WATER_WAVE_HEIGHT;
#elif MATERIAL_TYPE == TILE_MATERIAL_WAVING_LEAVES && ENABLE_WAVING_LEAVES
	pos.x += disp_x;
	pos.y += disp_z * 0.1;
	pos.z += disp_z;
#elif MATERIAL_TYPE == TILE_MATERIAL_WAVING_PLANTS && ENABLE_WAVING_PLANTS
	if (gl_TexCoord[0].y < 0.05) {
		pos.x += disp_x;
		pos.z += disp_z;
	}
#endif
	gl_Position = mWorldViewProj * pos;


	vPosition = gl_Position.xyz;
	worldPosition = (mWorld * gl_Vertex).xyz;

	// Don't generate heightmaps when too far from the eye
	float dist = distance (vec3(0.0, 0.0, 0.0), vPosition);
	if (dist > 150.0) {
		area_enable_parallax = 0.0;
	}

	vec3 sunPosition = vec3 (0.0, eyePosition.y * BS + 900.0, 0.0);

	vec3 normal, tangent, binormal;
	normal = normalize(gl_NormalMatrix * gl_Normal);
	tangent = normalize(gl_NormalMatrix * gl_MultiTexCoord1.xyz);
	binormal = normalize(gl_NormalMatrix * gl_MultiTexCoord2.xyz);

	vec3 v;

	lightVec = sunPosition - worldPosition;
	v.x = dot(lightVec, tangent);
	v.y = dot(lightVec, binormal);
	v.z = dot(lightVec, normal);
	tsLightVec = normalize (v);

	eyeVec = -(gl_ModelViewMatrix * gl_Vertex).xyz;
	v.x = dot(eyeVec, tangent);
	v.y = dot(eyeVec, binormal);
	v.z = dot(eyeVec, normal);
	tsEyeVec = normalize (v);

	vec4 color;
	float day = gl_Color.r;
	float night = gl_Color.g;
	float light_source = gl_Color.b;

	float rg = mix(night, day, dayNightRatio);
	rg += light_source * 2.5; // Make light sources brighter
	float b = rg;

	// Moonlight is blue
	b += (day - night) / 13.0;
	rg -= (day - night) / 23.0;

	// Emphase blue a bit in darker places
	// See C++ implementation in mapblock_mesh.cpp finalColorBlend()
	b += max(0.0, (1.0 - abs(b - 0.13) / 0.17) * 0.025);

	// Artificial light is yellow-ish
	// See C++ implementation in mapblock_mesh.cpp finalColorBlend()
	rg += max(0.0, (1.0 - abs(rg - 0.85) / 0.15) * 0.065);

	color.r = rg;
	color.g = rg;
	color.b = b;

	color.a = gl_Color.a;
	gl_FrontColor = gl_BackColor = clamp(color, 0.0, 1.0);
}
