## Write-up 1

1. Your no-decode tile shows texel 128 as 188. How many times too much light does a mid-grey wall reflect if the decode is skipped? Work it out from Equation 1. The chapter says "about 2x" and uses 0.5^2.2. Give the exact factor and the factor with x^2.2.

It's the factor of c / L = 0.5020 / 0.2159 ≈ 2.325 times, using the exact piecewise curve.

With the chapter's `x^2.2` approximation instead: decoding 0.5 via `0.5^2.2 ≈ 0.2176` gives a factor of `0.5 / 0.2176 ≈ 2.298`, close to but not identical to the exact factor — which is the point of using the real piecewise curve instead of a plain power.

2. The wall in mode 0. On some brick, each spot on its own displays the byte 150, on both sides of the split. What does the overlap of the two spots display on the left, and what on the right? Where a pool has faded to a quarter of its centre's light, what does each side display? Work both out from Equation 1, then compare your screenshot. Why can an artist working in a gamma pipeline make one light look right, but never two?

**Setup.** At the chosen brick, one spot alone (either) displays byte 150 on both sides, i.e. `c = 150/255 = 0.588`. Decoding via Eq 1: `K = L(0.588) = 0.305` — this is the linear light one spot alone delivers there.

**Overlap.**
- *Left (correct):* two real lights add in linear space before the one final encode: `c(K + K) = c(0.610) ≈ 0.804` → **byte ≈ 205**.
- *Right (mode 0):* `srgb_wall.frag` instead adds the two *already-encoded* bytes directly: `0.588 + 0.588 = 1.176` → exceeds 1.0 → **clips to byte 255**.

Matches the screenshot: the right side's overlap is visibly blown out/clipped (reds pinned at 255) compared to the left's merely-brighter, unclipped overlap.

**Quarter-light falloff** (single spot dimmed to ¼ its centre intensity).
- *Left (correct):* falloff scales linear light before the encode: `c(K/4) = c(0.076) ≈ 0.306` → **byte ≈ 78**.
- *Right (mode 0):* falloff is applied as a flat post-encode multiply: `0.588 × 0.25 = 0.147` → **byte ≈ 38**.

The right side simply scales the byte linearly with the falloff factor; the left side runs the quarter-intensity light back through the nonlinear curve, landing over double the naive linear-byte expectation (78 vs 38) — because the sRGB curve is steep near black, so a true ¼-power physical dimming still reads brighter than a ¼ *byte* dimming would suggest.

**Why one light looks right but never two.** The gamma pipeline has one free parameter per light (its base colour constant), multiplied post-encode by falloff. An artist can tune that constant so the result matches the correct pipeline at *one* chosen brightness (e.g. the point they're staring at). But matching at every point along the same light's falloff would require `c_tex·c(W)·a = c(L(c_tex)·W·a)` to hold for *all* `a` — false for nonlinear `c`, as the 78-vs-38 mismatch above shows even for a single light once you move off the tuned point. Adding a second light makes it categorically worse: it needs `c(X)+c(Y) = c(X+Y)`, which is false for any nonlinear `c` regardless of tuning — no per-light calibration can fix how the lights *combine*.

3. A roughness map is loaded as SRGB by mistake. Is a roughness of 0.5 read as rougher or smoother, and by how much? Why is no image ever wrong this way for a metallic map that only holds 0 and 1?

It means the roughness 0.5 is the linear format. But it's mistakenly loaded as SRGB.
Then it would do L(c) converting c = 0.5 to L = 0.2159. Making the roughness less -> meaning smoother, by the same factor as question 1: 0.502 / 0.2159 ≈ 2.33x smoother than intended.

Metallic map only 0 and 1 would never get this wrong because L(0) = 0, c(0) = 0, L(1) = 1, and c(1) = 1.

4. The chapter's Python check (9.6.2) tests each channel separately against \[0.04, 0.9\]. Yours tests the luminance of each pixel. Find a texel in the test texture that one check flags and the other passes. Which check is right for a saturated red brick, and why?

From the code

 ```cpp
else if (brick == RED)
  value = c == 0 ? 200 : c == 1 ? 30 : 25;
 ```

So the texel to find is the RED brick. Bytes are (200, 30, 25). Decoded to linear, G ≈ 0.013 and B ≈ 0.0097, both under 0.04, so the per-channel check flags this texel as too dark. Its luminance is Y ≈ 0.13, which is inside [0.04, 0.9], so the luminance check passes it. The luminance check is right: a saturated red pigment naturally reflects almost no green or blue light, so near-zero individual channels are normal colour saturation, not baked-in shadow — only the overall perceived brightness (luminance) should flag an implausible albedo.

5. Generate an albedo texture with any image model (or download one), run Part I on it with `--albedo yours.png`, and look at mode 1. What fraction of it is too dark or too bright, and what in the picture caused it? Is there light and shadow painted into it (9.6.1, "baked lighting")?

Input texture: [./assets/texture-wood.jpg](./assets/texture-wood.jpg). Mode 1 result: [./report/srgb_yours.png](./report/srgb_yours.png).
There's only few too dark (20.4%) caused by the groove of the wood. There's no too light (0%).

## Write-up 2

## Write-up 3

### Prediction

### After

## Write-up 4

### Prediction

### After

## AI prompt log
