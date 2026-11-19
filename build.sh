#!/bin/bash

MOD_ID="ui-flags"
MOD_NAME="Universum Infinitum: Flags"
MOD_VERSION="${1}"
STELLARIS_VERSION="v4.5.*"

if [ -z "${MOD_VERSION}" ]; then
    echo "Please specify a version!"
    exit 1
fi

SOURCE_DIR_PATH="$(pwd)/source"
SOURCE_SCRIPTS_DIR_PATH="${SOURCE_DIR_PATH}/scripts"
SOURCE_FLAGS_DIR_PATH="${SOURCE_DIR_PATH}/flags"
SOURCE_BACKGROUNDS_DIR_PATH="${SOURCE_DIR_PATH}/backgrounds"
SOURCE_COLOURS_FILE_PATH="${SOURCE_DIR_PATH}/colours.txt"
SOURCE_LOCALISATION_FILE_PATH="${SOURCE_DIR_PATH}/localisation.yml"

BUILD_DIR_PATH="$(pwd)/build"
OUTPUT_DIR_PATH="$(pwd)/out"

OUTPUT_MOD_DIR_PATH="${OUTPUT_DIR_PATH}/${MOD_ID}"
OUTPUT_FLAGS_DIR_PATH="${OUTPUT_MOD_DIR_PATH}/flags"
OUTPUT_BACKGROUNDS_DIR_PATH="${OUTPUT_FLAGS_DIR_PATH}/backgrounds"
OUTPUT_LOCALISATIONS_DIR_PATH="${OUTPUT_MOD_DIR_PATH}/localisation"
OUTPUT_COLOURS_FILE_PATH="${OUTPUT_FLAGS_DIR_PATH}/colors.txt"
OUTPUT_LOCALISATION_FILE_PATH="${OUTPUT_LOCALISATIONS_DIR_PATH}/ui-flags_l_english.yml"

MOD_DESCRIPTOR_PRIMARY_FILE_PATH="${OUTPUT_DIR_PATH}/${MOD_ID}.mod"
MOD_DESCRIPTOR_SECONDARY_FILE_PATH="${OUTPUT_MOD_DIR_PATH}/descriptor.mod"

FLAG_NAMES_FILE_PATH="${SOURCE_DIR_PATH}/names.txt"
THUMBNAIL_FILE_PATH="${SOURCE_DIR_PATH}/thumbnail.png"

# Each variant is rendered in a separate GIMP process when the shared session is killed, so several
# attempts cover machines whose memory is nearly exhausted by other applications. A long-lived
# GIMP session can also crash partway, which leaves a truncated PNG behind.
readonly VARIANT_ATTEMPT_COUNT=8

# How many flags to process at once. The SVG rasterisation and the DDS export are cheap, so a high
# value is fine for them; the GIMP bevels are gated separately by FLAG_GIMP_CONCURRENCY.
readonly FLAG_WORKER_COUNT="${FLAG_WORKER_COUNT:-4}"

# How many GIMP processes may run at once. Every instance needs a few hundred megabytes, so raising
# this too far gets the bevels killed by the OOM killer, which silently leaves them unbeveled.
readonly FLAG_GIMP_CONCURRENCY="${FLAG_GIMP_CONCURRENCY:-4}"
readonly GIMP_SLOT_DIRECTORY_PATH="${BUILD_DIR_PATH}/gimp-slots"

[ ! -d "${SOURCE_DIR_PATH}" ] && echo "MISSING SOURCE DIRECTORY" && exit -1
[ ! -f "/usr/bin/convert" ] && echo "[ERROR] ImageMagick is not installed on this system" && exit 1
[ ! -f "/usr/bin/potrace" ] && echo "[ERROR] potrace is not installed on this system" && exit 1

PYTHON_BINARY="/usr/bin/python3"
if [ ! -f "${PYTHON_BINARY}" ]; then
    PYTHON_BINARY="$(command -v python3)"
fi
if [ ! -x "${PYTHON_BINARY}" ]; then
    echo "[ERROR] Python 3 is not installed on this system" && exit 1
fi

RSVG_BINARY="/usr/bin/rsvg-convert"
if [ ! -x "${RSVG_BINARY}" ]; then
    RSVG_BINARY="$(command -v rsvg-convert)"
fi
if [ ! -x "${RSVG_BINARY}" ]; then
    echo "[ERROR] rsvg-convert is not installed on this system" && exit 1
fi

function execute-inkscape {
    local INKSCAPE_BINARY="/usr/bin/inkscape"

    [ ! -f "${INKSCAPE_BINARY}" ] && INKSCAPE_BINARY="/var/lib/flatpak/exports/bin/org.inkscape.Inkscape"
    [ ! -f "${INKSCAPE_BINARY}" ] && INKSCAPE_BINARY="${HOME}/.local/share/flatpak/exports/bin/org.inkscape.Inkscape"
    if [ ! -f "${INKSCAPE_BINARY}" ]; then
        echo "[ERROR] Inkscape is not installed on this system"
        exit 1
    fi

    "${INKSCAPE_BINARY}" ${*}
}

function execute-gimp-script-file {
    local GIMP_SCRIPT_LABEL="${1}" && shift
    local GIMP_SCRIPT_PATH="${SOURCE_SCRIPTS_DIR_PATH}/${GIMP_SCRIPT_LABEL}.py"
    local GIMP_BINARY="/usr/bin/gimp"

    [ ! -f "${GIMP_BINARY}" ] && GIMP_BINARY="/var/lib/flatpak/exports/bin/org.gimp.GIMP"
    [ ! -f "${GIMP_BINARY}" ] && GIMP_BINARY="${HOME}/.local/share/flatpak/exports/bin/org.gimp.GIMP"
    if [ ! -f "${GIMP_BINARY}" ]; then
        echo "[ERROR] GIMP is not installed on this system" >&2
        exit 1
    fi

    if [ ! -f "${GIMP_SCRIPT_PATH}" ]; then
        echo "[ERROR] The specified GIMP script cannot be found!" >&2
        exit 1
    fi

    if [ "$(( $# % 2))" -ne 0 ]; then
        echo "[ERROR] Invalid arguments (count: $#) for execute-gimp-script-file: ${*}" >&2
        exit 2
    fi

    local -a GIMP_SCRIPT_ARGUMENTS=()
    while [ "$#" -gt 0 ]; do
        GIMP_SCRIPT_ARGUMENTS+=("GIMP_SCRIPT_${1}=${2}")
        shift 2
    done

    local GIMP_BATCH_COMMAND="import sys; sys.path.insert(0, '${SOURCE_SCRIPTS_DIR_PATH}'); exec(open('${GIMP_SCRIPT_PATH}').read())"

    # At most FLAG_GIMP_CONCURRENCY GIMP processes may run at once. A lock file per slot keeps the
    # concurrency independent of how many workers the pipeline uses.
    mkdir -p "${GIMP_SLOT_DIRECTORY_PATH}"
    local GIMP_SLOT_PATH=""
    local GIMP_SLOT_NUMBER=1
    while [ -z "${GIMP_SLOT_PATH}" ]; do
        local CANDIDATE_SLOT_PATH="${GIMP_SLOT_DIRECTORY_PATH}/slot-${GIMP_SLOT_NUMBER}.lock"
        exec {GIMP_SLOT_FILE_DESCRIPTOR}>"${CANDIDATE_SLOT_PATH}"

        if flock -n "${GIMP_SLOT_FILE_DESCRIPTOR}"; then
            GIMP_SLOT_PATH="${CANDIDATE_SLOT_PATH}"
        else
            exec {GIMP_SLOT_FILE_DESCRIPTOR}>&-
            GIMP_SLOT_NUMBER=$((GIMP_SLOT_NUMBER + 1))

            if [ "${GIMP_SLOT_NUMBER}" -gt "${FLAG_GIMP_CONCURRENCY}" ]; then
                GIMP_SLOT_NUMBER=1
                sleep 1
            fi
        fi
    done

    # A new instance is required so that consecutive invocations do not attach
    # to an instance that is still shutting down and discard the batch command.
    env "${GIMP_SCRIPT_ARGUMENTS[@]}" "${GIMP_BINARY}" --new-instance -i \
        --batch-interpreter=python-fu-eval -b "${GIMP_BATCH_COMMAND}" --quit
    local GIMP_EXIT_CODE=$?

    exec {GIMP_SLOT_FILE_DESCRIPTOR}>&-

    return "${GIMP_EXIT_CODE}"
}

function xcf-to-png {
    local INPUT_IMAGE_PATH="${1}"
    local OUTPUT_IMAGE_PATH="${2}"

    echo -e "\e[36mConverting XCF to PNG for '${INPUT_IMAGE_PATH}'...\e[0m"

    execute-gimp-script-file "xcf_to_png" \
        INPUT_IMAGE_PATH "${INPUT_IMAGE_PATH}" \
        OUTPUT_IMAGE_PATH "${OUTPUT_IMAGE_PATH}"

    if [ ! -f "${OUTPUT_IMAGE_PATH}" ]; then
        echo "[ERROR] Failure while converting '${INPUT_IMAGE_PATH}' to '${OUTPUT_IMAGE_PATH}'!"
        exit 3
    fi
}

function xcf-to-svg {
    local INPUT_IMAGE_PATH="${1}"
    local OUTPUT_IMAGE_PATH="${2}"
    local OUTPUT_IMAGE_PATH_WITHOUT_EXTENSION="${OUTPUT_IMAGE_PATH%.*}"

    xcf-to-png "${INPUT_IMAGE_PATH}" "${OUTPUT_IMAGE_PATH_WITHOUT_EXTENSION}.png"
    png-to-svg "${OUTPUT_IMAGE_PATH_WITHOUT_EXTENSION}.png" "${OUTPUT_IMAGE_PATH}"
}

function png-to-bmp {
    local INPUT_IMAGE_PATH="${1}"
    local OUTPUT_IMAGE_PATH="${2}"

    echo -e "\e[36mConverting PNG to BMP for '${INPUT_IMAGE_PATH}'...\e[0m"

    convert -background "#000" -flatten "${INPUT_IMAGE_PATH}" "${OUTPUT_IMAGE_PATH}"

    if [ ! -f "${OUTPUT_IMAGE_PATH}" ]; then
        echo "[ERROR] Failure while converting '${INPUT_IMAGE_PATH}' to '${OUTPUT_IMAGE_PATH}'!"
        exit 3
    fi
}

function png-to-svg {
    local INPUT_IMAGE_PATH="${1}"
    local OUTPUT_IMAGE_PATH="${2}"
    local OUTPUT_IMAGE_PATH_WITHOUT_EXTENSION="${OUTPUT_IMAGE_PATH%.*}"

    png-to-bmp "${INPUT_IMAGE_PATH}" "${OUTPUT_IMAGE_PATH_WITHOUT_EXTENSION}.bmp"
    bmp-to-svg "${OUTPUT_IMAGE_PATH_WITHOUT_EXTENSION}.bmp" "${OUTPUT_IMAGE_PATH}"
}


function png-to-dds {
    local INPUT_IMAGE_PATH="${1}"
    local OUTPUT_IMAGE_PATH="${2}"

    echo -e "\e[36mConverting PNG to DDS for '${INPUT_IMAGE_PATH}'...\e[0m"

    # The uncompressed DDS format is simple enough to write directly, which avoids a GIMP start.
    env "GIMP_SCRIPT_INPUT_IMAGE_PATH=${INPUT_IMAGE_PATH}" \
        "GIMP_SCRIPT_OUTPUT_IMAGE_PATH=${OUTPUT_IMAGE_PATH}" \
        "${PYTHON_BINARY}" "${SOURCE_SCRIPTS_DIR_PATH}/png_to_dds.py" || true

    if [ ! -f "${OUTPUT_IMAGE_PATH}" ]; then
        echo "[ERROR] Failure while converting '${INPUT_IMAGE_PATH}' to '${OUTPUT_IMAGE_PATH}'!"
        return 1
    fi
}

function bmp-to-svg {
    local INPUT_IMAGE_PATH="${1}"
    local OUTPUT_IMAGE_PATH="${2}"

    echo -e "\e[36mConverting BMP to SVG for '${INPUT_IMAGE_PATH}'...\e[0m"

    potrace --opaque -s "${INPUT_IMAGE_PATH}" -o "${OUTPUT_IMAGE_PATH}"

    if [ ! -f "${OUTPUT_IMAGE_PATH}" ]; then
        echo "[ERROR] Failure while converting '${INPUT_IMAGE_PATH}' to '${OUTPUT_IMAGE_PATH}'!"
        exit 3
    fi
}

function ai-to-svg {
    local INPUT_IMAGE_PATH="${1}"
    local OUTPUT_IMAGE_PATH="${2}"

    echo -e "\e[36mConverting AI to SVG for '${INPUT_IMAGE_PATH}'...\e[0m"

    execute-inkscape -f "${INPUT_IMAGE_PATH}" -l "${OUTPUT_IMAGE_PATH}"

    if [ ! -f "${OUTPUT_IMAGE_PATH}" ]; then
        echo "[ERROR] Failure while converting '${INPUT_IMAGE_PATH}' to '${OUTPUT_IMAGE_PATH}'!"
        exit 3
    fi
}

function svg-to-png {
    local INPUT_IMAGE_PATH="${1}"
    local OUTPUT_IMAGE_PATH="${2}"
    local OUTPUT_IMAGE_SIZE="${3}"

    echo -e "\e[36mConverting SVG to PNG for '${INPUT_IMAGE_PATH}'...\e[0m"

    # rsvg-convert rasterises the emblem over a flat background, and the emblem is simply the
    # difference from that background colour, which becomes the alpha channel. This reproduces the
    # GIMP pipeline pixel for pixel while costing milliseconds instead of a multi-second GIMP start.
    # The temporary file must keep a .png extension because rsvg-convert infers the output format
    # from it.
    local RAW_PNG_PATH="${OUTPUT_IMAGE_PATH}.raw.png"

    # The background must be white. SVGs traced from bitmaps draw black shapes without a background
    # rectangle, so the default transparent background would render black on black and leave the
    # emblem invisible.
    "${RSVG_BINARY}" -w "${OUTPUT_IMAGE_SIZE}" -h "${OUTPUT_IMAGE_SIZE}" -b white \
        -o "${RAW_PNG_PATH}" "${INPUT_IMAGE_PATH}"

    if [ ! -f "${RAW_PNG_PATH}" ]; then
        echo "[ERROR] Failure while rasterising '${INPUT_IMAGE_PATH}'!"
        exit 3
    fi

    local BACKGROUND_COLOUR=$(magick "${RAW_PNG_PATH}" -format '%[pixel:p{3,0}]' info:)

    # The emblem is everything that differs from the background colour, and that difference is the
    # alpha channel. The base is a plain white image, because the pipeline expects the emblem to be
    # white and to carry its shape in the alpha channel alone.
    magick "${RAW_PNG_PATH}" \
        \( +clone -fill "${BACKGROUND_COLOUR}" -colorize 100 \) \
        -compose Difference -composite \
        -colorspace Gray \
        "${RAW_PNG_PATH}.alpha.png"

    magick -size "${OUTPUT_IMAGE_SIZE}x${OUTPUT_IMAGE_SIZE}" xc:white \
        "${RAW_PNG_PATH}.alpha.png" -alpha off \
        -compose CopyOpacity -composite \
        -type TrueColorAlpha \
        -define png:color-type=6 \
        "${OUTPUT_IMAGE_PATH}"

    rm -f "${RAW_PNG_PATH}" "${RAW_PNG_PATH}.alpha.png"

    if [ ! -f "${OUTPUT_IMAGE_PATH}" ]; then
        echo "[ERROR] Failure while converting '${INPUT_IMAGE_PATH}' to '${OUTPUT_IMAGE_PATH}'!"
        exit 3
    fi
}

function apply-gradient-bevel {
    local IMAGE_PATH="${1}"

    echo -e "\e[36mApplying gradient bevel on '${IMAGE_PATH}'...\e[0m"

    execute-gimp-script-file "gradient_bevel" IMAGE_PATH "${IMAGE_PATH}"
}

function render-flag {
    local SOURCE_PATH="${1}"
    local MAIN_PNG_PATH="${2}"
    local MAIN_DDS_PATH="${3}"
    local MAP_PNG_PATH="${4}"
    local MAP_DDS_PATH="${5}"
    local SMALL_PNG_PATH="${6}"
    local SMALL_DDS_PATH="${7}"

    echo -e "\e[36mRendering the flag variants for '${SOURCE_PATH}'...\e[0m"

    # Only the two bevels need GIMP. The SVG rasterisation and the DDS export use plain tools, and
    # each GIMP start costs about three seconds, so the session is skipped whenever both bevels are
    # already present.
    if ! is-beveled-png "${MAIN_PNG_PATH}" || ! is-beveled-png "${SMALL_PNG_PATH}"; then
        if ! is-beveled-png "${MAIN_PNG_PATH}"; then
            svg-to-png "${SOURCE_PATH}" "${MAIN_PNG_PATH}" "128"
            execute-gimp-script-file "gradient_bevel" IMAGE_PATH "${MAIN_PNG_PATH}"
        fi

        if ! is-beveled-png "${SMALL_PNG_PATH}"; then
            svg-to-png "${SOURCE_PATH}" "${SMALL_PNG_PATH}" "24"
            execute-gimp-script-file "gradient_bevel" IMAGE_PATH "${SMALL_PNG_PATH}"
        fi
    fi

    if ! is-usable-png "${MAP_PNG_PATH}"; then
        svg-to-png "${SOURCE_PATH}" "${MAP_PNG_PATH}" "256"
    fi

    # A memory-limited machine can terminate a GIMP session partway, so any bevel that is still
    # missing is attempted again through individual invocations.
    ensure-beveled-png "${SOURCE_PATH}" "${MAIN_PNG_PATH}" "128"
    ensure-beveled-png "${SOURCE_PATH}" "${SMALL_PNG_PATH}" "24"
    png-to-dds "${MAIN_PNG_PATH}" "${MAIN_DDS_PATH}"
    png-to-dds "${MAP_PNG_PATH}" "${MAP_DDS_PATH}"
    png-to-dds "${SMALL_PNG_PATH}" "${SMALL_DDS_PATH}"

    local MISSING_OUTPUT_PATH=""
    for OUTPUT_PATH in "${MAIN_DDS_PATH}" "${MAP_DDS_PATH}" "${SMALL_DDS_PATH}"; do
        [ -f "${OUTPUT_PATH}" ] || MISSING_OUTPUT_PATH="${OUTPUT_PATH}"
    done

    if [ -n "${MISSING_OUTPUT_PATH}" ]; then
        echo "[ERROR] Failure while rendering the flag variants for '${SOURCE_PATH}'!"
        exit 3
    fi
}

function is-usable-png {
    local PNG_PATH="${1}"

    [ -s "${PNG_PATH}" ] || return 1
    identify "${PNG_PATH}" >/dev/null 2>&1
}

function bevel-marker-path {
    local PNG_PATH="${1}"

    echo "${PNG_PATH}.beveled"
}

function is-beveled-png {
    local PNG_PATH="${1}"

    is-usable-png "${PNG_PATH}" && [ -f "$(bevel-marker-path "${PNG_PATH}")" ]
}

function ensure-beveled-png {
    local SOURCE_PATH="${1}"
    local PNG_PATH="${2}"
    local IMAGE_SIZE="${3}"
    local ATTEMPT_NUMBER=1

    while ! is-beveled-png "${PNG_PATH}" && [ "${ATTEMPT_NUMBER}" -le "${VARIANT_ATTEMPT_COUNT}" ]; do
        echo -e "\e[33mRendering the ${IMAGE_SIZE}px PNG of '${SOURCE_PATH}' on attempt ${ATTEMPT_NUMBER}...\e[0m"
        rm -f "${PNG_PATH}" "$(bevel-marker-path "${PNG_PATH}")"
        render-beveled-png "${SOURCE_PATH}" "${PNG_PATH}" "${IMAGE_SIZE}"
        ATTEMPT_NUMBER=$((ATTEMPT_NUMBER + 1))
    done
}

function ensure-flat-png {
    local SOURCE_PATH="${1}"
    local PNG_PATH="${2}"
    local IMAGE_SIZE="${3}"
    local ATTEMPT_NUMBER=1

    while ! is-usable-png "${PNG_PATH}" && [ "${ATTEMPT_NUMBER}" -le "${VARIANT_ATTEMPT_COUNT}" ]; do
        echo -e "\e[33mRendering the ${IMAGE_SIZE}px PNG of '${SOURCE_PATH}' on attempt ${ATTEMPT_NUMBER}...\e[0m"
        rm -f "${PNG_PATH}"
        svg-to-png "${SOURCE_PATH}" "${PNG_PATH}" "${IMAGE_SIZE}"
        ATTEMPT_NUMBER=$((ATTEMPT_NUMBER + 1))
    done
}

function render-beveled-png {
    local SOURCE_PATH="${1}"
    local PNG_PATH="${2}"
    local IMAGE_SIZE="${3}"

    svg-to-png "${SOURCE_PATH}" "${PNG_PATH}" "${IMAGE_SIZE}"

    if [ -f "${PNG_PATH}" ]; then
        execute-gimp-script-file "gradient_bevel" IMAGE_PATH "${PNG_PATH}"
    fi
}

function render-flat-png {
    local SOURCE_PATH="${1}"
    local PNG_PATH="${2}"
    local IMAGE_SIZE="${3}"

    svg-to-png "${SOURCE_PATH}" "${PNG_PATH}" "${IMAGE_SIZE}"
}

function get-flag-file-name {
    local SOURCE_FILE_NAME="$1"
    local FILE_PREFIX="ui_"
    local FLAG_FILE_NAME=$(grep "^${SOURCE_FILE_NAME}=" "${FLAG_NAMES_FILE_PATH}" | awk -F= '{print $2}')

    if [ -z "${FLAG_FILE_NAME}" ]; then
        echo "${FILE_PREFIX}${SOURCE_FILE_NAME}"
    else
        echo "${FLAG_FILE_NAME}"
    fi
}

function generate-mod-descriptor {
    local FILE_PATH="${1}"

    echo "version=\"${MOD_VERSION}\"" > "${FILE_PATH}"
    echo "name=\"${MOD_NAME}\"" >> "${FILE_PATH}"
    echo "path=\"mod/${MOD_ID}\"" >> "${FILE_PATH}"
    echo "tags={" >> "${FILE_PATH}"
    echo "	\"Graphics\"" >> "${FILE_PATH}"
    echo "}" >> "${FILE_PATH}"
    echo "supported_version=\"${STELLARIS_VERSION}\"" >> "${FILE_PATH}"
    echo "" >> "${FILE_PATH}"
}

mkdir -p "${OUTPUT_BACKGROUNDS_DIR_PATH}"

# Worker logs from a previous run would otherwise be summarised again at the end of this one.
rm -f "${BUILD_DIR_PATH}"/*.log
mkdir -p "${OUTPUT_LOCALISATIONS_DIR_PATH}"

cp "${SOURCE_BACKGROUNDS_DIR_PATH}"/* "${OUTPUT_BACKGROUNDS_DIR_PATH}"
cp "${SOURCE_COLOURS_FILE_PATH}" "${OUTPUT_COLOURS_FILE_PATH}"
cp "${SOURCE_LOCALISATION_FILE_PATH}" "${OUTPUT_LOCALISATION_FILE_PATH}"
cp "${THUMBNAIL_FILE_PATH}" "${OUTPUT_MOD_DIR_PATH}"

generate-mod-descriptor "${MOD_DESCRIPTOR_PRIMARY_FILE_PATH}"
generate-mod-descriptor "${MOD_DESCRIPTOR_SECONDARY_FILE_PATH}"

for CATEGORY_DIR in "${SOURCE_FLAGS_DIR_PATH}"/*; do
    [ -z "${CATEGORY_DIR}" ] && continue
    [ $(ls -A "${CATEGORY_DIR}" | wc -l) -eq 0 ] && continue
    [ ! -d "${CATEGORY_DIR}" ] && continue

    CATEGORY_NAME=$(basename "${CATEGORY_DIR}")

    CATEGORY_BUILD_DIR_PATH="${BUILD_DIR_PATH}/${CATEGORY_NAME}"
    CATEGORY_BUILD_MAP_DIR_PATH="${CATEGORY_BUILD_DIR_PATH}/map"
    CATEGORY_BUILD_SMALL_DIR_PATH="${CATEGORY_BUILD_DIR_PATH}/small"
    CATEGORY_OUTPUT_DIR_PATH="${OUTPUT_FLAGS_DIR_PATH}/${CATEGORY_NAME}"
    CATEGORY_OUTPUT_MAP_DIR_PATH="${CATEGORY_OUTPUT_DIR_PATH}/map"
    CATEGORY_OUTPUT_SMALL_DIR_PATH="${CATEGORY_OUTPUT_DIR_PATH}/small"

    mkdir -p "${CATEGORY_BUILD_MAP_DIR_PATH}"
    mkdir -p "${CATEGORY_BUILD_SMALL_DIR_PATH}"

    mkdir -p "${CATEGORY_OUTPUT_MAP_DIR_PATH}"
    mkdir -p "${CATEGORY_OUTPUT_SMALL_DIR_PATH}"

    if [ -f "${CATEGORY_DIR}/usage.txt" ]; then
        cp "${CATEGORY_DIR}/usage.txt" "${CATEGORY_OUTPUT_DIR_PATH}/usage.txt"
    fi

    for FILE in "${CATEGORY_DIR}"/* ; do
        FILE_BASENAME=$(basename "${FILE}")

        [ "${FILE_BASENAME}" == "usage.txt" ] && continue

        FILE_NAME="${FILE_BASENAME%.*}"
        FILE_EXTENSION=$(echo "${FILE_BASENAME}" | cut -d'.' -f2)

        FLAG_FILE_NAME=$(get-flag-file-name "${FILE_NAME}")

        FLAG_BMP_BUILD_FILE_PATH="${CATEGORY_BUILD_DIR_PATH}/${FLAG_FILE_NAME}.bmp"
        FLAG_PNG_BUILD_FILE_PATH="${CATEGORY_BUILD_DIR_PATH}/${FLAG_FILE_NAME}.png"
        FLAG_SVG_BUILD_FILE_PATH="${CATEGORY_BUILD_DIR_PATH}/${FLAG_FILE_NAME}.svg"

        FLAG_BUILD_MAIN_FILE_PATH="${FLAG_PNG_BUILD_FILE_PATH}"
        FLAG_BUILD_MAP_FILE_PATH="${CATEGORY_BUILD_MAP_DIR_PATH}/${FLAG_FILE_NAME}.png"
        FLAG_BUILD_SMALL_FILE_PATH="${CATEGORY_BUILD_SMALL_DIR_PATH}/${FLAG_FILE_NAME}.png"

        FLAG_OUTPUT_MAIN_FILE_PATH="${CATEGORY_OUTPUT_DIR_PATH}/${FLAG_FILE_NAME}.dds"
        FLAG_OUTPUT_MAP_FILE_PATH="${CATEGORY_OUTPUT_MAP_DIR_PATH}/${FLAG_FILE_NAME}.dds"
        FLAG_OUTPUT_SMALL_FILE_PATH="${CATEGORY_OUTPUT_SMALL_DIR_PATH}/${FLAG_FILE_NAME}.dds"

        if [ -f "${FLAG_OUTPUT_MAIN_FILE_PATH}" ] && [ -f "${FLAG_OUTPUT_MAP_FILE_PATH}" ] && [ -f "${FLAG_OUTPUT_SMALL_FILE_PATH}" ]; then
            continue
        fi

        echo "Processing ${FILE_NAME} (${FILE})..."

        if [ "${FILE_EXTENSION}" == "bmp" ]; then
            bmp-to-svg "${FILE}" "${FLAG_SVG_BUILD_FILE_PATH}"
        elif [ "${FILE_EXTENSION}" == "xcf" ]; then
            xcf-to-svg "${FILE}" "${FLAG_SVG_BUILD_FILE_PATH}"
        elif [ "${FILE_EXTENSION}" == "png" ]; then
            png-to-svg "${FILE}" "${FLAG_SVG_BUILD_FILE_PATH}"
        elif [ "${FILE_EXTENSION}" == "ai" ]; then
            ai-to-svg "${FILE}" "${FLAG_SVG_BUILD_FILE_PATH}"
        elif [ "${FILE_EXTENSION}" == "svg" ]; then
            cp "${FILE}" "${FLAG_SVG_BUILD_FILE_PATH}"
        fi

        # Rendering is limited to FLAG_WORKER_COUNT concurrent GIMP processes. Each worker logs to
        # its own file so that the output is not interleaved.
        while [ "$(jobs -rp | wc -l)" -ge "${FLAG_WORKER_COUNT}" ]; do
            wait -n
        done

        (
            FLAG_LOG_PATH="${BUILD_DIR_PATH}/${FLAG_FILE_NAME}.log"
            render-flag \
                "${FLAG_SVG_BUILD_FILE_PATH}" \
                "${FLAG_BUILD_MAIN_FILE_PATH}" \
                "${FLAG_OUTPUT_MAIN_FILE_PATH}" \
                "${FLAG_BUILD_MAP_FILE_PATH}" \
                "${FLAG_OUTPUT_MAP_FILE_PATH}" \
                "${FLAG_BUILD_SMALL_FILE_PATH}" \
                "${FLAG_OUTPUT_SMALL_FILE_PATH}" > "${FLAG_LOG_PATH}" 2>&1
        ) &
    done
done

wait

for LOG_FILE_PATH in "${BUILD_DIR_PATH}"/*.log; do
    [ -f "${LOG_FILE_PATH}" ] || continue
    grep -E "\[(ERROR|WARNING)\]|on attempt" "${LOG_FILE_PATH}"
done

MISSING_OUTPUT_COUNT=$(find "${OUTPUT_FLAGS_DIR_PATH}" -name '*.dds' -not -path '*/backgrounds/*' | wc -l)
EXPECTED_OUTPUT_COUNT=$(( $(find "${SOURCE_FLAGS_DIR_PATH}" -type f \( -name '*.svg' -o -name '*.png' -o -name '*.bmp' -o -name '*.xcf' -o -name '*.ai' \) | wc -l) * 3 ))

echo "Produced ${MISSING_OUTPUT_COUNT} of ${EXPECTED_OUTPUT_COUNT} flag DDS files."
