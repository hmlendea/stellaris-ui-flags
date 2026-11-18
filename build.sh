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
# attempts cover machines whose memory is nearly exhausted by other applications.
readonly VARIANT_ATTEMPT_COUNT=5

[ ! -d "${SOURCE_DIR_PATH}" ] && echo "MISSING SOURCE DIRECTORY" && exit -1
[ ! -f "/usr/bin/convert" ] && echo "[ERROR] ImageMagick is not installed on this system" && exit 1
[ ! -f "/usr/bin/potrace" ] && echo "[ERROR] potrace is not installed on this system" && exit 1

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

    # A new instance is required so that consecutive invocations do not attach
    # to an instance that is still shutting down and discard the batch command.
    env "${GIMP_SCRIPT_ARGUMENTS[@]}" "${GIMP_BINARY}" --new-instance -i \
        --batch-interpreter=python-fu-eval -b "${GIMP_BATCH_COMMAND}" --quit
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

    execute-gimp-script-file "png_to_dds" \
        INPUT_IMAGE_PATH "${INPUT_IMAGE_PATH}" \
        OUTPUT_IMAGE_PATH "${OUTPUT_IMAGE_PATH}"

    if [ ! -f "${OUTPUT_IMAGE_PATH}" ]; then
        echo "[ERROR] Failure while converting '${INPUT_IMAGE_PATH}' to '${OUTPUT_IMAGE_PATH}'!"
        exit 3
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

    execute-gimp-script-file "svg_to_png" \
        INPUT_IMAGE_PATH "${INPUT_IMAGE_PATH}" \
        OUTPUT_IMAGE_PATH "${OUTPUT_IMAGE_PATH}" \
        OUTPUT_IMAGE_SIZE "${OUTPUT_IMAGE_SIZE}"

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

    # All variants are rendered in a single GIMP session because each process costs about four seconds to start.
    execute-gimp-script-file "render_flag_variants" \
        SOURCE_PATH "${SOURCE_PATH}" \
        MAIN_PNG_PATH "${MAIN_PNG_PATH}" \
        MAIN_DDS_PATH "${MAIN_DDS_PATH}" \
        MAP_PNG_PATH "${MAP_PNG_PATH}" \
        MAP_DDS_PATH "${MAP_DDS_PATH}" \
        SMALL_PNG_PATH "${SMALL_PNG_PATH}" \
        SMALL_DDS_PATH "${SMALL_DDS_PATH}" \
        MAIN_SIZE "128" \
        MAP_SIZE "256" \
        SMALL_SIZE "24"

    # A memory-limited machine can terminate the shared session partway, so any variant that is still
    # absent is rendered again through individual invocations, which each release their memory on exit.
    ensure-beveled-variant "${SOURCE_PATH}" "${MAIN_PNG_PATH}" "${MAIN_DDS_PATH}" "128"
    ensure-flat-variant "${SOURCE_PATH}" "${MAP_PNG_PATH}" "${MAP_DDS_PATH}" "256"
    ensure-beveled-variant "${SOURCE_PATH}" "${SMALL_PNG_PATH}" "${SMALL_DDS_PATH}" "24"

    local MISSING_OUTPUT_PATH=""
    for OUTPUT_PATH in "${MAIN_DDS_PATH}" "${MAP_DDS_PATH}" "${SMALL_DDS_PATH}"; do
        [ -f "${OUTPUT_PATH}" ] || MISSING_OUTPUT_PATH="${OUTPUT_PATH}"
    done

    if [ -n "${MISSING_OUTPUT_PATH}" ]; then
        echo "[ERROR] Failure while rendering the flag variants for '${SOURCE_PATH}'!"
        exit 3
    fi
}

function ensure-beveled-variant {
    local SOURCE_PATH="${1}"
    local PNG_PATH="${2}"
    local DDS_PATH="${3}"
    local IMAGE_SIZE="${4}"
    local ATTEMPT_NUMBER=1

    while [ ! -f "${DDS_PATH}" ] && [ "${ATTEMPT_NUMBER}" -le "${VARIANT_ATTEMPT_COUNT}" ]; do
        echo -e "\e[33mRendering the ${IMAGE_SIZE}px variant of '${SOURCE_PATH}' on attempt ${ATTEMPT_NUMBER}...\e[0m"
        render-beveled-variant "${SOURCE_PATH}" "${PNG_PATH}" "${DDS_PATH}" "${IMAGE_SIZE}"
        ATTEMPT_NUMBER=$((ATTEMPT_NUMBER + 1))
    done
}

function ensure-flat-variant {
    local SOURCE_PATH="${1}"
    local PNG_PATH="${2}"
    local DDS_PATH="${3}"
    local IMAGE_SIZE="${4}"
    local ATTEMPT_NUMBER=1

    while [ ! -f "${DDS_PATH}" ] && [ "${ATTEMPT_NUMBER}" -le "${VARIANT_ATTEMPT_COUNT}" ]; do
        echo -e "\e[33mRendering the ${IMAGE_SIZE}px variant of '${SOURCE_PATH}' on attempt ${ATTEMPT_NUMBER}...\e[0m"
        render-flat-variant "${SOURCE_PATH}" "${PNG_PATH}" "${DDS_PATH}" "${IMAGE_SIZE}"
        ATTEMPT_NUMBER=$((ATTEMPT_NUMBER + 1))
    done
}

function render-beveled-variant {
    local SOURCE_PATH="${1}"
    local PNG_PATH="${2}"
    local DDS_PATH="${3}"
    local IMAGE_SIZE="${4}"

    execute-gimp-script-file "svg_to_png" \
        INPUT_IMAGE_PATH "${SOURCE_PATH}" \
        OUTPUT_IMAGE_PATH "${PNG_PATH}" \
        OUTPUT_IMAGE_SIZE "${IMAGE_SIZE}"

    if [ -f "${PNG_PATH}" ]; then
        execute-gimp-script-file "gradient_bevel" IMAGE_PATH "${PNG_PATH}"
        execute-gimp-script-file "png_to_dds" \
            INPUT_IMAGE_PATH "${PNG_PATH}" \
            OUTPUT_IMAGE_PATH "${DDS_PATH}"
    fi
}

function render-flat-variant {
    local SOURCE_PATH="${1}"
    local PNG_PATH="${2}"
    local DDS_PATH="${3}"
    local IMAGE_SIZE="${4}"

    execute-gimp-script-file "svg_to_png" \
        INPUT_IMAGE_PATH "${SOURCE_PATH}" \
        OUTPUT_IMAGE_PATH "${PNG_PATH}" \
        OUTPUT_IMAGE_SIZE "${IMAGE_SIZE}"

    if [ -f "${PNG_PATH}" ]; then
        execute-gimp-script-file "png_to_dds" \
            INPUT_IMAGE_PATH "${PNG_PATH}" \
            OUTPUT_IMAGE_PATH "${DDS_PATH}"
    fi
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

        render-flag \
            "${FLAG_SVG_BUILD_FILE_PATH}" \
            "${FLAG_BUILD_MAIN_FILE_PATH}" \
            "${FLAG_OUTPUT_MAIN_FILE_PATH}" \
            "${FLAG_BUILD_MAP_FILE_PATH}" \
            "${FLAG_OUTPUT_MAP_FILE_PATH}" \
            "${FLAG_BUILD_SMALL_FILE_PATH}" \
            "${FLAG_OUTPUT_SMALL_FILE_PATH}"
    done
done
