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

const float e = 2.718281828459;
const float BS = 10.0;

float smoothCurve(float x)
{
	return x * x * (3.0 - 2.0 * x);
}
float triangleWave(float x)
{
	return abs(fract( x + 0.5 ) * 2.0 - 1.0);
}
float smoothTriangleWave(float x)
{
	return smoothCurve(triangleWave( x )) * 2.0 - 1.0;
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

/*
 * Complex Number functions
 */
#define cplx vec2
#define cplx_new(re, im) vec2(re, im)
#define cplx_re(z) z.x
#define cplx_im(z) z.y
#define cplx_exp(z) (exp(z.x) * cplx_new(cos(z.y), sin(z.y)))
#define cplx_scale(z, scalar) (z * scalar)
#define cplx_abs(z) (sqrt(z.x * z.x + z.y * z.y))

void main(void)
{
	gl_TexCoord[0] = gl_MultiTexCoord0;

	vec4 pos = gl_Vertex;

#ifdef ENABLE_PLANET
	mat4 viewModel = inverse(gl_ModelViewMatrix);
	vec3 camPos = viewModel[3].xyz;
	float rp = PLANET_RADIUS * BS * 16;

#ifdef PLANET_KEEP_SCALE
	// Complex approach
	vec2 planedir = normalize(vec2(pos.x - camPos.x, pos.z - camPos.z));
	cplx plane = cplx_new(pos.y - camPos.y, sqrt((pos.x - camPos.x) * (pos.x - camPos.x) + (pos.z - camPos.z) * (pos.z - camPos.z)));
	cplx circle = rp * cplx_exp(cplx_scale(plane, 1.0 / rp)) - cplx_new(rp, 0);
	pos.x = cplx_im(circle) * planedir.x + camPos.x;
	pos.z = cplx_im(circle) * planedir.y + camPos.z;
	pos.y = cplx_re(circle) + camPos.y;
#else
	// Naive approach
	vec2 planedir = normalize(vec2(pos.x - camPos.x, pos.z - camPos.z));
	vec2 plane = vec2(pos.y + rp, sqrt((pos.x - camPos.x) * (pos.x - camPos.x) + (pos.z - camPos.z) * (pos.z - camPos.z)));
	vec2 circle = plane.x * vec2(cos(plane.y / rp), sin(plane.y / rp)) - vec2(rp, 0);
	pos.x = circle.y * planedir.x + camPos.x;
	pos.z = circle.y * planedir.y + camPos.z;
	pos.y = circle.x;
#endif

	// Code for not scaling nodes so that their size close to the player is normal.
	// Nodes that are higher up will appear larger (compared to the player).
	// Due to distortions you won't be able to dig / build blocks normally though.
	//vec2 planedir = normalize(vec2(pos.x - camPos.x, pos.z - camPos.z));
	//cplx plane = cplx_new(pos.y, sqrt((pos.x - camPos.x) * (pos.x - camPos.x) + (pos.z - camPos.z) * (pos.z - camPos.z)));
	//cplx circle = rp * cplx_exp(cplx_scale(plane, 1.0 / rp)) - cplx_new(rp, 0);
	//pos.x = cplx_im(circle) * planedir.x + camPos.x;
	//pos.z = cplx_im(circle) * planedir.y + camPos.z;
	//pos.y = cplx_re(circle);
#endif

#if (MATERIAL_TYPE == TILE_MATERIAL_LIQUID_TRANSPARENT || MATERIAL_TYPE == TILE_MATERIAL_LIQUID_OPAQUE) && ENABLE_WAVING_WATER
	pos.y -= 2.0;

	float posYbuf = (pos.z / WATER_WAVE_LENGTH + animationTimer * WATER_WAVE_SPEED * WATER_WAVE_LENGTH);

	pos.y -= sin(posYbuf) * WATER_WAVE_HEIGHT + sin(posYbuf / 7.0) * WATER_WAVE_HEIGHT;
	gl_Position = mWorldViewProj * pos;
#elif MATERIAL_TYPE == TILE_MATERIAL_WAVING_LEAVES && ENABLE_WAVING_LEAVES
	vec4 pos2 = mWorld * pos;
	/*
	 * Mathematic optimization: pos2.x * A + pos2.z * A (2 multiplications + 1 addition)
	 * replaced with: (pos2.x + pos2.z) * A (1 addition + 1 multiplication)
	 * And bufferize calcul to a float
	 */
	float pos2XpZ = pos2.x + pos2.z;
	pos.x += (smoothTriangleWave(animationTimer*10.0 + pos2XpZ * 0.01) * 2.0 - 1.0) * 0.4;
	pos.y += (smoothTriangleWave(animationTimer*15.0 + pos2XpZ * -0.01) * 2.0 - 1.0) * 0.2;
	pos.z += (smoothTriangleWave(animationTimer*10.0 + pos2XpZ * -0.01) * 2.0 - 1.0) * 0.4;
	gl_Position = mWorldViewProj * pos;
#elif MATERIAL_TYPE == TILE_MATERIAL_WAVING_PLANTS && ENABLE_WAVING_PLANTS
	vec4 pos2 = mWorld * pos;
	if (gl_TexCoord[0].y < 0.05) {
		/*
		 * Mathematic optimization: pos2.x * A + pos2.z * A (2 multiplications + 1 addition)
		 * replaced with: (pos2.x + pos2.z) * A (1 addition + 1 multiplication)
		 * And bufferize calcul to a float
		 */
		float pos2XpZ = pos2.x + pos2.z;
		pos.x += (smoothTriangleWave(animationTimer * 20.0 + pos2XpZ * 0.1) * 2.0 - 1.0) * 0.8;
		pos.y -= (smoothTriangleWave(animationTimer * 10.0 + pos2XpZ * -0.5) * 2.0 - 1.0) * 0.4;
	}
	gl_Position = mWorldViewProj * pos;
#else
	gl_Position = mWorldViewProj * pos;
#endif

	vPosition = gl_Position.xyz;
	worldPosition = (mWorld * pos).xyz;
	vec3 sunPosition = vec3 (0.0, eyePosition.y * BS + 900.0, 0.0);

	vec3 normal, tangent, binormal;
	normal = normalize(gl_NormalMatrix * gl_Normal);
	if (gl_Normal.x > 0.5) {
		//  1.0,  0.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 0.0,  0.0, -1.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	} else if (gl_Normal.x < -0.5) {
		// -1.0,  0.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	} else if (gl_Normal.y > 0.5) {
		//  0.0,  1.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
	} else if (gl_Normal.y < -0.5) {
		//  0.0, -1.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
	} else if (gl_Normal.z > 0.5) {
		//  0.0,  0.0,  1.0
		tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	} else if (gl_Normal.z < -0.5) {
		//  0.0,  0.0, -1.0
		tangent  = normalize(gl_NormalMatrix * vec3(-1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	}
	mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
							tangent.y, binormal.y, normal.y,
							tangent.z, binormal.z, normal.z);

	lightVec = sunPosition - worldPosition;
	tsLightVec = lightVec * tbnMatrix;
	eyeVec = (gl_ModelViewMatrix * gl_Vertex).xyz;
	tsEyeVec = eyeVec * tbnMatrix;

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
	b += max(0.0, (1.0 - abs(b - 0.13)/0.17) * 0.025);

	// Artificial light is yellow-ish
	// See C++ implementation in mapblock_mesh.cpp finalColorBlend()
	rg += max(0.0, (1.0 - abs(rg - 0.85)/0.15) * 0.065);

	color.r = rg;
	color.g = rg;
	color.b = b;

	color.a = gl_Color.a;
	gl_FrontColor = gl_BackColor = clamp(color,0.0,1.0);
}
