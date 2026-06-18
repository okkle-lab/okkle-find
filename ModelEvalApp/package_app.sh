#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Model Eval Runner"
BUNDLE_ID="com.mototax.modelevalrunner"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
VERSION_FILE="${SCRIPT_DIR}/VERSION"
BUILD_DIR="${SCRIPT_DIR}/.build/packaging"
VENV_DIR="${BUILD_DIR}/pyinstaller-venv"
RUNNER_DIST="${BUILD_DIR}/runner-dist"
RUNNER_WORK="${BUILD_DIR}/runner-work"
RUNNER_SPEC="${BUILD_DIR}/runner-spec"
ICONSET_DIR="${BUILD_DIR}/AppIcon.iconset"
ICON_PATH="${BUILD_DIR}/AppIcon.icns"
DIST_DIR="${SCRIPT_DIR}/dist"
APP_DIR="${DIST_DIR}/${APP_NAME}.app"
DEFAULTS_DIR="${SCRIPT_DIR}/Defaults"

if [[ -n "${APP_VERSION:-}" ]]; then
  VERSION="${APP_VERSION}"
elif [[ -f "${VERSION_FILE}" ]]; then
  VERSION="$(tr -d '[:space:]' < "${VERSION_FILE}")"
else
  echo "Missing ${VERSION_FILE}" >&2
  exit 2
fi

if [[ ! "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?$ ]]; then
  echo "Invalid app version '${VERSION}'. Expected semantic versioning, e.g. 1.0.0." >&2
  exit 2
fi

BUILD_NUMBER="${BUILD_NUMBER:-1}"
ZIP_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}-mac.zip"
LATEST_ZIP_PATH="${DIST_DIR}/${APP_NAME}-mac.zip"

if [[ -n "${PYTHON:-}" && -x "${PYTHON}" ]]; then
  BASE_PYTHON="${PYTHON}"
else
  BASE_PYTHON="$(command -v python3)"
fi

if [[ -z "${BASE_PYTHON}" ]]; then
  echo "python3 is required to package the app." >&2
  exit 2
fi

echo "Packaging ${APP_NAME} ${VERSION} (${BUILD_NUMBER})"
echo "Using Python: ${BASE_PYTHON}"
mkdir -p "${BUILD_DIR}" "${DIST_DIR}"

if [[ ! -x "${VENV_DIR}/bin/python" ]]; then
  "${BASE_PYTHON}" -m venv "${VENV_DIR}"
fi

if ! "${VENV_DIR}/bin/python" - <<'PY' >/dev/null 2>&1
import PyInstaller
import openpyxl
import PIL
PY
then
  "${VENV_DIR}/bin/python" -m pip install --upgrade pip setuptools wheel
  "${VENV_DIR}/bin/python" -m pip install --upgrade pyinstaller openpyxl pillow
fi

echo "Building bundled runner..."
rm -rf "${RUNNER_DIST}" "${RUNNER_WORK}" "${RUNNER_SPEC}"
"${VENV_DIR}/bin/python" -m PyInstaller \
  --onefile \
  --clean \
  --name model_eval_runner \
  --distpath "${RUNNER_DIST}" \
  --workpath "${RUNNER_WORK}" \
  --specpath "${RUNNER_SPEC}" \
  "${REPO_ROOT}/script/model_eval_runner.py"

echo "Building Swift app..."
swift build -c release --package-path "${SCRIPT_DIR}" >/dev/null
SWIFT_BIN="$(swift build -c release --package-path "${SCRIPT_DIR}" --show-bin-path)/ModelEvalApp"

echo "Creating app icon..."
rm -rf "${ICONSET_DIR}"
mkdir -p "${ICONSET_DIR}"
"${VENV_DIR}/bin/python" - "${ICONSET_DIR}" <<'PY'
from pathlib import Path
import math
import sys

from PIL import Image, ImageDraw, ImageFilter

out_dir = Path(sys.argv[1])
canvas = 1024

def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask

def vertical_gradient(size, stops):
    image = Image.new("RGBA", size)
    pix = image.load()
    for y in range(size[1]):
        t = y / max(1, size[1] - 1)
        for idx in range(len(stops) - 1):
            a_pos, a_col = stops[idx]
            b_pos, b_col = stops[idx + 1]
            if a_pos <= t <= b_pos:
                f = (t - a_pos) / max(0.001, b_pos - a_pos)
                col = tuple(round(a_col[i] + (b_col[i] - a_col[i]) * f) for i in range(4))
                break
        else:
            col = stops[-1][1]
        for x in range(size[0]):
            pix[x, y] = col
    return image

def shadowed_round_rect(base, rect, radius, fill, shadow, blur=28, offset=(0, 18), outline=None):
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    shadow_rect = tuple(rect[i] + (offset[0] if i % 2 == 0 else offset[1]) for i in range(4))
    draw.rounded_rectangle(shadow_rect, radius=radius, fill=shadow)
    layer = layer.filter(ImageFilter.GaussianBlur(blur))
    base.alpha_composite(layer)

    front = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(front)
    draw.rounded_rectangle(rect, radius=radius, fill=fill)
    if outline:
        draw.rounded_rectangle(rect, radius=radius, outline=outline, width=3)
    base.alpha_composite(front)

icon = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
mask = rounded_mask((canvas, canvas), 220)
background = vertical_gradient(
    (canvas, canvas),
    [
        (0.0, (226, 252, 255, 255)),
        (0.42, (83, 176, 247, 255)),
        (1.0, (33, 64, 210, 255)),
    ],
)

grain = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
grain_draw = ImageDraw.Draw(grain)
for i in range(0, canvas, 7):
    alpha = 9 + int(6 * math.sin(i / 27))
    grain_draw.line((0, i, canvas, i + 180), fill=(255, 255, 255, alpha), width=1)

background.alpha_composite(grain)
background.putalpha(mask)
icon.alpha_composite(background)

glass = Image.new("RGBA", icon.size, (0, 0, 0, 0))
gdraw = ImageDraw.Draw(glass)
gdraw.rounded_rectangle((18, 18, 1006, 1006), radius=210, outline=(255, 255, 255, 90), width=7)
gdraw.rounded_rectangle((54, 54, 970, 318), radius=154, fill=(255, 255, 255, 28))
gdraw.arc((94, 78, 930, 678), 200, 340, fill=(255, 255, 255, 58), width=8)
icon.alpha_composite(glass)

shadowed_round_rect(
    icon,
    (206, 246, 818, 760),
    92,
    (246, 252, 255, 224),
    (0, 28, 90, 86),
    blur=38,
    offset=(0, 28),
    outline=(255, 255, 255, 178),
)

details = Image.new("RGBA", icon.size, (0, 0, 0, 0))
draw = ImageDraw.Draw(details)
draw.rounded_rectangle((244, 286, 780, 378), radius=46, fill=(24, 92, 221, 205))
for x in (352, 462, 572, 682):
    draw.line((x, 418, x, 702), fill=(54, 78, 114, 54), width=5)
for y in (438, 512, 586, 660):
    draw.line((244, y, 780, y), fill=(54, 78, 114, 54), width=5)

for y, colors in [
    (456, ((54, 214, 167), (255, 255, 255))),
    (530, ((255, 190, 86), (255, 255, 255))),
    (604, ((86, 126, 255), (255, 255, 255))),
]:
    draw.rounded_rectangle((274, y, 320, y + 24), radius=12, fill=colors[0] + (218,))
    draw.rounded_rectangle((352, y + 2, 646, y + 18), radius=9, fill=(48, 64, 96, 80))
    draw.rounded_rectangle((676, y + 2, 748, y + 18), radius=9, fill=(48, 64, 96, 54))
icon.alpha_composite(details)

shadowed_round_rect(
    icon,
    (604, 586, 846, 828),
    84,
    (21, 220, 182, 235),
    (0, 34, 82, 92),
    blur=30,
    offset=(0, 20),
    outline=(255, 255, 255, 178),
)
play = Image.new("RGBA", icon.size, (0, 0, 0, 0))
draw = ImageDraw.Draw(play)
draw.polygon([(694, 656), (694, 758), (778, 707)], fill=(255, 255, 255, 245))
draw.arc((632, 610, 818, 796), 210, 330, fill=(255, 255, 255, 92), width=7)
draw.ellipse((678, 640, 716, 678), fill=(255, 255, 255, 64))
icon.alpha_composite(play)

highlight = Image.new("RGBA", icon.size, (0, 0, 0, 0))
hdraw = ImageDraw.Draw(highlight)
hdraw.rounded_rectangle((150, 92, 874, 304), radius=134, fill=(255, 255, 255, 24))
hdraw.arc((124, 74, 900, 614), 202, 338, fill=(255, 255, 255, 48), width=7)
highlight = highlight.filter(ImageFilter.GaussianBlur(10))
icon.alpha_composite(highlight)

sizes = [
    (16, ""),
    (32, "@2x"),
    (32, ""),
    (64, "@2x"),
    (128, ""),
    (256, "@2x"),
    (256, ""),
    (512, "@2x"),
    (512, ""),
    (1024, "@2x"),
]
names = [
    "icon_16x16.png",
    "icon_16x16@2x.png",
    "icon_32x32.png",
    "icon_32x32@2x.png",
    "icon_128x128.png",
    "icon_128x128@2x.png",
    "icon_256x256.png",
    "icon_256x256@2x.png",
    "icon_512x512.png",
    "icon_512x512@2x.png",
]

resample = Image.Resampling.LANCZOS
for pixel_size, name in zip([s[0] for s in sizes], names):
    icon.resize((pixel_size, pixel_size), resample).save(out_dir / name)

icon.save(out_dir.parent / "AppIcon-1024.png")
PY

iconutil -c icns "${ICONSET_DIR}" -o "${ICON_PATH}"

echo "Assembling ${APP_NAME}.app..."
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
cp "${SWIFT_BIN}" "${APP_DIR}/Contents/MacOS/ModelEvalApp"
cp "${RUNNER_DIST}/model_eval_runner" "${APP_DIR}/Contents/Resources/model_eval_runner"
cp "${ICON_PATH}" "${APP_DIR}/Contents/Resources/AppIcon.icns"
if [[ -d "${DEFAULTS_DIR}" ]]; then
  ditto "${DEFAULTS_DIR}" "${APP_DIR}/Contents/Resources/Defaults"
  find "${APP_DIR}/Contents/Resources/Defaults" \
    \( -name ".DS_Store" -o -name "~\$*" \) \
    -delete
fi
chmod +x "${APP_DIR}/Contents/MacOS/ModelEvalApp"
chmod +x "${APP_DIR}/Contents/Resources/model_eval_runner"
xattr -cr "${APP_DIR}"

"${VENV_DIR}/bin/python" - "${APP_DIR}/Contents/Info.plist" "${BUNDLE_ID}" "${APP_NAME}" "${VERSION}" "${BUILD_NUMBER}" <<'PY'
from pathlib import Path
import plistlib
import sys

plist_path = Path(sys.argv[1])
bundle_id = sys.argv[2]
app_name = sys.argv[3]
version = sys.argv[4]
build_number = sys.argv[5]

plist = {
    "CFBundleDevelopmentRegion": "en",
    "CFBundleDisplayName": app_name,
    "CFBundleExecutable": "ModelEvalApp",
    "CFBundleIconFile": "AppIcon",
    "CFBundleIdentifier": bundle_id,
    "CFBundleInfoDictionaryVersion": "6.0",
    "CFBundleName": app_name,
    "CFBundlePackageType": "APPL",
    "CFBundleShortVersionString": version,
    "CFBundleVersion": build_number,
    "CFBundleGetInfoString": f"{app_name} {version} ({build_number})",
    "LSApplicationCategoryType": "public.app-category.productivity",
    "LSMinimumSystemVersion": "14.0",
    "NSHighResolutionCapable": True,
    "NSSupportsAutomaticGraphicsSwitching": True,
}

with plist_path.open("wb") as handle:
    plistlib.dump(plist, handle, sort_keys=True)
PY

codesign --force --deep --sign - "${APP_DIR}" >/dev/null
codesign --verify --deep --strict --verbose=2 "${APP_DIR}"

rm -f "${ZIP_PATH}" "${LATEST_ZIP_PATH}"
ditto -c -k --keepParent "${APP_DIR}" "${ZIP_PATH}"
cp "${ZIP_PATH}" "${LATEST_ZIP_PATH}"

echo
echo "Created: ${APP_DIR}"
echo "Created: ${ZIP_PATH}"
echo "Created: ${LATEST_ZIP_PATH}"
echo "Bundled runner: ${APP_DIR}/Contents/Resources/model_eval_runner"
