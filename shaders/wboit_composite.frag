#version 450
#extension GL_GOOGLE_include_directive : require

#include <params.glsl>

layout(location = 0) in vec2 inUV;

layout(location = 0) out vec4 outColor;

void main() {
  ivec2 p = ivec2(gl_FragCoord.xy);

  // Read accum (tex0) and reveal (tex1, .r) at p with texelFetch.
  // Where nothing transparent was drawn (reveal 1), leave the scene alone. Elsewhere
  // output the weighted average colour accum.rgb / accum.a (keep the division away
  // from 0) with alpha 1 - reveal.
  // Until then alpha 0: the scene stays as it is.
  vec4 accum = texelFetch(tex0, p, 0);
  float reveal = texelFetch(tex1, p, 0).r;
  if (reveal >= 1.0) {
    outColor = vec4(0.0);
  } else {
    vec3 color = accum.rgb / max(accum.a, 1e-5);
    outColor = vec4(color, 1.0 - reveal);
  }
}
