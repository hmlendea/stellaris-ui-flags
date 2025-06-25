#!/bin/bash

MOD_ID="ui-flags"
MOD_NAME="Universum Infinitum: Flags"
MOD_VERSION="${1}"
STELLARIS_VERSION="4.0.*"

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

function execute-scriptfu {
    local GIMP_SCRIPTFU="${1}"
    local GIMP_BINARY="/usr/bin/gimp"

    [ ! -f "${GIMP_BINARY}" ] && GIMP_BINARY="/var/lib/flatpak/exports/bin/org.gimp.GIMP"
    [ ! -f "${GIMP_BINARY}" ] && GIMP_BINARY="${HOME}/.local/share/flatpak/exports/bin/org.gimp.GIMP"
    if [ ! -f "${GIMP_BINARY}" ]; then
        echo "[ERROR] GIMP is not installed on this system"
        exit 1
    fi

    "${GIMP_BINARY}" -i -b ''"${GIMP_SCRIPTFU}"'' -b '(gimp-quit 0)' &>/dev/null
}

function execute-scriptfu-file {
    local GIMP_SCRIPTFU_LABEL="${1}" && shift
    local GIMP_SCRIPTFU_PATH="${SOURCE_SCRIPTS_DIR_PATH}/${GIMP_SCRIPTFU_LABEL}.lisp"
    local GIMP_SCRIPTFU=""

    if [ ! -f "${GIMP_SCRIPTFU_PATH}" ]; then
        echo "[ERROR] The specified GIMP Script-fu file cannot be found!"
        exit 1
    fi

    GIMP_SCRIPTFU=$(cat "${GIMP_SCRIPTFU_PATH}")

    if [ "$(( $# % 2))" -ne 0 ]; then
        echo "[ERROR] Invalid arguments (count: $#) for execute-scriptfu: ${*}" >&2
        exit 2
    fi

    local PAIRS_COUNT=$(($# / 2))
    local VARIABLE_NAME=""
    local VARIABLE_VALUE=""
    local VARIABLE_VALUE_ESCAPED=""

    for I in $(seq 1 ${PAIRS_COUNT}); do
        VARIABLE_NAME="${1}" && shift
        VARIABLE_VALUE="${1}" && shift
        VARIABLE_VALUE_ESCAPED=$(echo "${VAL}" | sed -e 's/[]\/$*.^|[]/\\&/g')

        GIMP_SCRIPTFU=$(echo "${GIMP_SCRIPTFU}" | sed 's|'"${VARIABLE_NAME}"'|'"${VARIABLE_VALUE}"'|g')
    done

    execute-scriptfu "${GIMP_SCRIPTFU}"
}

function xcf-to-png {
    local INPUT_IMAGE_PATH="${1}"
    local OUTPUT_IMAGE_PATH="${2}"

    echo -e "\e[36mConverting XCF to PNG for '${INPUT_IMAGE_PATH}'...\e[0m"

    execute-scriptfu-file "xcf-to-png" \
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

    execute-scriptfu-file "png-to-dds" \
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

    execute-scriptfu-file "svg-to-png" \
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

    execute-scriptfu-file "gradient-bevel" IMAGE_PATH "${IMAGE_PATH}"
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

        svg-to-png "${FLAG_SVG_BUILD_FILE_PATH}" "${FLAG_BUILD_MAIN_FILE_PATH}" 128
        apply-gradient-bevel "${FLAG_BUILD_MAIN_FILE_PATH}"
        png-to-dds "${FLAG_BUILD_MAIN_FILE_PATH}" "${FLAG_OUTPUT_MAIN_FILE_PATH}"

        svg-to-png "${FLAG_SVG_BUILD_FILE_PATH}" "${FLAG_BUILD_MAP_FILE_PATH}" 256
        png-to-dds "${FLAG_BUILD_MAP_FILE_PATH}" "${FLAG_OUTPUT_MAP_FILE_PATH}"

        svg-to-png "${FLAG_SVG_BUILD_FILE_PATH}" "${FLAG_BUILD_SMALL_FILE_PATH}" 24
        apply-gradient-bevel "${FLAG_BUILD_SMALL_FILE_PATH}"
        png-to-dds "${FLAG_BUILD_SMALL_FILE_PATH}" "${FLAG_OUTPUT_SMALL_FILE_PATH}"
    done
done
