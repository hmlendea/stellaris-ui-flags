(let* (
      (imageInPath "INPUT_IMAGE_PATH")
      (imageOutPath "OUTPUT_IMAGE_PATH")
      (image (car (file-svg-load RUN-NONINTERACTIVE imageInPath imageInPath 96.0 OUTPUT_IMAGE_SIZE OUTPUT_IMAGE_SIZE 0)))
      (width (car (gimp-image-width image)))
      (height (car (gimp-image-height image)))
      (drawable (car (gimp-image-get-active-drawable image)))
      (background-layer (car (gimp-layer-new image width height RGBA-IMAGE "BG-Colour" 100 NORMAL-MODE)))
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
