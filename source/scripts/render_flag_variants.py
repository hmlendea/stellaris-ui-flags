"""Rendering of every flag variant in a single GIMP session.

The DDS export is deliberately left to the build, which writes the uncompressed format directly and
therefore does not need GIMP for it.
"""

import os

import gradient_bevel
import svg_to_png
from gimp_script_arguments import read_argument, read_integer_argument

SOURCE_PATH_ARGUMENT = 'SOURCE_PATH'
MAIN_PNG_PATH_ARGUMENT = 'MAIN_PNG_PATH'
MAP_PNG_PATH_ARGUMENT = 'MAP_PNG_PATH'
SMALL_PNG_PATH_ARGUMENT = 'SMALL_PNG_PATH'
MAIN_SIZE_ARGUMENT = 'MAIN_SIZE'
MAP_SIZE_ARGUMENT = 'MAP_SIZE'
SMALL_SIZE_ARGUMENT = 'SMALL_SIZE'

TEMPORARY_SUFFIX = '.partial'


def render_variants(source_path, main_png_path, map_png_path, small_png_path, main_size,
                    map_size, small_size):
    """Render the beveled main and small PNGs and the flat map PNG.

    Each PNG is produced under a temporary name and renamed only once it is complete. A session that
    dies partway therefore leaves no half-processed PNG behind, which the build could mistake for a
    finished one.
    """
    render_beveled_variant(source_path, main_png_path, main_size)
    render_flat_variant(source_path, map_png_path, map_size)
    render_beveled_variant(source_path, small_png_path, small_size)


def render_beveled_variant(source_path, png_path, size):
    """Render the source at the supplied size, apply the bevel, then publish the PNG."""
    partial_path = png_path + TEMPORARY_SUFFIX
    svg_to_png.render_flag(source_path, partial_path, size)
    gradient_bevel.apply_gradient_bevel(partial_path)
    os.replace(partial_path, png_path)


def render_flat_variant(source_path, png_path, size):
    """Render the source at the supplied size and publish the PNG without a bevel."""
    partial_path = png_path + TEMPORARY_SUFFIX
    svg_to_png.render_flag(source_path, partial_path, size)
    os.replace(partial_path, png_path)


def main():
    render_variants(
        source_path=read_argument(SOURCE_PATH_ARGUMENT),
        main_png_path=read_argument(MAIN_PNG_PATH_ARGUMENT),
        map_png_path=read_argument(MAP_PNG_PATH_ARGUMENT),
        small_png_path=read_argument(SMALL_PNG_PATH_ARGUMENT),
        main_size=read_integer_argument(MAIN_SIZE_ARGUMENT),
        map_size=read_integer_argument(MAP_SIZE_ARGUMENT),
        small_size=read_integer_argument(SMALL_SIZE_ARGUMENT),
    )


if __name__ == '__main__':
    main()