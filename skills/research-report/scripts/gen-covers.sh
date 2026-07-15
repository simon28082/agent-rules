#!/bin/bash
# Cover page generator for deep-research-report.
# Usage: source this file, then call generate() and render_and_crop().
#
# Example:
#   TEMPLATE="templates/cover.html"
#   mkdir -p reports/MYCO
#   generate reports/MYCO/cover.html \
#     "{{COMPANY}}" "My Company, Inc." \
#     "{{TICKER}}" "MYCO" \
#     "{{TITLE_CN}}" "深度研究" \
#     "{{SUBTITLE}}" "副标题" \
#     "{{TICKER_FULL}}" "NYSE: MYCO" \
#     "{{DATE}}" "2026.07.12" \
#     "{{M1_LABEL}}" "Market Cap" \
#     "{{M1_VAL}}" "\$10.0B" \
#     "{{M2_LABEL}}" "Revenue" \
#     "{{M2_VAL}}" "\$500M" \
#     "{{M3_LABEL}}" "FCF" \
#     "{{M3_VAL}}" "\$50M" \
#     "{{TAG1}}" "Segment A" \
#     "{{TAG2}}" "Segment B" \
#     "{{TAG3}}" "Segment C" \
#     "{{PRIMARY_COLOR}}" "#0066FF"
#   render_and_crop reports/MYCO

set -e
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

generate() {
  local out="$1"; shift
  cp "$TEMPLATE" "$out"
  while [ $# -ge 2 ]; do
    sed -i '' "s|$1|$2|g" "$out"
    shift 2
  done
}

render_and_crop() {
  local dir="$1"
  local html="$dir/cover.html"
  cd "$dir"
  "$CHROME" --headless --screenshot=cover.png --window-size=800,420 --force-device-scale-factor=2 "file://$PWD/cover.html" 2>/dev/null
  python3 -c "
from PIL import Image; import numpy as np
img = Image.open('cover.png'); arr = np.array(img)
mask = ~((arr[:,:,0] > 254) & (arr[:,:,1] > 254) & (arr[:,:,2] > 254))
coords = np.argwhere(mask)
y0, x0 = coords.min(axis=0); y1, x1 = coords.max(axis=0) + 1
img.crop((x0-4, y0-4, x1+4, y1+4)).save('cover.png')
  "
  cd - >/dev/null
}
