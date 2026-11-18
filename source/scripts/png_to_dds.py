"""Export of a PNG image to an uncompressed DDS texture."""

from gimp_image_operations import export_dds, load_image, remove_image
from gimp_script_arguments import read_argument

SOURCE_PATH_ARGUMENT = 'INPUT_IMAGE_PATH'
OUTPUT_PATH_ARGUMENT = 'OUTPUT_IMAGE_PATH'


def convert_image(source_path, output_path):
    """Convert the PNG stored at the source path into a DDS file."""
    image = load_image(source_path)

    export_dds(image, output_path)
    remove_image(image)


def main():
    source_path = read_argument(SOURCE_PATH_ARGUMENT)
    output_path = read_argument(OUTPUT_PATH_ARGUMENT)

    convert_image(source_path, output_path)


if __name__ == '__main__':
    main()
