#!/bin/zsh

set -euo pipefail

asset_catalog="${1:-DaliCamera/Assets.xcassets}"
target_bytes=95000
initial_long_edge=720
minimum_long_edge=480
step=30

if ! command -v sips >/dev/null 2>&1; then
  print -u2 "sips is required to optimize package images."
  exit 1
fi

temporary_directory=$(mktemp -d /tmp/dali-package-images.XXXXXX)
converted_count=0

cleanup() {
  find "$temporary_directory" -type f -delete
  rmdir "$temporary_directory"
}
trap cleanup EXIT

while IFS= read -r -d '' source_image; do
  image_set_directory=${source_image:h}
  source_stem=${source_image:t:r}
  destination_image="$image_set_directory/$source_stem.jpg"
  temporary_image="$temporary_directory/$converted_count.jpg"
  long_edge=$initial_long_edge

  if [[ ${source_image:e:l} == "jpg" ]]; then
    source_bytes=$(stat -f '%z' "$source_image")
    source_width=$(sips -g pixelWidth "$source_image" 2>/dev/null | awk '/pixelWidth/ { print $2 }')
    source_height=$(sips -g pixelHeight "$source_image" 2>/dev/null | awk '/pixelHeight/ { print $2 }')
    if (( source_bytes <= target_bytes && source_width <= initial_long_edge && source_height <= initial_long_edge )); then
      converted_count=$((converted_count + 1))
      continue
    fi
  fi

  while true; do
    sips \
      -s format jpeg \
      -s formatOptions normal \
      -Z "$long_edge" \
      "$source_image" \
      --out "$temporary_image" >/dev/null

    image_bytes=$(stat -f '%z' "$temporary_image")
    if (( image_bytes <= target_bytes || long_edge <= minimum_long_edge )); then
      break
    fi

    long_edge=$((long_edge - step))
  done

  if (( image_bytes > 100000 )); then
    print -u2 "Could not reduce $source_image below 100000 bytes."
    exit 1
  fi

  mv -f "$temporary_image" "$destination_image"
  if [[ "$source_image" != "$destination_image" ]]; then
    unlink "$source_image"
  fi

  contents_file="$image_set_directory/Contents.json"
  perl -pi -e 's/\.(?:png|jpe?g)"/.jpg"/gi' "$contents_file"
  converted_count=$((converted_count + 1))
done < <(
  find "$asset_catalog" \
    \( -path '*Pose*.imageset/*' -o -path '*Landscape*.imageset/*' -o -path '*Food*.imageset/*' \) \
    -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) \
    -print0
)

print "Optimized $converted_count package images to JPEG (target: $target_bytes bytes each)."
