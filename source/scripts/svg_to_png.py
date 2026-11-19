"""Rendering of an SVG flag to a PNG image."""

from gimp_image_operations import (add_background_layer, export_png, fill_with_background,
                                   load_svg_image, merge_visible_layers, pick_colour,
                                   recolour_opaque_area, remove_colour, remove_image,
                                   set_background_colour)
from gimp_script_arguments import read_argument, read_integer_argument

SOURCE_PATH_ARGUMENT = 'INPUT_IMAGE_PATH'
OUTPUT_PATH_ARGUMENT = 'OUTPUT_IMAGE_PATH'
OUTPUT_SIZE_ARGUMENT = 'OUTPUT_IMAGE_SIZE'

WHITE_COLOUR = 'white'
BACKGROUND_LAYER_NAME = 'BG-Colour'
COLOUR_PICK_POSITION_X = 3.0
COLOUR_PICK_POSITION_Y = 0.0


def render_flag(source_path, output_path, output_size):
    """Render the SVG at the supplied size, removing its flat background colour.

    The white background layer is essential. SVGs that rely on a stroked path with no fill are
    transparent, so the background colour sampled at the top-left corner would otherwise be
    transparent itself, and removing it would erase the whole emblem.
    """
    image = load_svg_image(source_path, output_size)

    background_layer = add_background_layer(image, BACKGROUND_LAYER_NAME)
    set_background_colour(WHITE_COLOUR)
    fill_with_background(background_layer)

    flag_layer = merge_visible_layers(image)
    background_colour = pick_colour(image, flag_layer, COLOUR_PICK_POSITION_X,
                                    COLOUR_PICK_POSITION_Y)
    remove_colour(flag_layer, background_colour)
    recolour_opaque_area(image, flag_layer, WHITE_COLOUR)

    merge_visible_layers(image)
    export_png(image, output_path)
    remove_image(image)


def main():
    source_path = read_argument(SOURCE_PATH_ARGUMENT)
    output_path = read_argument(OUTPUT_PATH_ARGUMENT)
    output_size = read_integer_argument(OUTPUT_SIZE_ARGUMENT)

    render_flag(source_path, output_path, output_size)


if __name__ == '__main__':
    main()
