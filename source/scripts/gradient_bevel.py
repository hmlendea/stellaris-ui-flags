"""Application of the gradient bevel effect to a PNG flag.

The effect reproduces the GIMP 2.10 Script-fu algorithm: a blurred white silhouette of the flag is
used as the height map of a bump map applied to the flag, then the flag is tinted with a radial
gold gradient.
"""

from gi.repository import Gimp

from gimp_image_operations import (add_layer, apply_gaussian_blur, apply_legacy_bump_map,
                                   clear_layer, clip_to_layer_alpha, duplicate_layer,
                                   export_png, invert_layer, load_image,
                                   merge_visible_layers, paint_shape_onto_layer,
                                   remove_image, remove_layer, select_all, select_none,
                                   select_shape, select_gradient_foreground_to_background,
                                   set_alpha_lock, set_background_colour,
                                   set_foreground_colour, set_layer_offsets,
                                   set_layer_opacity)
from gimp_script_arguments import read_argument

IMAGE_PATH_ARGUMENT = 'IMAGE_PATH'

BLUR_LAYER_NAME = 'Blur'
COLOUR_LAYER_NAME = 'Colour'
WHITE_COLOUR = 'white'
FLAG_GRADIENT_START = 'white'
FLAG_GRADIENT_END = '#7f7f7f'
COLOUR_GRADIENT_START = '#b2a488'
COLOUR_GRADIENT_END = '#715209'
BLUR_RADIUS = 2.5
BUMP_AZIMUTH = 115.0
BUMP_ELEVATION = 40.0
BUMP_DEPTH = 5
BUMP_AMBIENT = 0.15
GRADIENT_OFFSET = 0.0
USE_GRADIENT_DITHER = True
BLUR_LAYER_OPACITY = 50.0
BEVEL_SIZE = 22
BEVEL_INDENT_OFFSET = 12
BLUR_OFFSET_ADJUSTMENT = 5


def apply_gradient_bevel(image_path):
    """Apply the gradient bevel and the radial colour gradient to the flag at the path."""
    image = load_image(image_path)
    height = image.get_height()
    flag_layer = image.get_layers()[0]
    silhouette_layer = duplicate_layer(image, flag_layer)

    blur_layer = add_layer(image, BLUR_LAYER_NAME, Gimp.LayerMode.NORMAL)
    paint_height_map(image, silhouette_layer, blur_layer)
    apply_flag_gradient(image, flag_layer, height)

    # The legacy bump map also colours the pixels outside the silhouette, so the flag is left
    # unclipped afterwards; clipping would erase that relief and thin the emblem edges.
    apply_bump_map(flag_layer, blur_layer)
    remove_layer(image, silhouette_layer)

    # The blurred silhouette is offset, inverted and dimmed, then removed, as in the original script.
    set_layer_offsets(blur_layer, BLUR_OFFSET_ADJUSTMENT, BLUR_OFFSET_ADJUSTMENT)
    invert_layer(blur_layer)
    set_layer_opacity(blur_layer, BLUR_LAYER_OPACITY)
    remove_layer(image, blur_layer)

    apply_colour_gradient(image, flag_layer)

    merge_visible_layers(image)
    export_png(image, image_path)
    remove_image(image)


def paint_height_map(image, silhouette_layer, blur_map_layer):
    """Paint a blurred white silhouette of the flag onto the height map layer.

    The blur runs inside the silhouette selection, as the legacy script does. Without the
    selection the blur widens the height map beyond the silhouette and the relief is flattened.
    """
    clear_layer(blur_map_layer)
    paint_shape_onto_layer(image, silhouette_layer, blur_map_layer, WHITE_COLOUR)
    select_shape(image, silhouette_layer)
    apply_gaussian_blur(blur_map_layer, BLUR_RADIUS)
    select_none(image)


def apply_flag_gradient(image, flag_layer, height):
    """Apply the white-to-grey radial gradient across the flag."""
    indent_x = BEVEL_INDENT_OFFSET + BEVEL_SIZE
    indent_y = BEVEL_SIZE + int(height / 8)

    set_foreground_colour(FLAG_GRADIENT_START)
    set_background_colour(FLAG_GRADIENT_END)
    select_gradient_foreground_to_background()
    set_alpha_lock(flag_layer, True)
    select_all(image)
    flag_layer.edit_gradient_fill(
        Gimp.GradientType.RADIAL, GRADIENT_OFFSET, False, 0, 0.0, USE_GRADIENT_DITHER,
        float(indent_x), float(indent_y), float(indent_x), float(height - indent_y))
    select_none(image)
    set_alpha_lock(flag_layer, False)


def apply_bump_map(flag_layer, blur_layer):
    """Bump map the flag using the blurred silhouette as the height map."""
    apply_legacy_bump_map(flag_layer, blur_layer, {
        'type': 'linear',
        'azimuth': BUMP_AZIMUTH,
        'elevation': BUMP_ELEVATION,
        'depth': BUMP_DEPTH,
        'offset-x': 0,
        'offset-y': 0,
        'waterlevel': 0.0,
        'ambient': BUMP_AMBIENT,
        'compensate': True,
        'invert': False,
    })


def apply_colour_gradient(image, flag_layer):
    """Overlay the radial gold gradient, clipped to the flag shape."""
    width = image.get_width()
    height = image.get_height()

    colour_layer = add_layer(image, COLOUR_LAYER_NAME, Gimp.LayerMode.GRAIN_MERGE_LEGACY)
    set_foreground_colour(COLOUR_GRADIENT_START)
    set_background_colour(COLOUR_GRADIENT_END)
    select_gradient_foreground_to_background()
    colour_layer.edit_gradient_fill(
        Gimp.GradientType.RADIAL, GRADIENT_OFFSET, False, 0, 0.0, USE_GRADIENT_DITHER,
        float(width // 3), 0.0, float(width), float(height))

    clip_to_layer_alpha(image, colour_layer, flag_layer)


def main():
    image_path = read_argument(IMAGE_PATH_ARGUMENT)

    apply_gradient_bevel(image_path)


if __name__ == '__main__':
    main()
