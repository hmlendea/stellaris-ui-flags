"""Application of the gradient bevel effect to a PNG flag."""

from gi.repository import Gimp

from gimp_image_operations import (EMBOSS_OPERATION, GAUSSIAN_BLUR_OPERATION, add_layer,
                                   apply_filter, clear_outside_shape, export_png,
                                   fill_with_background, fill_with_radial_gradient,
                                   load_image, merge_visible_layers, paint_shape_onto_layer,
                                   remove_image, remove_layer, select_all, select_none,
                                   set_background_colour)
from gimp_script_arguments import read_argument

IMAGE_PATH_ARGUMENT = 'IMAGE_PATH'

RELIEF_LAYER_NAME = 'Relief'
COLOUR_LAYER_NAME = 'Colour'
BLACK_COLOUR = 'black'
WHITE_COLOUR = 'white'
COLOUR_GRADIENT_START = '#b2a488'
COLOUR_GRADIENT_END = '#715209'
BLUR_RADIUS = 2.5
BLUR_ABYSS_POLICY = 'clamp'
RELIEF_AZIMUTH = 115.0
RELIEF_ELEVATION = 40.0
RELIEF_DEPTH = 5
RELIEF_TYPE = 'emboss'


def apply_gradient_bevel(image_path):
    """Apply a radial colour gradient and a blurred relief to the flag at the path."""
    image = load_image(image_path)
    width = image.get_width()
    height = image.get_height()
    flag_layer = image.get_layers()[0]

    relief_layer = add_layer(image, RELIEF_LAYER_NAME, Gimp.LayerMode.NORMAL)
    paint_relief_shading(image, flag_layer, relief_layer)
    clear_outside_shape(image, flag_layer, relief_layer)

    colour_layer = add_layer(image, COLOUR_LAYER_NAME, Gimp.LayerMode.GRAIN_MERGE_LEGACY)
    fill_with_radial_gradient(colour_layer, width / 3.0, 0.0, float(width), float(height),
                              COLOUR_GRADIENT_START, COLOUR_GRADIENT_END)
    clear_outside_shape(image, flag_layer, colour_layer)

    remove_layer(image, flag_layer)
    merge_visible_layers(image)
    export_png(image, image_path)
    remove_image(image)


def paint_relief_shading(image, flag_layer, relief_layer):
    """Build a blurred silhouette of the flag and emboss it into a relief."""
    select_all(image)
    set_background_colour(BLACK_COLOUR)
    fill_with_background(relief_layer)
    select_none(image)

    paint_shape_onto_layer(image, flag_layer, relief_layer, WHITE_COLOUR)

    apply_filter(relief_layer, GAUSSIAN_BLUR_OPERATION, {
        'std-dev-x': BLUR_RADIUS,
        'std-dev-y': BLUR_RADIUS,
        'abyss-policy': BLUR_ABYSS_POLICY,
        'clip-extent': False,
    })
    apply_filter(relief_layer, EMBOSS_OPERATION, {
        'type': RELIEF_TYPE,
        'azimuth': RELIEF_AZIMUTH,
        'elevation': RELIEF_ELEVATION,
        'depth': RELIEF_DEPTH,
    })


def main():
    image_path = read_argument(IMAGE_PATH_ARGUMENT)

    apply_gradient_bevel(image_path)


if __name__ == '__main__':
    main()
