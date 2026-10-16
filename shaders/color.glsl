#ifndef COLOR_GLSL_INCLUDED
#define COLOR_GLSL_INCLUDED

// sRGB-encoded value (what the bytes of a colour texture mean) -> linear light.
// The exact piecewise curve, not pow(c, 2.2).
vec3 srgb_to_linear(vec3 c) {
  vec3 lo = c / 12.92;
  vec3 hi = pow((c + 0.055) / 1.055, vec3(2.4));
  return mix(lo, hi, step(vec3(0.04045), c));
}

// Linear light -> sRGB-encoded value (what the UNORM target and the screen expect).
// The exact inverse of srgb_to_linear.
vec3 linear_to_srgb(vec3 L) {
  vec3 lo = 12.92 * L;
  vec3 hi = 1.055 * pow(L, vec3(1 / 2.4)) - 0.055;
  return mix(lo, hi, step(vec3(0.0031308), L));
}

// A debug view for albedo textures: luminance of the LINEAR colour, too dark
// (< 0.04) shows blue, too bright (> 0.9) shows red, anything else shows that
// luminance as a grey, encoded for display.
vec3 albedo_check(vec3 lin) {
  float y = dot(vec3(0.2126, 0.7152, 0.0722), lin);

  vec3 blue = vec3(0.0, 0.0, 1.0);
  vec3 red = vec3(1.0, 0.0, 0.0);
  vec3 grey = vec3(y, y, y);

  vec3 linear = mix(
      blue,
      mix(
        grey,
        red,
        step(0.9, y)
      ),
      step(0.04, y)
    );

  return linear_to_srgb(linear);
}

#endif
