(let* (
      (imageInPath "INPUT_IMAGE_PATH")
      (imageOutPath "OUTPUT_IMAGE_PATH")
      (image (car (gimp-file-load RUN-NONINTERACTIVE imageInPath imageInPath)))
      (drawable (car (gimp-image-merge-visible-layers image CLIP-TO-IMAGE)))
      )

    ; Save
    (file-png-save RUN-NONINTERACTIVE image (car (gimp-image-get-active-drawable image))
                   imageOutPath imageOutPath
                   FALSE 0 FALSE FALSE FALSE FALSE FALSE)

    (gimp-context-pop)
)
