"""Export of a PNG image to an uncompressed DDS texture.

This writes the format that GIMP's `file-dds-export` produces with compression disabled: a 128-byte
header followed by raw BGRA pixels, no mipmaps. Writing it directly avoids starting GIMP, which
costs about three seconds per invocation and dominates the build.

ImageMagick emits the BGRA pixels in a single invocation, so the export costs one process start for
the dimensions and one for the pixels.
"""

import struct
import subprocess

from gimp_script_arguments import read_argument

SOURCE_PATH_ARGUMENT = 'INPUT_IMAGE_PATH'
OUTPUT_PATH_ARGUMENT = 'OUTPUT_IMAGE_PATH'

HEADER_SIZE = 128
DDS_FLAGS = 0x100f
DDS_PIXEL_FORMAT_FLAGS = 0x41
DDS_PIXEL_FORMAT_SIZE = 32
DDS_CAPS_TEXTURE = 0x1000
IMAGE_MAGICK_BINARY = 'magick'
BGRA_FORMAT_SPECIFIER = 'bgra:-'
BYTES_PER_PIXEL = 4


def build_header(width, height):
    """Build the 128-byte header that GIMP writes for an uncompressed texture."""
    header = bytearray(HEADER_SIZE)
    header[0:4] = b'DDS '
    struct.pack_into('<I', header, 4, HEADER_SIZE - 4)
    struct.pack_into('<I', header, 8, DDS_FLAGS)
    struct.pack_into('<I', header, 12, height)
    struct.pack_into('<I', header, 16, width)
    struct.pack_into('<I', header, 20, width * BYTES_PER_PIXEL)
    struct.pack_into('<I', header, 28, 1)

    # GIMP stamps its version into the reserved field; 3.2 wrote 0x0003095c.
    header[32:40] = b'GIMP-DDS'
    struct.pack_into('<I', header, 40, 0x0003095c)

    struct.pack_into('<I', header, 76, DDS_PIXEL_FORMAT_SIZE)
    struct.pack_into('<I', header, 80, DDS_PIXEL_FORMAT_FLAGS)
    struct.pack_into('<I', header, 88, DDS_PIXEL_FORMAT_SIZE)
    struct.pack_into('<I', header, 92, 0x00ff0000)
    struct.pack_into('<I', header, 96, 0x0000ff00)
    struct.pack_into('<I', header, 100, 0x000000ff)
    struct.pack_into('<I', header, 104, 0xff000000)
    struct.pack_into('<I', header, 108, DDS_CAPS_TEXTURE)

    return bytes(header)


def read_dimensions(source_path):
    """Return the width and height of the PNG at the supplied path."""
    result = subprocess.run(
        [IMAGE_MAGICK_BINARY, 'identify', '-format', '%w %h', source_path],
        capture_output=True, check=True, text=True)

    width, height = result.stdout.split()

    return int(width), int(height)


def read_bgra_data(source_path):
    """Return the raw BGRA bytes of the PNG at the supplied path."""
    return subprocess.run(
        [IMAGE_MAGICK_BINARY, source_path, '-depth', '8', BGRA_FORMAT_SPECIFIER],
        capture_output=True, check=True).stdout


def convert_image(source_path, output_path):
    """Convert the PNG stored at the source path into an uncompressed DDS file."""
    width, height = read_dimensions(source_path)
    pixels = read_bgra_data(source_path)

    with open(output_path, 'wb') as output_file:
        output_file.write(build_header(width, height))
        output_file.write(pixels)


def main():
    source_path = read_argument(SOURCE_PATH_ARGUMENT)
    output_path = read_argument(OUTPUT_PATH_ARGUMENT)

    convert_image(source_path, output_path)


if __name__ == '__main__':
    main()
