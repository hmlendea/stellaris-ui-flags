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

# A GIMP session that is killed leaves every bevel it had not finished missing, so several rounds
# cover machines whose memory is nearly exhausted by other applications. A long-lived GIMP session
# can also crash partway, which leaves a truncated PNG behind.
readonly VARIANT_ATTEMPT_COUNT=8

# How many flags to rasterise and export at once. Both stages use plain tools, so the workers only
# trade processor time; the GIMP bevels are batched separately and gated by FLAG_GIMP_CONCURRENCY.
readonly FLAG_WORKER_COUNT="${FLAG_WORKER_COUNT:-4}"

# How many GIMP sessions may run at once. Every instance needs a few hundred megabytes, so raising
# this too far gets the bevels killed by the OOM killer, which silently leaves them unbeveled.
readonly FLAG_GIMP_CONCURRENCY="${FLAG_GIMP_CONCURRENCY:-4}"

# Estimate how many images a GIMP session can hold before the machine runs out of memory. Every
# flag's working set inside a session is roughly 200 MiB, and FLAG_GIMP_CONCURRENCY sessions may run
# at once, so the available memory is shared between them. The floor is deliberately above the point
# where sessions would be started for almost every image, because the session start dominates the
# per-image cost and a tiny batch multiplies both the starts and the number of kill-and-retry rounds.
function bevel-batch-default {
    local mem_kb="$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
    local budget=$((mem_kb / (200000 * FLAG_GIMP_CONCURRENCY)))

    if [ "${budget}" -lt 4 ]; then
        echo 4
    elif [ "${budget}" -lt 8 ]; then
        echo 6
    else
        echo 8
    fi
}

# How many flags one GIMP session bevels before it is replaced. Starting GIMP costs a few seconds
# while every further image in a running session costs a fraction of one, so a larger batch is
# faster; however the memory a session holds also grows with the number of images it has processed,
# so an oversized batch exhausts memory and is killed partway.
# When the variable is unset the build autodetects a safe default from available memory; supply the
# variable yourself (e.g. FLAG_BEVEL_BATCH_SIZE=12) only when you know your machine can keep every
# session alive. Too small wastes session starts; too large leaves most flags unbeveled.
readonly FLAG_BEVEL_BATCH_SIZE="${FLAG_BEVEL_BATCH_SIZE:-$(bevel-batch-default)}"
readonly GIMP_SLOT_DIRECTORY_PATH="${BUILD_DIR_PATH}/gimp-slots"

echo "Using a bevel batch size of ${FLAG_BEVEL_BATCH_SIZE} and ${FLAG_GIMP_CONCURRENCY} concurrent GIMP sessions."

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

function source-to-svg {
    local SOURCE_PATH="${1}"
    local OUTPUT_PATH="${2}"

    case "${SOURCE_PATH##*.}" in
        bmp) bmp-to-svg "${SOURCE_PATH}" "${OUTPUT_PATH}" ;;
        png) png-to-svg "${SOURCE_PATH}" "${OUTPUT_PATH}" ;;
        svg) cp "${SOURCE_PATH}" "${OUTPUT_PATH}" ;;
        *) echo "[WARNING] Unsupported source format for '${SOURCE_PATH}'!" >&2 ;;
    esac
}

function export-map-dds {
    local MAP_PNG_PATH="${1}"
    local MAP_DDS_PATH="${2}"

    png-to-dds "${MAP_PNG_PATH}" "${MAP_DDS_PATH}"

    if [ ! -f "${MAP_DDS_PATH}" ]; then
        echo "[ERROR] Failure while exporting '${MAP_DDS_PATH}'!"
        exit 3
    fi
}

function export-beveled-dds {
    local MAIN_PNG_PATH="${1}"
    local MAIN_DDS_PATH="${2}"
    local SMALL_PNG_PATH="${3}"
    local SMALL_DDS_PATH="${4}"

    png-to-dds "${MAIN_PNG_PATH}" "${MAIN_DDS_PATH}"
    png-to-dds "${SMALL_PNG_PATH}" "${SMALL_DDS_PATH}"

    local MISSING_OUTPUT_PATH=""
    for OUTPUT_PATH in "${MAIN_DDS_PATH}" "${SMALL_DDS_PATH}"; do
        [ -f "${OUTPUT_PATH}" ] || MISSING_OUTPUT_PATH="${OUTPUT_PATH}"
    done

    if [ -n "${MISSING_OUTPUT_PATH}" ]; then
        echo "[ERROR] Failure while exporting '${MISSING_OUTPUT_PATH}'!"
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

function collect-unbeveled-pngs {
    FLAG_BEVEL_PATHS=()

    for FLAG_KEY in "${FLAG_KEYS[@]}"; do
        for PNG_PATH in "${FLAG_MAIN_PNG_PATHS[${FLAG_KEY}]}" "${FLAG_SMALL_PNG_PATHS[${FLAG_KEY}]}"; do
            [ -n "${PNG_PATH}" ] || continue
            is-beveled-png "${PNG_PATH}" && continue

            FLAG_BEVEL_PATHS+=("${PNG_PATH}")
        done
    done
}

function rasterise-bevel-png {
    local PNG_PATH="${1}"

    rm -f "${PNG_PATH}"
    svg-to-png "${FLAG_BEVEL_SVGS[${PNG_PATH}]}" "${PNG_PATH}" "${FLAG_BEVEL_SIZES[${PNG_PATH}]}"
}

function start-bevel-session {
    local ROUND_NAME="${1}" && shift
    local CHUNK_NUMBER="${1}" && shift

    while [ "$(jobs -rp | wc -l)" -ge "${FLAG_GIMP_CONCURRENCY}" ]; do
        wait -n
    done

    local BEVEL_LOG_PATH="${BUILD_DIR_PATH}/bevel-${ROUND_NAME}-${CHUNK_NUMBER}.log"

    (
        execute-gimp-script-file "bevel_batch" IMAGE_PATHS "$(printf '%s\n' "$@")"
    ) > "${BEVEL_LOG_PATH}" 2>&1 &
}

function bevel-pngs {
    local ROUND_NAME="${1}" && shift

    local -a CHUNK_PATHS=()
    local CHUNK_NUMBER=0

    for PNG_PATH in "$@"; do
        is-usable-png "${PNG_PATH}" || continue

        CHUNK_PATHS+=("${PNG_PATH}")

        if [ "${#CHUNK_PATHS[@]}" -ge "${FLAG_BEVEL_BATCH_SIZE}" ]; then
            start-bevel-session "${ROUND_NAME}" "${CHUNK_NUMBER}" "${CHUNK_PATHS[@]}"
            CHUNK_PATHS=()
            CHUNK_NUMBER=$((CHUNK_NUMBER + 1))
        fi
    done

    if [ "${#CHUNK_PATHS[@]}" -gt 0 ]; then
        start-bevel-session "${ROUND_NAME}" "${CHUNK_NUMBER}" "${CHUNK_PATHS[@]}"
    fi

    wait
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

# Every flag that still needs work is registered here, so the bevels can be batched into shared
# GIMP sessions after the parallel rasterisation has finished.
declare -a FLAG_KEYS=()
declare -A FLAG_MAIN_PNG_PATHS=()
declare -A FLAG_SMALL_PNG_PATHS=()
declare -A FLAG_MAIN_DDS_PATHS=()
declare -A FLAG_SMALL_DDS_PATHS=()
declare -A FLAG_BEVEL_SVGS=()
declare -A FLAG_BEVEL_SIZES=()

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

        source-to-svg "${FILE}" "${FLAG_SVG_BUILD_FILE_PATH}"

        FLAG_KEY="${CATEGORY_NAME}/${FLAG_FILE_NAME}"
        FLAG_KEYS+=("${FLAG_KEY}")
        FLAG_MAIN_PNG_PATHS[${FLAG_KEY}]="${FLAG_BUILD_MAIN_FILE_PATH}"
        FLAG_SMALL_PNG_PATHS[${FLAG_KEY}]="${FLAG_BUILD_SMALL_FILE_PATH}"
        FLAG_MAIN_DDS_PATHS[${FLAG_KEY}]="${FLAG_OUTPUT_MAIN_FILE_PATH}"
        FLAG_SMALL_DDS_PATHS[${FLAG_KEY}]="${FLAG_OUTPUT_SMALL_FILE_PATH}"

        FLAG_BEVEL_SVGS[${FLAG_BUILD_MAIN_FILE_PATH}]="${FLAG_SVG_BUILD_FILE_PATH}"
        FLAG_BEVEL_SIZES[${FLAG_BUILD_MAIN_FILE_PATH}]="128"
        FLAG_BEVEL_SVGS[${FLAG_BUILD_SMALL_FILE_PATH}]="${FLAG_SVG_BUILD_FILE_PATH}"
        FLAG_BEVEL_SIZES[${FLAG_BUILD_SMALL_FILE_PATH}]="24"

        # The rasterisation is limited to FLAG_WORKER_COUNT concurrent workers. Each worker logs to
        # its own file so that the output is not interleaved.
        while [ "$(jobs -rp | wc -l)" -ge "${FLAG_WORKER_COUNT}" ]; do
            wait -n
        done

        (
            FLAG_LOG_PATH="${BUILD_DIR_PATH}/${CATEGORY_NAME}-${FLAG_FILE_NAME}.log"

            (
                is-beveled-png "${FLAG_BUILD_MAIN_FILE_PATH}" || rasterise-bevel-png "${FLAG_BUILD_MAIN_FILE_PATH}"
                is-beveled-png "${FLAG_BUILD_SMALL_FILE_PATH}" || rasterise-bevel-png "${FLAG_BUILD_SMALL_FILE_PATH}"

                if ! is-usable-png "${FLAG_BUILD_MAP_FILE_PATH}"; then
                    svg-to-png "${FLAG_SVG_BUILD_FILE_PATH}" "${FLAG_BUILD_MAP_FILE_PATH}" "256"
                fi

                # The map needs no bevel, so its DDS is exported now. The main and small DDS are
                # exported after the bevel rounds, from the beveled PNGs.
                export-map-dds "${FLAG_BUILD_MAP_FILE_PATH}" "${FLAG_OUTPUT_MAP_FILE_PATH}"
            ) > "${FLAG_LOG_PATH}" 2>&1
        ) &
    done
done

wait

# The bevels are batched, because starting GIMP costs a few seconds while every further image in a
# running session costs a fraction of one. A session that is killed leaves the bevels it had not
# reached unmarked, and those are retried over the remaining rounds.
for BEVEL_ROUND_NUMBER in $(seq 1 "${VARIANT_ATTEMPT_COUNT}"); do
    collect-unbeveled-pngs

    [ "${#FLAG_BEVEL_PATHS[@]}" -eq 0 ] && break

    if [ "${BEVEL_ROUND_NUMBER}" -gt 1 ]; then
        echo -e "\e[33mBeveling ${#FLAG_BEVEL_PATHS[@]} flags again on attempt ${BEVEL_ROUND_NUMBER}...\e[0m"

        for PNG_PATH in "${FLAG_BEVEL_PATHS[@]}"; do
            rm -f "$(bevel-marker-path "${PNG_PATH}")"
        done
    fi

    bevel-pngs "${BEVEL_ROUND_NUMBER}" "${FLAG_BEVEL_PATHS[@]}"

    # A memory-limited machine can terminate a session partway, so every bevel that is still missing
    # is rasterised again before the next round attempts it.
    for PNG_PATH in "${FLAG_BEVEL_PATHS[@]}"; do
        is-usable-png "${PNG_PATH}" || rasterise-bevel-png "${PNG_PATH}"
    done
done

wait

# The beveled main and small PNGs are exported only now, so their DDS textures carry the bevel. The
# map DDS was already exported by the workers, because the map needs no bevel. The exports are
# bounded by the same worker count as the rasterisation, so the process count stays in check.
for FLAG_KEY in "${FLAG_KEYS[@]}"; do
    while [ "$(jobs -rp | wc -l)" -ge "${FLAG_WORKER_COUNT}" ]; do
        wait -n
    done

    FLAG_EXPORT_LOG_PATH="${BUILD_DIR_PATH}/${FLAG_KEY//\//-}.export.log"

    (
        export-beveled-dds \
            "${FLAG_MAIN_PNG_PATHS[${FLAG_KEY}]}" \
            "${FLAG_MAIN_DDS_PATHS[${FLAG_KEY}]}" \
            "${FLAG_SMALL_PNG_PATHS[${FLAG_KEY}]}" \
            "${FLAG_SMALL_DDS_PATHS[${FLAG_KEY}]}"
    ) > "${FLAG_EXPORT_LOG_PATH}" 2>&1 &
done

wait

for LOG_FILE_PATH in "${BUILD_DIR_PATH}"/*.log; do
    [ -f "${LOG_FILE_PATH}" ] || continue
    grep -E "\[(ERROR|WARNING)\]|on attempt|not beveled" "${LOG_FILE_PATH}"
done

MISSING_BEVEL_COUNT=0

for FLAG_KEY in "${FLAG_KEYS[@]}"; do
    is-beveled-png "${FLAG_MAIN_PNG_PATHS[${FLAG_KEY}]}" || MISSING_BEVEL_COUNT=$((MISSING_BEVEL_COUNT + 1))
    is-beveled-png "${FLAG_SMALL_PNG_PATHS[${FLAG_KEY}]}" || MISSING_BEVEL_COUNT=$((MISSING_BEVEL_COUNT + 1))
done

if [ "${MISSING_BEVEL_COUNT}" -gt 0 ]; then
    echo "[ERROR] ${MISSING_BEVEL_COUNT} flags were not beveled after ${VARIANT_ATTEMPT_COUNT} attempts!"
fi

MISSING_OUTPUT_COUNT=$(find "${OUTPUT_FLAGS_DIR_PATH}" -name '*.dds' -not -path '*/backgrounds/*' | wc -l)
EXPECTED_OUTPUT_COUNT=$(( $(find "${SOURCE_FLAGS_DIR_PATH}" -type f \( -name '*.svg' -o -name '*.png' -o -name '*.bmp' \) | wc -l) * 3 ))

echo "Produced ${MISSING_OUTPUT_COUNT} of ${EXPECTED_OUTPUT_COUNT} flag DDS files."
