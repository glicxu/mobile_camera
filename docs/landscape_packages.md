# Dali Camera Landscape Composition Packages

Date: October 6, 2026
Status: Initial four-package catalog implemented

## Implementation snapshot

The initial catalog is now available in the native iOS app for testing:

- Selecting the **Landscape** situation reveals a separate **Landscape** button; the people-oriented Posture button remains hidden.
- The category-first chooser contains **Mountains**, **Lakes & Water**, **Plains & Fields**, and **Plants & Gardens**.
- Each package contains six selectable composition recipes with photo references, for 24 recipes total.
- Every recipe includes two framing cues, an automatically recommended camera angle, recommended light/time, and a location-specific safety note.
- Selecting **Natural** turns off the creative composition recipe while retaining the app's live horizon and stability guidance.
- The active recipe card can be tapped to open the full photo, lighting explanation, and safety note.

Standalone light filters, step-by-step advancement, and Auto recommendations remain documented for later implementation after the four manual packages are reviewed.

## Purpose

Landscape photography should use a dedicated package system rather than people-oriented posture guidance. A landscape package teaches the photographer where to stand, how to angle the camera, what visual element to emphasize, and which light best supports the scene.

The system should combine three dimensions:

1. **Scene package** — what the user is photographing.
2. **Composition recipe** — how to frame it and where to place the camera.
3. **Light and time** — sunrise, daytime, sunset, blue hour, or overcast conditions.

This structure avoids creating duplicate packages such as “Mountains at Sunrise,” “Mountains at Sunset,” and “Mountains in Overcast Light.” Mountains remains one package; time and lighting refine its recipes.

## Proposed first-release packages

| Package | Initial recipe count | Primary photographic goals |
| --- | ---: | --- |
| Mountains | 6 | Scale, layered ridges, peaks, foreground depth, trails, and dramatic light. |
| Lakes & Water | 6 | Reflections, shoreline curves, horizon placement, foreground rocks, and calm or moving water. |
| Plains & Fields | 6 | Open space, leading paths, horizon proportion, repeating texture, and isolated subjects. |
| Plants & Gardens | 6 | Layers of foliage, individual plants, patterns, paths, backlight, and controlled backgrounds. |

Potential later packages include Coast & Ocean, Forests, Waterfalls & Rivers, Desert, Snow, Cityscape, and Night Sky.

## Package-selection experience

1. When the selected photographic situation is **Landscape**, show a separate **Landscape** control in the compact selection row.
2. Tapping Landscape opens a category-first chooser: Mountains, Lakes & Water, Plains & Fields, and Plants & Gardens.
3. Each category card shows three preview photos, the number of recipes, and a short description.
4. Selecting a category opens only that category's large photo montage.
5. Selecting a reference photo starts short photographer coaching and keeps the shutter available.
6. The active card displays the reference, composition instruction, recommended camera angle, and recommended light/time.
7. **Natural** or **No composition recipe** exits creative guidance while ordinary horizon, stability, exposure, and safety coaching continues.

## Shared composition metadata

Every landscape reference should include:

| Field | Example |
| --- | --- |
| Stable ID | `MT1`, `LK3`, `PL2`, or `PG5` |
| Package | Mountains |
| Title | Foreground trail to peak |
| Scene tags | Mountain, trail, valley |
| Composition type | Leading line |
| Camera height | Low, eye level, elevated, or overhead |
| Camera direction | Straight, upward, downward, or side angle |
| Lens/framing guidance | Wide view, standard view, or detail |
| Horizon placement | Upper third, lower third, centered reflection, or not applicable |
| Light/time | Sunrise, daytime, sunset, blue hour, or overcast |
| Weather suitability | Clear, cloudy, mist, or any |
| Coaching cues | Two short photographer actions |
| Safety note | Stay on trail; avoid unstable edges; do not enter water |
| Reference image | Photo demonstrating the complete recipe |

## Package 1: Mountains

| ID | Composition recipe | Camera angle | Best light | Coaching cues |
| --- | --- | --- | --- | --- |
| MT1 | Foreground trail to peak | Low, slightly upward | Sunrise or sunset | Lower the camera near the trail. Use the trail to lead toward the peak. |
| MT2 | Layered ridgelines | Eye level | Sunrise, sunset, or mist | Frame several overlapping ridges. Keep the brightest ridge away from the center. |
| MT3 | Peak with open sky | Eye level, slight upward angle | Sunrise or blue hour | Place the peak below the center. Leave clean sky around its outline. |
| MT4 | Valley from above | Elevated, gently downward | Daytime or sunset | Include the valley foreground. Keep the horizon level and away from the center. |
| MT5 | Person for scale | Eye level | Golden hour | Place the person away from the peak. Step back until the landscape remains dominant. |
| MT6 | Mountain detail | Standard or slight side angle | Soft overcast light | Isolate one ridge, texture, or patch of light. Remove distracting edges. |

## Package 2: Lakes & Water

| ID | Composition recipe | Camera angle | Best light | Coaching cues |
| --- | --- | --- | --- | --- |
| LK1 | Centered reflection | Eye level | Sunrise or calm sunset | Center the shoreline horizontally. Keep the reflected peak or trees fully visible. |
| LK2 | Foreground rocks | Low, gently downward | Sunrise or sunset | Lower the camera near the rocks. Use them to lead into the water. |
| LK3 | Curving shoreline | Eye level or slightly high | Daytime or golden hour | Follow the shoreline through the frame. Keep the far end visible. |
| LK4 | Minimal water and sky | Eye level | Blue hour or overcast | Simplify the frame to water, horizon, and sky. Remove shoreline clutter. |
| LK5 | Reeds or plants at water's edge | Low, side angle | Backlit sunrise or sunset | Place the plants along one edge. Keep open water visible beyond them. |
| LK6 | Moving water texture | Slightly high, downward | Overcast | Fill the frame with ripples or flow. Avoid bright reflections at the edges. |

## Package 3: Plains & Fields

| ID | Composition recipe | Camera angle | Best light | Coaching cues |
| --- | --- | --- | --- | --- |
| PL1 | Path through the field | Low or eye level | Sunrise or sunset | Place the path near a lower corner. Let it lead toward the distance. |
| PL2 | Large open sky | Eye level | Sunset or dramatic clouds | Place the horizon low. Keep the strongest cloud or color away from dead center. |
| PL3 | Repeating rows | Slightly elevated | Daytime or golden hour | Align the rows into the distance. Keep their convergence point visible. |
| PL4 | Single tree or structure | Eye level | Sunrise or sunset | Isolate the subject against open space. Leave room in the direction it visually faces. |
| PL5 | Grass or flowers in foreground | Low | Backlit golden hour | Focus on the nearest texture. Keep enough distant field to show depth. |
| PL6 | Layered field colors | Elevated, gently downward | Soft daylight | Stack color bands across the frame. Keep boundaries clean and level. |

## Package 4: Plants & Gardens

| ID | Composition recipe | Camera angle | Best light | Coaching cues |
| --- | --- | --- | --- | --- |
| PG1 | Garden path | Eye level or low | Morning or overcast | Use the path as a leading line. Keep its destination visible. |
| PG2 | Single plant portrait | Eye level with the plant | Soft overcast or window-like light | Move to the plant's height. Choose a clean background behind it. |
| PG3 | Backlit leaves | Slight upward angle | Sunrise or sunset | Place the light behind the leaves. Shift sideways until edges glow without hiding detail. |
| PG4 | Repeating pattern | Straight-on or overhead | Soft even light | Fill the frame with the pattern. Keep rows and edges aligned. |
| PG5 | Layered foliage | Eye level | Overcast | Separate foreground, middle, and background plants. Avoid overlapping the main shapes. |
| PG6 | Flower or leaf detail | Side or 45-degree angle | Soft shade | Move close enough to simplify the frame. Keep the key petal or leaf edge sharp. |

## Light and time filters

Light should refine package results rather than create separate duplicate packages.

| Filter | Visual opportunity | General guidance |
| --- | --- | --- |
| Sunrise | Low warm light, mist, calm water | Arrive before sunrise; face partly across the light rather than directly into it. |
| Daytime | Strong detail and clear color | Prefer side light or open shade; watch for glare and harsh shadows. |
| Sunset | Warm side light and colorful sky | Expose for the brightest sky while retaining visible foreground detail. |
| Blue hour | Even cool color and silhouettes | Stabilize the phone and avoid lifting shadows until they become noisy. |
| Overcast | Soft detail, foliage color, waterfalls | Use the even light for plants, textures, and moving water. |

## Angle vocabulary

Landscape instructions should use a small, consistent set of camera positions:

- **Low foreground angle** — camera near a safe foreground element to exaggerate depth.
- **Eye level** — neutral view for horizons, reflections, and layered distance.
- **Elevated view** — safely above the scene, angled gently downward.
- **Upward angle** — emphasizes peaks, trees, or sky without excessive distortion.
- **Downward detail** — isolates water, plants, texture, or patterns.
- **Side angle** — changes overlap, glare, reflections, or backlighting.

The app must never encourage stepping beyond barriers, approaching unstable edges, entering water, blocking trails, or trespassing to achieve an angle.

## Future Auto recommendation

Auto may recommend a scene package and a small set of matching recipes using visible, non-sensitive evidence:

- mountain or ridge confidence,
- water and reflection area,
- open-field and horizon structure,
- dominant vegetation,
- sunrise/sunset color and sun elevation,
- cloud, mist, and brightness patterns,
- foreground availability,
- and phone orientation.

The display card should explain its evidence, for example:

> **Auto suggestion**
>
> Lake · calm sunset light
> View 4 matching compositions

Auto should recommend a filtered montage, not silently activate a composition recipe. Stable multi-frame evidence and manual override behavior should match the proposed posture Auto system.

## Implementation phases

1. **Implemented:** Add a reusable landscape-recipe model with package, angle, light/time, safety, cue, and image metadata.
2. **Implemented:** Add the separate Landscape control, four category cards, and category-specific recipe montages.
3. **Implemented:** Produce all 24 initial reference photographs.
4. **Partially implemented:** Add an active composition card and full detail view. Step-by-step advancement can follow user testing.
5. **Implemented for the test:** Keep existing live horizon and stability observations visible without blocking capture.
6. **Deferred:** Add Auto ranking only after the manual packages are tested.

## Later review questions

1. Should Forests become its own package or remain under Plants & Gardens initially?
2. Should sunrise and sunset become visible filters after the manual catalog is tested?
3. Should each recipe show a recommended phone lens such as 0.5×, 1×, or 2× when hardware supports it?
4. Should Person + Scene allow selected landscape recipes while retaining people guidance?

## Recommended starting decision

- Keep landscape composition separate from people posture packages.
- Start with the four proposed scene packages and six recipes per package.
- Treat sunrise, sunset, blue hour, daytime, and overcast as reusable filters.
- Require an angle, light/time recommendation, two photographer cues, and a safety note for every reference image.
- Produce **Mountains** first, validate its interaction model, and then reuse the structure for Lakes, Plains, and Plants.
