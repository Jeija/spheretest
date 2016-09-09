uniform mat4 mWorldViewProj;

const float BS = 10.0;

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

	gl_Position = mWorldViewProj * pos;

	gl_FrontColor = gl_BackColor = gl_Color;
}
