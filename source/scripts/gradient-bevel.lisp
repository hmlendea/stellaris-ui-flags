; Script based on gradient-bevel-logo.scm included with GIMP <2.10, by Brian McFee
(let* (
      (imageInPath "IMAGE_PATH")
      (imageOutPath "IMAGE_PATH")
      (image (car (file-png-load RUN-NONINTERACTIVE imageInPath imageInPath)))
      (logo-layer (car (gimp-image-get-active-drawable image)))
      (width (car (gimp-image-width image)))
      (height (car (gimp-image-height image)))
      (bevel-size 22)
      (bevel-width 2.5)
      (bevel-height 40)
      (indentX (+ bevel-size 12))
      (indentY (+ bevel-size (/ height 8)))
      (blur-layer (car (gimp-layer-new image width height RGBA-IMAGE "Blur" 100 NORMAL-MODE)))
      (colour-layer (car (gimp-layer-new image width height RGBA-IMAGE "Colour" 100 LAYER-MODE-GRAIN-MERGE-LEGACY)))
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
)
