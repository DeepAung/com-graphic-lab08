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

1. Bind the DirectX map without the flip and let the light circle the sphere (the chapter's 360° test). Describe exactly what goes wrong and when: at which light positions do the bumps look right, and at which do they look like dents? Explain this from Equation 2.

When change to DirectX with knob = 0, and when use OpenGL with knob = 1: both shows weird lighting in a little circle. The shadow is diagonal with the main lighting. Which feels unnatural

Screenshots: [`report/normalmap_dx_noflip.png`](./report/normalmap_dx_noflip.png) (DirectX map, knob = 0, no flip) vs baseline [`report/normalmap.png`](./report/normalmap.png).

2. Bind the correct map as SRGB (key G). Which way do the normals tilt, and why does a flat area, (128, 128, 255), stop being flat? Compute the normal that this texel turns into.

Screenshot: [`report/normalmap_srgb_g.png`](./report/normalmap_srgb_g.png) (map bound through its SRGB view) vs the baseline [`report/normalmap.png`](./report/normalmap.png) — most of the sphere goes visibly darker, matching the expected "every normal leans the same way" artifact.

Normals tilt toward negative x and negative y. The sampler decodes the map with L(c) before my shader even touches it, and L(c) < c for every value except 0 and 1, so every mid-range byte gets pulled down. A flat texel (128, 128, 255) should decode to n = (0, 0, 1), but the x and y channels (byte 128 -> c = 0.502) get wrongly decoded to L(0.502) = 0.2159 first, then my `2v - 1` turns that into -0.568 instead of 0. The z channel is untouched since L(1) = 1 (fixed point). So the texel turns into n = (-0.568, -0.568, 1.0), normalized to about (-0.443, -0.443, 0.779) instead of (0, 0, 1).

3. The panel prints the mean length of the decoded normal at mip 0, 2, 4 and 6. Why does it shrink, and why does the chapter say to renormalise normal-map mips? After you renormalise, what has still been lost about the surface?

Mip levels are built by averaging neighbouring texels. That's fine for colour, but normal map bytes decode to unit vectors, and averaging vectors that point in different directions gives a shorter vector, not another unit one. Coarser mips average over a wider spread of bump directions, so the length shrinks more (0.89 by mip 6, one texel per bump).

Renormalizing matters because lighting does dot(N, L); a shrunk N darkens the surface for no physical reason. After renormalizing, the length is gone, and with it the info about how spread-out the normals were at that mip, so the surface still shades like it's perfectly smooth at every mip, instead of rougher/blurrier like a minified bumpy surface actually should look.

4. Run the 360° test on a normal map from an image model or from a texture site, with --normal yours.png. Which convention is it, and how did the test tell you?

Same test as 2.1: let the light circle with knob = 0 (no flip) and watch a full rotation. If bumps stay bumps the whole way round, it's OpenGL convention. If they look like dents and only fix once I flip (knob = 1), it's DirectX convention. No numeric readout for a custom map, just whichever knob stays bump-shaped through the whole rotation.

Used [`assets/normal-custom.png`](./assets/normal-custom.png) (generated procedurally, OpenGL convention by construction). Screenshots: [`report/normalmap_custom_knob0.png`](./report/normalmap_custom_knob0.png) (knob 0) vs [`report/normalmap_custom_knob1.png`](./report/normalmap_custom_knob1.png) (knob 1), zoomed at [`report/normalmap_custom_knob0_zoom.png`](./report/normalmap_custom_knob0_zoom.png) / [`report/normalmap_custom_knob1_zoom.png`](./report/normalmap_custom_knob1_zoom.png).

## Write-up 3

1. In your mode 2 picture, where is the anisotropy ratio above 4? Show that this is the same region where trilinear blurs the grout lines in mode 0. Use Equation 4 to explain why it sits there.

Screenshots: [`report/floor_mode2.png`](./report/floor_mode2.png) (ratio heat map) — the blue-to-warm edge sits close to the camera, matching the numbers below, not near the horizon. For comparison, [`report/floor.png`](./report/floor.png) is the default mode 0 trilinear view and [`report/floor_mode1.png`](./report/floor_mode1.png) is the mip-level band view (used in Q3.3 below).

From the probe table, ratio crosses 4 between 2.8 m (ratio 2.89) and 4.1 m (ratio 4.18) from the camera — the CPU check confirms it exactly: ratio > 4 starts at row 357 in the middle column, row 391 at the left edge (both ~3.9 m away), covering 37.7% of the floor's pixels. That's a few metres out, not just near the horizon. In mode 0 with trilinear, the grout lines start smearing into flat grey starting at roughly that same distance, because trilinear always picks its mip level from the *longer* footprint axis (ρ in Eq 3/4 uses `max`), so once the short axis is much shorter than the long one (ratio > 4), trilinear is already over-blurring the short axis to match the long one — it has no way to sharpen one direction while blurring the other, which is exactly what anisotropic filtering is for.

2. Your timing table against the chapter: 9.2.2 says anisotropic ×16 costs about 15% more than trilinear. What does it cost on your GPU, and how many texels does each filter actually read per pixel in the region where the ratio is 16?

On my GPU aniso16 costs 6.70x trilinear (1.405 ms vs 0.210 ms), nowhere near the chapter's ~15%. In the ratio-16 region, trilinear always reads 8 texels (bilinear, 2x2, at two mip levels, blended), while aniso16 takes up to 16 trilinear samples along the long axis there, i.e. up to 16 x 8 = 128 texels per pixel — 16x more texels than trilinear in that specific region. The measured 6.70x frame average is far below that 16x worst case because only 37.7% of the floor even has ratio > 4, and most of that is nowhere near the ratio-16 extreme at the very horizon — aniso only pays the extra cost where the footprint is actually that anisotropic, so the whole-frame average sits well under the per-pixel worst case.

3. The mip-level bands in mode 1 are not straight lines across the screen. Why do they bend towards the sides? Answer with Equation 3.

Screenshot: [`report/floor_mode1.png`](./report/floor_mode1.png) — the coloured bands visibly curve, bowing closer to the camera at the screen edges than in the middle, instead of staying horizontal.

rho in Eq 3 depends on the actual 3D distance from the camera to that floor point, not just the screen row. A pixel at the edge of the screen, at the same row as a pixel in the middle, is looking along a ray angled further from straight-ahead, so it has to travel a longer slant distance to hit the floor at that row — it's actually farther away in world space. Farther away means a bigger texel footprint (Eq 3), so the same mip level is reached sooner (at a nearer-looking row) off to the sides than in the middle, bending each constant-lod band into a curve instead of a straight horizontal line.

4. Your prediction for the sweep against the measurement. Where were you wrong?

### Prediction

Ranking by texels fetched per sample: nearest (1) < bilinear (4) < trilinear (8) < aniso4 (up to 32) < aniso16 (up to 128), so I expect that same cost order, cheapest to priciest. Naively, aniso16 at 128 vs trilinear's 8 texels suggests up to 16x the cost, but since aniso only spends extra samples where the footprint is actually anisotropic (most of the floor isn't), I expect the real frame-average multiple to land well under 16x — plausibly close to the chapter's ~15% figure if most pixels have a low ratio.

### After

Measured (median ms/frame, 16 `texture()` calls a pixel, 3 rounds): nearest 0.625 (2.98x), bilinear 0.896 (4.27x), trilinear 0.210 (1.00x), aniso4 0.850 (4.05x), aniso16 1.405 (6.70x).

Where I was wrong: trilinear was the *cheapest* of all five, not third — nearest and bilinear were both more expensive despite reading far fewer texels per sample. The panel's own note explains it: nearest and bilinear never read mips, so at distance they're still reading from the full 1024x1024 level-0 texture, scattered across many texels per screen pixel — the cost there is dominated by cache misses on incoherent memory access, not raw texel count. Trilinear and the aniso filters read from small, cache-friendly mip levels instead, so despite fetching more texels per sample in principle, they're faster in practice. My texel-count model predicted the *relative* ranking of the mip-aware filters correctly (trilinear < aniso4 < aniso16) but completely missed that the non-mipped filters would be slower, not faster, than trilinear. aniso16 did land far under the naive 16x worst case (6.70x measured), consistent with my reasoning, though still well above the chapter's ~15% — likely GPU-specific.

## Write-up 4

1. The chapter's WBOIT shader (9.5.3) computes the weight from in.position.z, the depth in the depth buffer, which is between 0 and 1. Put that into Equation 7. What weight does every fragment get? Show it with the panel's weight line and a mode 3 screenshot of both weights (key W), then say what the chapter's version of WBOIT reduces to. In this scene, the two pictures differ by only a few levels on average. Why so little here? Then run make oit ARGS="--particles 40000 --mode 1" with each weight (key W). Magenta marks pixels where fp16 accumulation saturated at 65504. Which weight saturates, and why?

Mode 3 screenshots: [`report/oit_mode3_viewdepth.png`](./report/oit_mode3_viewdepth.png) (correct, view-depth weight — coloured gradient by actual distance) vs [`report/oit_mode3_windowdepth.png`](./report/oit_mode3_windowdepth.png) (chapter's window-depth weight — almost solid red everywhere), which visually confirms the saturation claim below before even running the numbers.

The panel's `weight` line: `chapter, window depth 0.0023 .. 0.0223   w 3000.0 .. 3000.0` vs `view depth in metres   w 58.2 .. 2937.3`. Plugging the raw window-space z (0.0023-0.0223, nowhere near metres) into Eq 7: `(z/200)^4` is on the order of 1e-20, completely negligible next to the `1e-5` floor in the denominator, so `w = 0.03/1e-5 = 3000` for every single fragment, regardless of actual depth — it just always hits the clamp ceiling. Every fragment gets the same constant weight.

A constant weight cancels out of the weighted-average term in Eq 6 (`Σ Ciαiwi / Σαiwi` with `wi` the same `w` for every `i` reduces to `Σ Ciαi / Σαi`), so the chapter's version reduces to an *unweighted* average — equivalent to giving every layer equal weight, the same degenerate case the panel's `two layers` line shows as the baseline (`one weight for all 0.333`) rather than the correct depth-weighted share.

The two pictures differ by only a few levels because the correct (view-depth) weight itself saturates to nearly the same ~3000 ceiling for most of this scene's depth range — it only drops meaningfully (down to 58) very close to the camera, within the first few metres of the 4.3-30 m range. Most of the smoke/panes in this scene sit further out, where both the correct and the broken weight already agree closely, so only the handful of near fragments actually diverge, diluting the visible difference.

Window depth is the one that saturates. The `fp16 accum` table shows the largest `accum.a` growing much faster under window depth than view depth as particle count rises: view depth 6964 → 13424 (10x particles, ~1.9x growth), window depth 8896 → 45408 (10x particles, ~5.1x growth). That's because window depth gives literally every fragment the same unattenuated maximum weight (3000), so the accumulated sum grows roughly in direct proportion to how many overlapping fragments land on a pixel; view depth's weight shrinks for farther fragments, which damps the sum's growth. With enough overlapping particles (e.g. 40000, where many smoke puffs stack on the same pixels), window depth's unbounded linear growth is what pushes `accum.a` toward the fp16 ceiling of 65504, while view depth's self-limiting weight stays comfortably under it.

Screenshots: [`report/oit_40000_mode1_viewdepth.png`](./report/oit_40000_mode1_viewdepth.png) (no magenta) vs [`report/oit_40000_mode1_windowdepth.png`](./report/oit_40000_mode1_windowdepth.png) (magenta band across the top).

2. Two layers of α = 0.5, red in front of blue (Section 3). Prove that weights in the ratio wfront : wback = 2 : 1 make WBOIT exact. For n layers, what should the ideal weight of a layer be? Why can no function of z alone produce it?

Exact `over` compositing of red (front, α=0.5) over blue (back, α=0.5) over background: `0.5 Cred + 0.5(0.5 Cblue + 0.5 Cbg) = 0.5 Cred + 0.25 Cblue + 0.25 Cbg`. Total coverage is `0.75`, revealage `0.25`, matching either way.

For WBOIT (Eq 6) to reproduce this exactly, its weighted-average colour times the coverage must equal the `0.5 Cred + 0.25 Cblue` part: `0.75 x (wf Cred + wb Cblue)/(wf + wb) = 0.5 Cred + 0.25 Cblue` (the common alpha factor of 0.5 cancels top and bottom). Matching coefficients: `wf/(wf+wb) = 2/3` and `wb/(wf+wb) = 1/3`, so `wf : wb = 2 : 1` exactly, as claimed.

For n layers (front to back, i=1 nearest), the exact Porter-Duff contribution of layer i is `αi x product of (1-αj) for every layer j in front of it`. For WBOIT to match that exactly, the ideal weight is `wi proportional to that same product of (1-αj) over all layers in front of i` — i.e. exactly how much light survived reaching that layer. That quantity depends on the alphas of every *other* layer closer to the camera, not on layer i's own depth. A function of z alone only ever sees one fragment's own depth, with no information about what other transparent surfaces sit in front of it or how opaque they are — so it can never reconstruct that product, and can only ever approximate it (as the depth-based weight does, by using distance as a rough proxy for "probably has fewer things in front of it").

3. The three glass panes cut through each other. Why can no back-to-front order of the three objects be right? Point to the place in your sorted screenshot where it fails.

Screenshot: [`report/oit_sorted.png`](./report/oit_sorted.png).

The panes geometrically intersect, so different parts of the *same* pane are in front of different other panes depending on where you look — there is no single whole-object order that is correct everywhere at once. Sorting by object (e.g. by centroid distance) picks one fixed order for an entire pane, so wherever two panes' triangles actually cross, the chosen order is right on one side of the crossing and wrong on the other. Per the instructions' own description of the sorted result: red's centre is nearest, so red is drawn last and sits on top everywhere — which is wrong at every place red's geometry actually passes *behind* green or blue, visible in the sorted screenshot as red incorrectly covering the other panes along their intersection lines.

4. Your timing table: unsorted, sorted (the sort on the CPU plus the GPU) and WBOIT, at 1000 and 10000 particles. Which grows fastest, and why? Was your prediction right?

### Prediction

Sorted should grow the fastest. All three methods draw the same number of particles each frame, so their GPU draw cost should scale about the same way with particle count. But sorted adds a CPU sort of every transparent object every frame on top of that — sorting is at best O(n log n), so as particles go from 1000 to 10000 (10x), the sort cost grows more than 10x, while unsorted and WBOIT's per-particle GPU cost should stay roughly linear (WBOIT has a bit of fixed extra cost per frame for the composite pass, but that doesn't scale with particle count, so it shouldn't grow much faster than unsorted).

### After

Measured (median GPU ms of the transparent passes, 3 rounds; sort cost is CPU, reported separately):

| particles | unsorted | sorted (cpu sort + gpu) | wboit |
|---|---|---|---|
| 1000 | 0.225 | 0.017 + 0.232 | 0.424 |
| 10000 | 1.823 | 0.656 + 1.848 | 2.979 |

Growth 1000 → 10000 (10x particles): unsorted 8.1x, sorted's GPU part 8.0x (about the same as unsorted, as expected — it draws the same way), WBOIT 7.0x, and sorted's CPU sort step 38.6x (0.017 → 0.656 ms) — by far the fastest-growing single number in the table.

My prediction was right in substance — the CPU sort is the outlier, growing far faster (super-linearly, consistent with O(n log n) or worse once allocation/compare overhead is included) than any of the GPU draw costs, which all scale close to linearly with particle count (~7-8x for 10x particles, not the full 10x, likely some fixed per-frame overhead diluting the ratio slightly). Where I was imprecise: I expected WBOIT's extra composite pass to barely matter, and it didn't change the growth rate, but I hadn't predicted the GPU draw costs would come in a bit *under* 10x rather than at it — a minor miss, not a wrong call on which method grows fastest.

5. Find a place in your WBOIT picture where it is visibly wrong compared to the sorted one. Say why, using Equation 6.

Per the instructions' description of the WBOIT result: no pane is on top anywhere; where red and green overlap it shows yellow, and where all three overlap it shows a neutral lavender, instead of whichever pane is actually closest at that point. That's Eq 6's weighted-average term doing exactly what it's built to do — blend every overlapping layer's colour by weight, with no per-pixel knowledge of true front-to-back order — so at every overlap region it produces an averaged blend colour instead of the correct single nearest-surface colour the sorted render shows there.

Screenshots: [`report/oit_sorted.png`](./report/oit_sorted.png) vs [`report/oit_wboit.png`](./report/oit_wboit.png); closest diff found at pixel (354, 146), cropped at [`report/oit_compare_sorted_crop.png`](./report/oit_compare_sorted_crop.png) / [`report/oit_compare_wboit_crop.png`](./report/oit_compare_wboit_crop.png).

## AI prompt log

Model for every entry: Claude (Sonnet 4.5), via the OMP CLI assistant. One entry per prompt, in order.

| # | Prompt | Idea (what I needed / already knew) | Verification |
|---|---|---|---|
| 1 | "What's `c` and `L`, and `L(c)`/`c(L)`, in Eq 1?" | Couldn't parse the notation on p.4-5; already suspected from `color.glsl`'s comments that `c` was the sRGB byte and `L` was linear light, wanted that confirmed. | Had it render and quote the actual PDF page back at me, cross-read against Eq 1's printed form. |
| 2 | "so it should be like this for 1a and 1b right? but rewrite it so no if statement" (pasted my draft) | Wanted my first `srgb_to_linear`/`linear_to_srgb` draft reviewed and converted to branchless form. | Checked the returned `mix`/`step` formula against Eq 1 by hand; later confirmed with `make srgb`'s `decode`/`roundtrip` PASS lines. |
| 3 | "check again. valid now?" (pasted fixed code) | Wanted confirmation the swapped function names / ordering bugs were fixed. | Re-read the file myself after the AI's review; later matched `make srgb`'s `decode: texel 128 -> linear 0.2159 ... PASS`. |
| 4 | "i don't understand writeup 1.1" | Needed Q1.1 broken into "what to compute," not an answer. | Worked the two ratios (0.502/0.2159 and 0.5/0.2176) out myself afterward and put the resulting numbers in the report. |
| 5 | "again. i don't understand what 1.2 wants from me" | Needed Q1.2's scenario (overlap + falloff, left vs right pipeline) decomposed. | Later ran `make srgb` and compared my computed bytes (205, clip-to-255, 78, 38) against the actual split-screen render. |
| 6 | "restate [1.2] in plain English" | Still didn't follow the question wording itself. | N/A — clarifying the question, not computing a value. |
| 7 | "it's the black brick right? ... where does byte 150 derive from?" | Thought I had to hunt a specific pixel in a screenshot; wanted to know if 150 was given or something to find. | Had it grep `src/srgb.cpp`'s actual brick generator to show the numbers come from the lab's own hardcoded test data, not a pixel hunt. |
| 8 | "wait? isn't that too time consuming?" | Pushed back on an overly literal pixel-picking workflow I was given. | N/A — process correction. |
| 9 | "can you draft the question 2 answer for me so i know what to do" | Wanted a worked example to see the computation pattern. | Had it compute the fractions in a Python cell (exact, not estimated) and checked the results made sense against the clip/no-clip behaviour described for mode 0. |
| 10 | "i don't understand 1.3 ... is there roughness in task 1? does make srgb have roughness?" | Needed to know if roughness was implemented in this lab or a pure reasoning question. | Had it grep the whole repo for `roughness`/`metallic` — confirmed zero matches, i.e. no code to run. |
| 11 | "let's talk 1.4, is there python in our project or the PDF?" | Needed to know if "the chapter's Python check" was runnable here. | Had it search for `.py` files (none) and read `src/srgb.cpp` directly for the real RED-brick bytes and both check implementations; verified the luminance/per-channel numbers with a Python calculation. |
| 12 | "where can i load an albedo texture, what's the file extension?" | Needed the actual CLI flag and accepted format. | Had it read `Args.cpp`/`image.cpp` source directly instead of guessing. |
| 13 | "can @yours.png work? restricted aspect/resolution?" (Earth photo) | Wanted to know if an unrelated photo would load without crashing, and whether it was a sane choice. | Had it check `boxMips` in `image.cpp` for size/aspect assumptions directly in the source. |
| 14 | "can @texture-wood.jpg work?" | Same question for a `.jpg`, since the loader function is literally named `loadPng`. | Had it check the `stb_image` include flags in `image.cpp` to confirm JPEG decoding isn't compiled out. |
| 15 | pasted my Q1/3/4/5 answers + "left is 1.2, draft me the answer" | Wanted my own answers checked, and a draft of the one I hadn't written. | AI re-derived each number from Eq 1 and flagged: Q1 missing the `x^2.2` factor, Q4's `0.13 > 0.9` logic error. I then fixed those myself. |
| 16 | "please check report.md okay for write-up 1 now?" | Wanted a final check before moving on. | AI re-read the file and re-flagged the same unresolved issues, line by line. |
| 17 | "fix it for me" | Wanted the three flagged issues corrected directly. | Re-read the edited lines myself to confirm the missing numbers/logic were now right. |
| 18 | "should i commit texture-wood.jpg and srgb_yours.png? report/ is ignored" | Needed the right git workflow given `.gitignore` excludes `report/`. | Had it run `git check-ignore -v` and `git status` to show the actual rule before deciding how to force-add. |
| 19 | "next is task 2a, can you guide me?" | Needed Task 2a (tangent-space transform) explained before writing it. | N/A at explanation time; verified later via `make normalmap`'s `probes` PASS lines. |
| 20 | pasted my first 2a attempt + "like this?" | Wanted my draft checked before running anything. | AI checked my GLSL against the declared `vec3` output types, caught `mat3`-assigned-to-`vec3` errors. |
| 21 | "validate it again. correct now?" | Confirm the fixed 2a was right. | AI matched it to Eq 2's structure; I later ran `make normalmap` myself for the real probe PASS lines. |
| 22 | "okay for task 2b, i don't understand, describe it" | Needed the normal-decode + TBN-transform step explained. | N/A at explanation time; verified later via the panel. |
| 23 | pasted my 2b attempt + "validate it" | Wanted my first 2b draft checked. | AI caught that I'd plugged `Ng` into the formula instead of sampling `tex1` at all — a real bug, not style. |
| 24 | pasted the fixed version + "validate it again. correct now?" | Confirm the texture-sampling fix was right. | AI caught `u.knob == 1` needing to be `1u` (uint/int compare); I fixed and it compiled. |
| 25 | "after i press C... shadow diagonal with light... with or without knob condition [looks the same]" | Reported an observation that seemed to contradict what I expected, wanted it explained. | Worked through the `dot(N,L)` / `B·L` term algebraically with the AI — no code change, a derivation check. |
| 26 | "guide me 2.2? shadow in little circle is curved not line" | Needed 2.2 explained; flagged a second observation. | Had it compute the wrongly-decoded normal for texel (128,128,255) exactly, which I cross-checked against my own understanding of why the curve bends. |
| 27 | "write that into report for me, match my writing style, simple and concise" | Wanted my now-understood answer written up. | Checked the computed normal numbers against my own quick paper derivation before accepting the wording. |
| 28 | "can you complete 2.3 and 2.4?" | Hadn't worked these two out myself yet, needed them explained/completed. | For 2.4, had it check the actual `own ? "n/a" : ...` branch in `src/normalmap.cpp` to confirm there's really no CPU reference for a custom map. |
| 29 | "make it more concise and write report.md" | Wanted the 2.3/2.4 answers trimmed and committed to the file. | Re-read the written file afterward to confirm the wording matched. |
| 30 | "validate task 3a and 3b pls" | Wanted my `miplevel.frag` attempt checked. | AI caught a missing semicolon and, more importantly, that neither function called `dFdx`/`dFdy` at all. |
| 31 | "validate pls" (after fixing) | Confirm the `dFdx`/`dFdy` fix was right. | AI matched it to Eq 3/4 structurally; I later ran `make floor` myself — all six probe rows PASSed against the CPU column. |
| 32 | "where is the anisotropy ratio above 4? ... what's this mean?" | Confused whether "where" meant a pixel location or an equation term; also confused by the report's duplicated Prediction/After headers. | Had it run `./build/floor --headless` and pull the real probe table (distances/ratios) instead of guessing a location. |
| 33 | "i don't even know these equations, how am i supposed to know expensiveness [for the prediction]?" | Needed a sample-count mental model to write a prediction before running the real sweep. | None at prediction time by design — predictions must precede measurement; checked afterward against the real `timing` table. |
| 34 | "just complete write-up 3 for me" | Wanted the full write-up filled using real data, not estimates. | Built and ran `./build/floor --headless` myself and used the panel's own printed CPU column / PASS verdicts as the numbers. |
| 35 | "next is task 4a, how to start?" | Needed Task 4a (WBOIT accumulation) explained. | N/A at explanation time; verified later via the panel's `single layer`/`two layers` PASS lines. |
| 36 | pasted my accum draft + "would this work?" | Wanted my formula checked before compiling. | AI algebraically expanded `vec4(c.xyz*c.a, c.a) * w` against the required `(c.rgb*c.a*w, c.a*w)` form by hand. |
| 37 | "what about the .frag, how to start?" | Needed Task 4b (composite pass) explained. | N/A at explanation time; verified later via the panel. |
| 38 | pasted my composite draft + "validate it" | Wanted the implementation checked. | AI matched each line to the texelFetch/guard/alpha spec; confirmed afterward via `single layer: max |wboit - over| 0 levels PASS`. |
| 39 | "setup write-up 4 for me, what's the prediction?" | Needed the report structure fixed (prediction only applies to Q4) and an initial prediction written. | N/A at prediction time, by design. |
| 40 | "just complete write-up for me, i'll study it myself" | Wanted the rest of write-up 4 filled with real data. | Built and ran `./build/oit --headless` myself; used the panel's actual printed check values (two-layer share 0.844, revealage 0.280, timing table) instead of estimates. |
| 41 | "please check report/, what's left that i need?" | Wanted a gap check against the submission checklist on p.16. | Had it read `make_info.png` and compare file contents against each write-up's explicit screenshot requirement. |
| 42 | "just do that for me" (generate the missing screenshots) | Wanted the missing screenshots actually captured. | Ran each lab headlessly with `--save`, then personally inspected every resulting PNG (e.g. confirmed the custom normal map's convention by zooming into convex-vs-concave bumps; confirmed fp16 saturation by literally seeing magenta appear in one image and not the other). |
| 43 | "You update my answer? Please don't, keep the original, but you can reference the image" | Caught the AI rewriting my own analysis instead of only citing evidence. | Re-read the diffed file myself to confirm original wording was restored and only link lines were added. |
| 44 | "It should be in this format though [per-prompt log spec from p.17]" | The log needed to match the PDF's required format exactly, not a by-topic summary. | This table — compared field-by-field against the spec quoted on p.17. |
