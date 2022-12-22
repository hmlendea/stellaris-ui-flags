(let* (
      (imageInPath INPUT_FILE_PATH)
      (imageOutPath OUTPUT_FILE_PATH)
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
