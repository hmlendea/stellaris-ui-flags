"""Application of the gradient bevel to a batch of PNG flags in one GIMP session.

Starting GIMP costs a few seconds, while every further image inside a running session costs a
fraction of one, so the whole batch is processed in a single session. The session is kept bounded
by the caller, because the memory a session holds grows with the number of images it has handled.
"""

import sys

from gimp_script_arguments import read_argument

from gradient_bevel import COMPLETION_MARKER_SUFFIX, apply_gradient_bevel

IMAGE_PATHS_ARGUMENT = 'IMAGE_PATHS'


def read_image_paths():
    """Return the non-empty, whitespace-trimmed image paths supplied as a newline-separated list."""
    image_paths = []

    for image_path in read_argument(IMAGE_PATHS_ARGUMENT).splitlines():
        image_path = image_path.strip()

        if image_path:
            image_paths.append(image_path)

    return image_paths


def bevel_images(image_paths):
    """Apply the gradient bevel to every image, continuing when one of them fails."""
    failed_image_paths = []

    for image_path in image_paths:
        # The progress line is written before the bevel starts, so a session that is killed partway
        # still leaves behind which flag it was working on. The build reads these lines to explain
        # which flags ended up unbeveled and why. It is flushed explicitly, because a killed session
        # never flushes its buffered output and the line would otherwise be lost with it.
        print(f"[INFO] Beveling '{image_path}'", flush=True)

        try:
            apply_gradient_bevel(image_path)

            # The marker is written only after the bevel has been saved, so a session that dies
            # partway or is killed is never mistaken for a completed bevel.
            open(image_path + COMPLETION_MARKER_SUFFIX, 'w', encoding='utf-8').close()
        except Exception as exception:
            failed_image_paths.append(image_path)
            print(f"[WARNING] Failure while beveling '{image_path}': {exception}", file=sys.stderr)

    return failed_image_paths


def main():
    image_paths = read_image_paths()
    failed_image_paths = bevel_images(image_paths)

    for image_path in failed_image_paths:
        print(f"[ERROR] The flag '{image_path}' was not beveled!", file=sys.stderr)


if __name__ == '__main__':
    main()
