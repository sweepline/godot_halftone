shader_type canvas_item;

// TODO: Cleanup, screen-space shader and CMY shader (check https://www.shadertoy.com/view/wsjGD1)

// Port of https://weber.itn.liu.se/~stegu76/webglshadertutorial/shadertutorial.html

uniform float aa_scale = 0.7;
/// there will be frequency^2 dots
uniform float frequency = 40.0;
/// radius is dependent on frequency
//uniform float radius = 0.5;
// radians
uniform float angle_c = 1.8326;
uniform float angle_m = 1.309;
uniform float angle_y = 1.5708;
uniform float angle_k = 0.261799;

float aastep(float threshold, float value) {
	float afwidth = aa_scale * length(vec2(dFdx(value), dFdy(value)));
	return smoothstep(threshold-afwidth, threshold+afwidth, value);
}
 
vec2 uv_rotated(float angle, vec2 uv) {
	// column major rotation matrix
	return mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * uv;
}

// Explicit bilinear texture lookup to circumvent bad hardware precision.
vec4 texture2D_bilinear(sampler2D tex, vec2 uv, vec2 texel_size) {
	vec2 f = fract( uv * vec2(textureSize(tex, 100)) );
    uv += ( .5 - f ) * texel_size;    // move uv to texel centre
	vec4 tl = texture(tex, uv);
	vec4 tr = texture(tex, uv + vec2(texel_size.x, 0.0));
	vec4 bl = texture(tex, uv + vec2(0.0, texel_size.y));
	vec4 br = texture(tex, uv + vec2(texel_size.x, texel_size.y));
    vec4 tA = mix( tl, tr, f.x );
    vec4 tB = mix( bl, br, f.x );
    return mix( tA, tB, f.y );
}

// Explicit bilinear texture lookup to circumvent bad hardware precision.
// Alternative version that result in same result as using COLOR
vec4 texture2D_bilinear_alt(sampler2D tex, vec2 st, vec2 texel_size) {
	vec2 uvv = st * vec2(textureSize(tex, 0));
	vec2 uv00 = floor(uvv - vec2(0.5)); // Lower left corner of lower left texel
	vec2 uvlerp = uvv - uv00 - vec2(0.5); // Texel-local lerp blends [0,1]
	vec2 uv = (uv00 + vec2(0.5)) * texel_size;
	vec4 tl = texture(tex, uv);
	vec4 tr = texture(tex, uv + vec2(texel_size.x, 0.0));
	vec4 bl = texture(tex, uv + vec2(0.0, texel_size.y));
	vec4 br = texture(tex, uv + vec2(texel_size.x, texel_size.y));
    vec4 tA = mix( tl, tr, uvlerp.x );
    vec4 tB = mix( bl, br, uvlerp.x );
    return mix( tA, tB, uvlerp.y );
}

// Description : Array- and textureless GLSL 2D simplex noise.
// Author : Ian McEwan, Ashima Arts. Version: 20110822
// Copyright (C) 2011 Ashima Arts. All rights reserved.
// Distributed under the MIT License. See LICENSE file.
// https://github.com/ashima/webgl-noise
vec2 mod2_289(vec2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec3 mod3_289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec3 permute(vec3 x) { return mod3_289((( x * 34.0) + 1.0) * x); }
 
float snoise(vec2 v) {
	const vec4 C = vec4(0.211324865405187,  // (3.0-sqrt(3.0))/6.0
	                    0.366025403784439,  // 0.5*(sqrt(3.0)-1.0)
	                    -0.577350269189626,  // -1.0 + 2.0 * C.x
	                    0.024390243902439); // 1.0 / 41.0
	// First corner
	vec2 i = floor(v + dot(v, C.yy) );
	vec2 x0 = v - i + dot(i, C.xx);
	// Other corners
	vec2 i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
	vec4 x12 = x0.xyxy + C.xxzz;
	x12.xy -= i1;
	// Permutations
	i = mod2_289(i); // Avoid truncation effects in permutation
	vec3 p = permute( permute( i.y + vec3(0.0, i1.y, 1.0 ))
	                        + i.x + vec3(0.0, i1.x, 1.0 ));
	vec3 m = max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy),
	                        dot(x12.zw,x12.zw)), 0.0);
	m = m*m; m = m*m;
	// Gradients
	vec3 x = 2.0 * fract(p * C.www) - 1.0;
	vec3 h = abs(x) - 0.5;
	vec3 a0 = x - floor(x + 0.5);
	// Normalise gradients implicitly by scaling m
	m *= 1.792843 - 0.853735 * ( a0*a0 + h*h );
	// Compute final noise value at P
	vec3 g;
	g.x = a0.x * x0.x + h.x * x0.y;
	g.yz = a0.yz * x12.xz + h.yz * x12.yw;
	return 130.0 * dot(m, g);
}

void fragment() {
	// Use a texture to modulate the size of the dots
	vec3 texcolor = texture2D_bilinear_alt(TEXTURE, UV, TEXTURE_PIXEL_SIZE).rgb;
	
	// Fractal noise
	float n = 0.1 * snoise(UV * 200.0);
	n += 0.05 * snoise(UV * 400.0);
	n += 0.025 * snoise(UV * 800.0);

	// Perform a rough RGB-to-CMYK conversion
    vec4 cmyk;
    cmyk.xyz = 1.0 - texcolor;
    cmyk.w = min(cmyk.x, min(cmyk.y, cmyk.z)); // Create K
    cmyk.xyz -= cmyk.w; // Subtract K equivalent from CMY
	
	// UVS
	vec2 uv_k = frequency * uv_rotated(angle_k, UV);
	vec2 nearest_k = 2.0 * fract(uv_k) - 1.0;
	float k = aastep(0.0, sqrt(cmyk.w)-length(nearest_k) + n);
	vec2 uv_c = frequency * uv_rotated(angle_c, UV);
	vec2 nearest_c = 2.0 * fract(uv_c) - 1.0;
	float c = aastep(0.0, sqrt(cmyk.x)-length(nearest_c) + n);
	vec2 uv_m = frequency * uv_rotated(angle_m, UV);
	vec2 nearest_m = 2.0 * fract(uv_m) - 1.0;
	float m = aastep(0.0, sqrt(cmyk.y)-length(nearest_m) + n);
	vec2 uv_y = frequency * uv_rotated(angle_y, UV);
	vec2 nearest_y = 2.0 * fract(uv_y) - 1.0;
	float y = aastep(0.0, sqrt(cmyk.z)-length(nearest_y) + n);

	vec3 white = vec3(n*0.5 + 0.98);
	vec3 black = vec3(n * 1.2);
	
	vec3 rgbscreen = 1.0 - 0.9*vec3(c,m,y) + n;
	rgbscreen = mix(rgbscreen, black, 0.85 * k + 0.3 * n);
	
	// Blend to regular tex at small sizes
	float afwidth = 2.0 * frequency * max(length(dFdx(UV)), length(dFdy(UV)));
	float blend = smoothstep(0.4, 2.2, afwidth);
	COLOR = vec4(mix(rgbscreen, texcolor, blend), 1.0);
}
