"""Rendering of every flag variant in a single GIMP session."""

import gradient_bevel
import png_to_dds
import svg_to_png
from gimp_script_arguments import read_argument, read_integer_argument

SOURCE_PATH_ARGUMENT = 'SOURCE_PATH'
MAIN_PNG_PATH_ARGUMENT = 'MAIN_PNG_PATH'
MAIN_DDS_PATH_ARGUMENT = 'MAIN_DDS_PATH'
MAP_PNG_PATH_ARGUMENT = 'MAP_PNG_PATH'
MAP_DDS_PATH_ARGUMENT = 'MAP_DDS_PATH'
SMALL_PNG_PATH_ARGUMENT = 'SMALL_PNG_PATH'
SMALL_DDS_PATH_ARGUMENT = 'SMALL_DDS_PATH'
MAIN_SIZE_ARGUMENT = 'MAIN_SIZE'
MAP_SIZE_ARGUMENT = 'MAP_SIZE'
SMALL_SIZE_ARGUMENT = 'SMALL_SIZE'


def render_variants(source_path, main_png_path, main_dds_path, map_png_path,
                    map_dds_path, small_png_path, small_dds_path, main_size,
                    map_size, small_size):
    """Render the beveled main and small variants and the flat map variant."""
    render_beveled_variant(source_path, main_png_path, main_dds_path, main_size)
    render_flat_variant(source_path, map_png_path, map_dds_path, map_size)
    render_beveled_variant(source_path, small_png_path, small_dds_path, small_size)


def render_beveled_variant(source_path, png_path, dds_path, size):
    """Render the source at the supplied size, then bevel and export it."""
    svg_to_png.render_flag(source_path, png_path, size)
    gradient_bevel.apply_gradient_bevel(png_path)
    png_to_dds.convert_image(png_path, dds_path)


def render_flat_variant(source_path, png_path, dds_path, size):
    """Render the source at the supplied size and export it without a bevel."""
    svg_to_png.render_flag(source_path, png_path, size)
    png_to_dds.convert_image(png_path, dds_path)


def main():
    render_variants(
        source_path=read_argument(SOURCE_PATH_ARGUMENT),
        main_png_path=read_argument(MAIN_PNG_PATH_ARGUMENT),
        main_dds_path=read_argument(MAIN_DDS_PATH_ARGUMENT),
        map_png_path=read_argument(MAP_PNG_PATH_ARGUMENT),
        map_dds_path=read_argument(MAP_DDS_PATH_ARGUMENT),
        small_png_path=read_argument(SMALL_PNG_PATH_ARGUMENT),
        small_dds_path=read_argument(SMALL_DDS_PATH_ARGUMENT),
        main_size=read_integer_argument(MAIN_SIZE_ARGUMENT),
        map_size=read_integer_argument(MAP_SIZE_ARGUMENT),
        small_size=read_integer_argument(SMALL_SIZE_ARGUMENT),
    )


if __name__ == '__main__':
    main()