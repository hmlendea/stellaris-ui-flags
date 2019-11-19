#!/bin/bash

MOD_ID="ui-flags"
MOD_NAME="Universum Infinitum - Flags"
STELLARIS_VERSION="2.5.*"

SOURCE_DIR_PATH="$(pwd)/source"
SOURCE_FLAGS_DIR_PATH="${SOURCE_DIR_PATH}/flags"
SOURCE_BACKGROUNDS_DIR_PATH="${SOURCE_DIR_PATH}/backgrounds"
SOURCE_LOCALISATION_FILE_PATH="${SOURCE_DIR_PATH}/localisation.yml"

BUILD_DIR_PATH="$(pwd)/build"
OUTPUT_DIR_PATH="$(pwd)/out"

OUTPUT_MOD_DIR_PATH="${OUTPUT_DIR_PATH}/${MOD_ID}"
OUTPUT_FLAGS_DIR_PATH="${OUTPUT_MOD_DIR_PATH}/flags"
OUTPUT_BACKGROUNDS_DIR_PATH="${OUTPUT_FLAGS_DIR_PATH}/backgrounds"
OUTPUT_LOCALISATIONS_DIR_PATH="${OUTPUT_MOD_DIR_PATH}/localisation"
OUTPUT_LOCALISATION_FILE_PATH="${OUTPUT_LOCALISATIONS_DIR_PATH}/ui-flags_l_english.yml"

MOD_DESCRIPTOR_PRIMARY_FILE_PATH="${OUTPUT_DIR_PATH}/${MOD_ID}.mod"
MOD_DESCRIPTOR_SECONDARY_FILE_PATH="${OUTPUT_MOD_DIR_PATH}/descriptor.mod"

FLAG_NAMES_FILE_PATH="${SOURCE_DIR_PATH}/names.txt"
LOGO_FILE_PATH="${SOURCE_DIR_PATH}/logo.jpg"

[ ! -d ${SOURCE_DIR_PATH} ] && echo "MISSING SOURCE DIRECTORY" && exit -1

function execute-scriptfu {
    GIMP_SCRIPTFU="$1"

    gimp -i -b ''"$GIMP_SCRIPTFU"'' -b '(gimp-quit 0)'
}

function xcf-to-png {
    FILE_IN="$1"
    FILE_OUT="$2"
    SIZE=$3

    echo -e "\e[36mConverting XCF to PNG for '$FILE_IN'...\e[0m"
    GIMP_SCRIPTFU="
(let* (
      (imageInPath \""$FILE_IN"\")
      (imageOutPath \""$FILE_OUT"\")
      (image (car (gimp-file-load RUN-NONINTERACTIVE imageInPath imageInPath)))
      (drawable (car (gimp-image-merge-visible-layers image CLIP-TO-IMAGE)))
      )

    ; Save
    (file-png-save RUN-NONINTERACTIVE image (car (gimp-image-get-active-drawable image))
                   imageOutPath imageOutPath
                   FALSE 0 FALSE FALSE FALSE FALSE FALSE)

    (gimp-context-pop)
)
"

    gimp -i -b ''"$GIMP_SCRIPTFU"'' -b '(gimp-quit 0)'
}

function png-to-bmp {
    FILE_IN="$1"
    FILE_OUT="$2"

    echo -e "\e[36mConverting PNG to BMP for '$FILE_IN'...\e[0m"

    convert -background "#000" -flatten "${FILE_IN}" "${FILE_OUT}"
}

function png-to-dds {
    FILE_IN="$1"
    FILE_OUT="$2"

    echo -e "\e[36mConverting PNG to DDS for '$FILE_IN'...\e[0m"
    GIMP_SCRIPTFU="
(let* (
      (imageInPath \""$FILE_IN"\")
      (imageOutPath \""$FILE_OUT"\")
      (image (car (file-png-load RUN-NONINTERACTIVE imageInPath imageInPath)))
      (drawable (car (gimp-image-get-active-drawable image)))
      )

    (gimp-context-push)
    (gimp-context-set-defaults)

    ; Save
    (file-dds-save RUN-NONINTERACTIVE image drawable
                   imageOutPath imageOutPath
                   0 1 0 0 0 0 0 0 0 1.0 0 0 0.5)

    (gimp-context-pop)
)
"

    gimp -i -b ''"$GIMP_SCRIPTFU"'' -b '(gimp-quit 0)'
}

function bmp-to-svg {
    FILE_IN="$1"
    FILE_OUT="$2"

    echo -e "\e[36mConverting BMP to SVG for '$FILE_IN'...\e[0m"
    
    potrace --opaque -s "${FILE_IN}" -o "${FILE_OUT}"
}

function ai-to-svg {
    FILE_IN="$1"
    FILE_OUT="$2"

    echo -e "\e[36mConverting AI to SVG for '$FILE_IN'...\e[0m"
    
    inkscape -f "${FILE_IN}" -l "${FILE_OUT}"
}

function svg-to-png {
    FILE_IN="$1"
    FILE_OUT="$2"
    SIZE=$3

    echo -e "\e[36mConverting SVG to PNG for '$FILE_IN'...\e[0m"
    GIMP_SCRIPTFU="
(let* (
      (imageInPath \""$FILE_IN"\")
      (imageOutPath \""$FILE_OUT"\")
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
    
    (set! bg-colour (car (gimp-image-pick-color image drawable 1 1 FALSE FALSE 0.0)))
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

    gimp -i -b ''"$GIMP_SCRIPTFU"'' -b '(gimp-quit 0)'
}

function apply-gradient-bevel {
    FILE="$1"

    echo -e "\e[36mApplying gradient bevel on '$FILE'...\e[0m"
    GIMP_SCRIPTFU="
; Script based on gradient-bevel-logo.scm included with GIMP <2.10, by Brian McFee
(let* (
      (imageInPath \""$FILE"\")
      (imageOutPath \""$FILE"\")
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

    gimp -i -b ''"$GIMP_SCRIPTFU"'' -b '(gimp-quit 0)'
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
    FILE_PATH=$1

    echo "name=\"${MOD_NAME}\"" > ${FILE_PATH}
    echo "path=\"mod/${MOD_ID}\"" >> ${FILE_PATH}
    echo "tags={" >> ${FILE_PATH}
    echo "  \"Graphics\"" >> ${FILE_PATH}
    echo "}" >> ${FILE_PATH}
    echo "picture=\"logo.jpg\"" >> ${FILE_PATH}
    echo "supported_version=\"${STELLARIS_VERSION}\"" >> ${FILE_PATH}
}

mkdir -p "${OUTPUT_BACKGROUNDS_DIR_PATH}"
mkdir -p "${OUTPUT_LOCALISATIONS_DIR_PATH}"

cp ${SOURCE_BACKGROUNDS_DIR_PATH}/* ${OUTPUT_BACKGROUNDS_DIR_PATH}
cp ${SOURCE_LOCALISATION_FILE_PATH} ${OUTPUT_LOCALISATION_FILE_PATH}
cp ${LOGO_FILE_PATH} ${OUTPUT_MOD_DIR_PATH}

generate-mod-descriptor ${MOD_DESCRIPTOR_PRIMARY_FILE_PATH}
generate-mod-descriptor ${MOD_DESCRIPTOR_SECONDARY_FILE_PATH}

for CATEGORY_DIR in ${SOURCE_FLAGS_DIR_PATH}/*; do
    [ -z "${CATEGORY_DIR}" ] && continue
    [ -z "$(ls -A ${CATEGORY_DIR})" ] && continue 
    [ ! -d ${CATEGORY_DIR} ] && continue

    CATEGORY_NAME=$(basename ${CATEGORY_DIR})
    
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

    for FILE in ${CATEGORY_DIR}/* ; do
        FILE_BASENAME=$(basename ${FILE})

        [ "${FILE_BASENAME}" == "usage.txt" ] && continue

        FILE_NAME="${FILE_BASENAME%.*}"
        FILE_EXTENSION=$(echo "${FILE_BASENAME}" | cut -d'.' -f2)

        FLAG_FILE_NAME=$(get-flag-file-name ${FILE_NAME})

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

        svg-to-png ${FLAG_SVG_BUILD_FILE_PATH} ${FLAG_BUILD_MAIN_FILE_PATH} 128
        apply-gradient-bevel ${FLAG_BUILD_MAIN_FILE_PATH}
        png-to-dds ${FLAG_BUILD_MAIN_FILE_PATH} ${FLAG_OUTPUT_MAIN_FILE_PATH}

        svg-to-png ${FLAG_SVG_BUILD_FILE_PATH} ${FLAG_BUILD_MAP_FILE_PATH} 256
        png-to-dds ${FLAG_BUILD_MAP_FILE_PATH} ${FLAG_OUTPUT_MAP_FILE_PATH}

        svg-to-png ${FLAG_SVG_BUILD_FILE_PATH} ${FLAG_BUILD_SMALL_FILE_PATH} 24
        apply-gradient-bevel ${FLAG_BUILD_SMALL_FILE_PATH}
        png-to-dds ${FLAG_BUILD_SMALL_FILE_PATH} ${FLAG_OUTPUT_SMALL_FILE_PATH}
    done
done
