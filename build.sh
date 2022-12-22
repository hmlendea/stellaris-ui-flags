#!/bin/bash

MOD_ID="ui-flags"
MOD_NAME="Universum Infinitum - Flags"
STELLARIS_VERSION="3.4.*"

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

function call-gimp {
    local GIMP_BINARY="/usr/bin/gimp"

    [ ! -f "${GIMP_BINARY}" ] && GIMP_BINARY="/var/lib/flatpak/exports/bin/org.gimp.GIMP"
    [ ! -f "${GIMP_BINARY}" ] && GIMP_BINARY="${HOME}/.local/share/flatpak/exports/bin/org.gimp.GIMP"
    if [ ! -f "${GIMP_BINARY}" ]; then
        echo "[ERROR] GIMP is not installed on this system"
        exit 1
    fi

    "${GIMP_BINARY}" $@
}

function execute-scriptfu {
    local GIMP_SCRIPTFU="${1}"
    call-gimp -i -b ''"$GIMP_SCRIPTFU"'' -b '(gimp-quit 0)'
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

        echo "var ${VARIABLE_NAME} = ${VARIABLE_VALUE}"
        GIMP_SCRIPTFU=$(echo "${GIMP_SCRIPTFU}" | sed 's|'"${VARIABLE_NAME}"'|'"\"${VARIABLE_VALUE}\""'|g')
    done

    execute-scriptfu "${GIMP_SCRIPTFU}"
}

function xcf-to-png {
    INPUT_FILE_PATH="${1}"
    OUTPUT_FILE_PATH="${2}"

    echo -e "\e[36mConverting XCF to PNG for '${INPUT_FILE_PATH}'...\e[0m"

    execute-scriptfu-file "xcf-to-png" \
        INPUT_FILE_PATH "${INPUT_FILE_PATH}" \
        OUTPUT_FILE_PATH "${OUTPUT_FILE_PATH}"
}

function png-to-bmp {
    INPUT_FILE_PATH="${1}"
    OUTPUT_FILE_PATH="${2}"

    echo -e "\e[36mConverting PNG to BMP for '${INPUT_FILE_PATH}'...\e[0m"

    convert -background "#000" -flatten "${INPUT_FILE_PATH}" "${OUTPUT_FILE_PATH}"
}

function png-to-dds {
    INPUT_FILE_PATH="${1}"
    OUTPUT_FILE_PATH="${2}"

    echo -e "\e[36mConverting PNG to DDS for '${INPUT_FILE_PATH}'...\e[0m"

    execute-scriptfu-file "png-to-dds" \
        INPUT_FILE_PATH "${INPUT_FILE_PATH}" \
        OUTPUT_FILE_PATH "${OUTPUT_FILE_PATH}"
}

function bmp-to-svg {
    INPUT_FILE_PATH="${1}"
    OUTPUT_FILE_PATH="${2}"

    echo -e "\e[36mConverting BMP to SVG for '${INPUT_FILE_PATH}'...\e[0m"

    potrace --opaque -s "${INPUT_FILE_PATH}" -o "${OUTPUT_FILE_PATH}"
}

function ai-to-svg {
    INPUT_FILE_PATH="${1}"
    OUTPUT_FILE_PATH="${2}"

    echo -e "\e[36mConverting AI to SVG for '${INPUT_FILE_PATH}'...\e[0m"

    inkscape -f "${INPUT_FILE_PATH}" -l "${OUTPUT_FILE_PATH}"
}

function svg-to-png {
    FILE_IN="${1}"
    FILE_OUT="${2}"
    SIZE="${3}"

    echo -e "\e[36mConverting SVG to PNG for '$FILE_IN'...\e[0m"
    GIMP_SCRIPTFU="
(let* (
      (imageInPath \""${FILE_IN}"\")
      (imageOutPath \""${FILE_OUT}"\")
      (image (car (file-svg-load RUN-NONINTERACTIVE imageInPath imageInPath 96.0 "$SIZE" "$SIZE" 0)))
      (width (car (gimp-image-width image)))
      (height (car (gimp-image-height image)))
      (drawable (car (gimp-image-get-active-drawable image)))
      (background-layer (car (gimp-layer-new image width height RGBA-IMAGE \"BG-Colour\" 100 NORMAL-MODE)))
      (has-black TRUE)
      (bg-colour '(255 255 255))
      )

    (gimp-context-push)
    (gimp-context-set-defaults)

    (script-fu-util-image-add-layers image background-layer)

    (gimp-context-set-background '(255 255 255))
    (gimp-edit-fill background-layer BACKGROUND-FILL)

    (if (= has-black FALSE)
        (begin
            (gimp-layer-set-lock-alpha drawable TRUE)
            (gimp-selection-all image)
            (gimp-context-set-background '(0 0 0))
            (gimp-edit-fill drawable BACKGROUND-FILL)
            (gimp-selection-none image)
            (gimp-layer-set-lock-alpha drawable FALSE)
        )
    )

    (gimp-image-merge-visible-layers image EXPAND-AS-NECESSARY)
    (set! drawable (car (gimp-image-get-active-drawable image)))

    (set! bg-colour (car (gimp-image-pick-color image drawable 3 0 FALSE FALSE 0.0)))
    (plug-in-colortoalpha RUN-NONINTERACTIVE image drawable bg-colour)

    (gimp-layer-set-lock-alpha drawable TRUE)
    (gimp-selection-all image)
    (gimp-context-set-background '(255 255 255))
    (gimp-edit-fill drawable BACKGROUND-FILL)
    (gimp-selection-none image)
    (gimp-layer-set-lock-alpha drawable FALSE)

    ; Save
    (gimp-image-merge-visible-layers image EXPAND-AS-NECESSARY)
    (file-png-save RUN-NONINTERACTIVE image (car (gimp-image-get-active-drawable image))
                   imageOutPath imageOutPath
                   FALSE 0 FALSE FALSE FALSE FALSE FALSE)

    (gimp-context-pop)
)
"

    execute-scriptfu "${GIMP_SCRIPTFU}"
}

function apply-gradient-bevel {
    FILE="${1}"

    echo -e "\e[36mApplying gradient bevel on '$FILE'...\e[0m"
    GIMP_SCRIPTFU="
; Script based on gradient-bevel-logo.scm included with GIMP <2.10, by Brian McFee
(let* (
      (imageInPath \""${FILE}"\")
      (imageOutPath \""${FILE}"\")
      (image (car (file-png-load RUN-NONINTERACTIVE imageInPath imageInPath)))
      (logo-layer (car (gimp-image-get-active-drawable image)))
      (width (car (gimp-image-width image)))
      (height (car (gimp-image-height image)))
      (bevel-size 22)
      (bevel-width 2.5)
      (bevel-height 40)
      (indentX (+ bevel-size 12))
      (indentY (+ bevel-size (/ height 8)))
      (blur-layer (car (gimp-layer-new image width height RGBA-IMAGE \"Blur\" 100 NORMAL-MODE)))
      (colour-layer (car (gimp-layer-new image width height RGBA-IMAGE \"Colour\" 100 LAYER-MODE-GRAIN-MERGE-LEGACY)))
      )

    (gimp-context-push)
    (gimp-context-set-defaults)

    (script-fu-util-image-add-layers image blur-layer)

    (gimp-layer-set-lock-alpha blur-layer TRUE)
    (gimp-context-set-background '(255 255 255))
    (gimp-selection-all image)
    (gimp-edit-fill blur-layer BACKGROUND-FILL)
    (gimp-edit-clear blur-layer)
    (gimp-selection-none image)
    (gimp-layer-set-lock-alpha blur-layer FALSE)
    (gimp-image-select-item image CHANNEL-OP-REPLACE logo-layer)
    (gimp-edit-fill blur-layer BACKGROUND-FILL)
    (plug-in-gauss-rle RUN-NONINTERACTIVE image blur-layer bevel-width 1 1)
    (gimp-selection-none image)
    (gimp-context-set-background '(127 127 127))
    (gimp-context-set-foreground '(255 255 255))
    (gimp-layer-set-lock-alpha logo-layer TRUE)
    (gimp-selection-all image)

    (gimp-edit-blend logo-layer FG-BG-RGB-MODE NORMAL-MODE
                     GRADIENT-RADIAL 95 0 REPEAT-NONE FALSE
                     FALSE 0 0 TRUE
                     indentX indentY indentX (- height indentY))

    (gimp-selection-none image)
    (gimp-layer-set-lock-alpha logo-layer FALSE)
    (plug-in-bump-map RUN-NONINTERACTIVE image logo-layer blur-layer 115 bevel-height 5 0 0 0 0.15 TRUE FALSE 0)
    (gimp-layer-set-offsets blur-layer 5 5)
    (gimp-invert blur-layer)
    (gimp-layer-set-opacity blur-layer 50.0)
    (gimp-image-set-active-layer image logo-layer)

    (gimp-context-pop)

    (gimp-image-remove-layer image blur-layer)

    ; Colour layer
    (script-fu-util-image-add-layers image colour-layer)
    (gimp-image-raise-item image colour-layer)
    (gimp-context-set-foreground '(178 164 136))
    (gimp-context-set-background '(113 82 9))
    (gimp-edit-blend colour-layer FG-BG-RGB-MODE NORMAL-MODE
                     GRADIENT-RADIAL 100 0 REPEAT-NONE FALSE
                     FALSE 0 0 TRUE
                     (/ width 3) 0 width height)

    ; Save
    (gimp-image-merge-visible-layers image EXPAND-AS-NECESSARY)
    (file-png-save RUN-NONINTERACTIVE image (car (gimp-image-get-active-drawable image))
                   imageOutPath imageOutPath
                   FALSE 0 FALSE FALSE FALSE FALSE FALSE)
)"

    execute-scriptfu "${GIMP_SCRIPTFU}"
}

function get-flag-file-name {
    SOURCE_FILE_NAME="$1"
    FILE_PREFIX="ui_"
    FLAG_FILE_NAME=$(grep "^${SOURCE_FILE_NAME}=" "${FLAG_NAMES_FILE_PATH}" | awk -F= '{print $2}')

    if [ -z "${FLAG_FILE_NAME}" ]; then
        echo "${FILE_PREFIX}${SOURCE_FILE_NAME}"
    else
        echo "${FLAG_FILE_NAME}"
    fi
}

function generate-mod-descriptor {
    FILE_PATH="${1}"

    echo "name=\"${MOD_NAME}\"" > "${FILE_PATH}"
    echo "path=\"mod/${MOD_ID}\"" >> "${FILE_PATH}"
    echo "tags={" >> "${FILE_PATH}"
    echo "  \"Graphics\"" >> "${FILE_PATH}"
    echo "}" >> "${FILE_PATH}"
    echo "supported_version=\"${STELLARIS_VERSION}\"" >> "${FILE_PATH}"
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

        FLAG_BUILD_MAIN_FILE_PATH="${FLAG_BMP_BUILD_FILE_PATH}"
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
            xcf-to-png "${FILE}" "${FLAG_PNG_BUILD_FILE_PATH}"
            png-to-bmp "${FLAG_PNG_BUILD_FILE_PATH}" "${FLAG_BMP_BUILD_FILE_PATH}"
            bmp-to-svg "${FLAG_BMP_BUILD_FILE_PATH}" "${FLAG_SVG_BUILD_FILE_PATH}"
        elif [ "${FILE_EXTENSION}" == "png" ]; then
            png-to-bmp "${FILE}" "${FLAG_BMP_BUILD_FILE_PATH}"
            bmp-to-svg "${FLAG_BMP_BUILD_FILE_PATH}" "${FLAG_SVG_BUILD_FILE_PATH}"
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
