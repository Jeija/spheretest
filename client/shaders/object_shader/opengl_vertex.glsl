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

	vec4 pos = mWorld * gl_Vertex;

#ifdef ENABLE_PLANET
	vec3 camPos = eyePosition.xyz;
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

	gl_Position = mWorldViewProj * mInvWorld * pos;

	vPosition = gl_Position.xyz;
	worldPosition = (mWorld * gl_Vertex).xyz;

	vec3 sunPosition = vec3 (0.0, eyePosition.y * BS + 900.0, 0.0);

	lightVec = sunPosition - worldPosition;
	eyeVec = -(gl_ModelViewMatrix * gl_Vertex).xyz;

	gl_FrontColor = gl_BackColor = gl_Color;
}
