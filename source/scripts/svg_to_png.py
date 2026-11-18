"""Rendering of an SVG flag to a PNG image."""

from gimp_image_operations import (export_png, load_svg_image, merge_visible_layers,
                                   pick_colour, recolour_opaque_area, remove_colour,
                                   remove_image)
from gimp_script_arguments import read_argument, read_integer_argument

SOURCE_PATH_ARGUMENT = 'INPUT_IMAGE_PATH'
OUTPUT_PATH_ARGUMENT = 'OUTPUT_IMAGE_PATH'
OUTPUT_SIZE_ARGUMENT = 'OUTPUT_IMAGE_SIZE'

WHITE_COLOUR = 'white'
COLOUR_PICK_POSITION_X = 3.0
COLOUR_PICK_POSITION_Y = 0.0


def render_flag(source_path, output_path, output_size):
    """Render the SVG at the supplied size, removing its flat background colour."""
    image = load_svg_image(source_path, output_size)

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
