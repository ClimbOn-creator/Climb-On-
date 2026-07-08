# AR Boulder Beta Packs

This app uses lightweight AR packs so Supabase does not store heavy AR files.

## What Supabase Stores

- Route AR metadata
- External AR asset URL
- Optional anchor/reference image URL
- Tiny beta overlay JSON with normalized hold and line coordinates

The heavy files should live outside Supabase, such as object storage, a CDN, or
another cheap static host.

## Field Photo Workflow

1. Pick one boulder problem.
2. Take one clean reference photo from the normal viewing stance.
3. Keep the phone as square to the face as possible.
4. Avoid ultra-wide distortion.
5. Make sure the start holds, crux holds, and top are visible.
6. Compress the photo before upload.
7. Host the photo externally and paste the URL into the AR editor.

## Overlay JSON

Use normalized coordinates. `x: 0` is the left edge of the photo, `x: 1` is the
right edge. `y: 0` is the top, `y: 1` is the bottom.

```json
{
  "referenceImageUrl": "https://example.com/boulders/problem-reference.webp",
  "holds": [
    {
      "x": 0.32,
      "y": 0.76,
      "type": "start",
      "label": "LH",
      "title": "Left start rail",
      "imageUrl": "https://example.com/boulders/left-start.webp",
      "description": "Pull inward on the rail and keep the right hip close."
    },
    {"x": 0.45, "y": 0.72, "type": "start", "label": "RH"},
    {
      "x": 0.52,
      "y": 0.55,
      "type": "hand",
      "label": "2",
      "title": "Right-hand crimp",
      "description": "Use the thumb catch before moving the left foot."
    },
    {"x": 0.39, "y": 0.82, "type": "foot", "label": "F"},
    {"x": 0.66, "y": 0.22, "type": "finish", "label": "Top"}
  ],
  "line": [
    {"x": 0.38, "y": 0.74},
    {"x": 0.52, "y": 0.55},
    {"x": 0.66, "y": 0.22}
  ]
}
```

`title`, `imageUrl`, and `description` are optional. When present, the route
viewer opens them as tappable micro-beta for that hold.

## Getting Rock Recognition Working

The first shippable version is manual/reference alignment:

1. The user downloads the route AR pack.
2. The app shows the reference photo and the hold overlay.
3. The climber compares it with the real boulder before pulling on.

True automatic recognition needs a vision step:

1. Collect 8-15 photos of the same boulder from slightly different distances
   and angles.
2. Pick one primary reference image.
3. Use the overlay JSON on that primary image.
4. Later, add an image tracking SDK or native ARKit/ARCore image anchor flow.
5. Feed the primary reference image into that tracker.
6. When the tracker recognizes the rock, draw the same normalized overlay in
   the camera coordinate space.

The important bit: the hold data format does not change. The current overlay
JSON is the foundation for both manual alignment and later automatic image
recognition.
