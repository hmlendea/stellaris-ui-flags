"""Reusable image, layer, selection, and filter operations for batch scripts."""

from gi.repository import Gegl
from gi.repository import Gimp
from gi.repository import Gio

from gimp_procedures import run_procedure

DEFAULT_LAYER_OPACITY = 100.0
DDS_COMPRESSION_FORMAT = 'none'
IMAGE_LOAD_PROCEDURE = 'gimp-file-load'
PNG_EXPORT_PROCEDURE = 'file-png-export'
DDS_EXPORT_PROCEDURE = 'file-dds-export'
SVG_LOAD_PROCEDURE = 'file-svg-load'
COLOUR_TO_ALPHA_OPERATION = 'gegl:color-to-alpha'
GAUSSIAN_BLUR_OPERATION = 'gegl:gaussian-blur'
BUMP_MAP_OPERATION = 'gegl:bump-map'


def load_image(source_path):
    """Load the image stored at the supplied path."""
    result = run_procedure(IMAGE_LOAD_PROCEDURE, {
        'run-mode': Gimp.RunMode.NONINTERACTIVE,
        'file': Gio.File.new_for_path(source_path),
    })

    return result.index(1)


def load_svg_image(source_path, size):
    """Load the SVG stored at the supplied path, rendered as a square."""
    result = run_procedure(SVG_LOAD_PROCEDURE, {
        'run-mode': Gimp.RunMode.NONINTERACTIVE,
        'file': Gio.File.new_for_path(source_path),
        'width': size,
        'height': size,
        'keep-ratio': False,
        'prefer-native-dimensions': False,
    })

    return result.index(1)


def export_png(image, output_path):
    """Write the image to the supplied path as a PNG file."""
    run_procedure(PNG_EXPORT_PROCEDURE, {
        'run-mode': Gimp.RunMode.NONINTERACTIVE,
        'image': image,
        'file': Gio.File.new_for_path(output_path),
    })


def export_dds(image, output_path):
    """Write the image to the supplied path as an uncompressed DDS file."""
    run_procedure(DDS_EXPORT_PROCEDURE, {
        'run-mode': Gimp.RunMode.NONINTERACTIVE,
        'image': image,
        'file': Gio.File.new_for_path(output_path),
        'compression-format': DDS_COMPRESSION_FORMAT,
    })


def add_layer(image, layer_name, layer_mode):
    """Create a transparent layer of the image size and insert it at the top."""
    layer = Gimp.Layer.new(image, layer_name, image.get_width(), image.get_height(),
                           Gimp.ImageType.RGBA_IMAGE, DEFAULT_LAYER_OPACITY, layer_mode)
    image.insert_layer(layer, None, 0)

    return layer


def add_background_layer(image, layer_name):
    """Create a transparent layer of the image size and insert it beneath the others."""
    layer = Gimp.Layer.new(image, layer_name, image.get_width(), image.get_height(),
                           Gimp.ImageType.RGBA_IMAGE, DEFAULT_LAYER_OPACITY,
                           Gimp.LayerMode.NORMAL)
    image.insert_layer(layer, None, len(image.get_layers()))

    return layer


def set_background_colour(hexadecimal_colour):
    """Set the context background colour from a hexadecimal value."""
    Gimp.context_set_background(Gegl.Color.new(hexadecimal_colour))


def set_foreground_colour(hexadecimal_colour):
    """Set the context foreground colour from a hexadecimal value."""
    Gimp.context_set_foreground(Gegl.Color.new(hexadecimal_colour))


def fill_with_background(layer):
    """Fill the layer using the current context background colour."""
    layer.edit_fill(Gimp.FillType.BACKGROUND)


def select_gradient_foreground_to_background():
    """Select the foreground-to-background gradient in the context."""
    Gimp.context_set_gradient_fg_bg_rgb()


def invert_layer(layer):
    """Invert the colours of the layer."""
    layer.invert(False)


def clear_layer(layer):
    """Erase the layer contents."""
    layer.edit_clear()


def select_all(image):
    """Select the entire image."""
    Gimp.Selection.all(image)


def select_none(image):
    """Clear the current selection."""
    Gimp.Selection.none(image)


def select_shape(image, shape_layer):
    """Replace the current selection with the opaque area of the shape layer."""
    return image.select_item(Gimp.ChannelOps.REPLACE, shape_layer)


def select_alpha(layer):
    """Select the opaque area of the layer."""
    layer.get_image().select_item(Gimp.ChannelOps.REPLACE, layer)


def invert_selection(image):
    """Invert the current selection."""
    Gimp.Selection.invert(image)


def set_alpha_lock(layer, is_locked):
    """Enable or disable the alpha lock of the layer."""
    layer.set_lock_alpha(is_locked)


def set_layer_opacity(layer, opacity):
    """Set the opacity of the layer as a percentage."""
    layer.set_opacity(opacity)


def set_layer_offsets(layer, offset_x, offset_y):
    """Move the layer by the supplied offsets."""
    layer.set_offsets(offset_x, offset_y)


def merge_visible_layers(image):
    """Merge every visible layer and return the resulting layer."""
    return image.merge_visible_layers(Gimp.MergeType.EXPAND_AS_NECESSARY)


def remove_image(image):
    """Delete the image and release its memory."""
    image.delete()


def remove_layer(image, layer):
    """Delete the layer from the image."""
    image.remove_layer(layer)


def duplicate_layer(image, layer):
    """Insert a copy of the layer at the top of the image and return it."""
    result = run_procedure('gimp-layer-copy', {'layer': layer})
    copy = result.index(1)
    image.insert_layer(copy, None, 0)

    return copy


def clip_to_layer_alpha(image, target_layer, alpha_reference_layer):
    """Erase everything on the target layer that lies outside the reference layer's opaque area."""
    select_alpha(alpha_reference_layer)
    invert_selection(image)
    clear_layer(target_layer)
    select_none(image)


def pick_colour(image, drawable, position_x, position_y):
    """Return the colour sampled from the drawable at the supplied position."""
    result = image.pick_color([drawable], position_x, position_y, False, False, 0.0)

    return result[1]


def recolour_opaque_area(image, layer, hexadecimal_colour):
    """Repaint the opaque area of the layer, leaving transparent pixels untouched."""
    set_alpha_lock(layer, True)
    select_all(image)
    set_background_colour(hexadecimal_colour)
    fill_with_background(layer)
    select_none(image)
    set_alpha_lock(layer, False)


def apply_gaussian_blur(layer, radius):
    """Apply a Gaussian blur of the supplied radius to the layer."""
    apply_filter(layer, GAUSSIAN_BLUR_OPERATION, {
        'std-dev-x': radius,
        'std-dev-y': radius,
        'abyss-policy': 'clamp',
        'clip-extent': False,
    })


def apply_legacy_bump_map(drawable, height_map_drawable, properties):
    """Apply bump mapping to the drawable using the height map as its auxiliary input."""
    filter_object = Gimp.DrawableFilter.new(drawable, BUMP_MAP_OPERATION, BUMP_MAP_OPERATION)
    filter_object.set_aux_input('aux', height_map_drawable)
    filter_config = filter_object.get_config()

    for property_name, property_value in properties.items():
        filter_config.set_property(property_name, property_value)

    drawable.merge_filter(filter_object)


def paint_shape_onto_layer(image, shape_layer, target_layer, hexadecimal_colour):
    """Paint the opaque area of the shape layer onto the target layer."""
    select_shape(image, shape_layer)
    set_background_colour(hexadecimal_colour)
    fill_with_background(target_layer)
    select_none(image)


def remove_colour(drawable, colour):
    """Make every pixel matching the supplied colour transparent."""
    apply_filter(drawable, COLOUR_TO_ALPHA_OPERATION, {'color': colour})


def apply_filter(drawable, operation_name, properties):
    """Apply the named GEGL operation to the drawable and commit the result."""
    filter_object = Gimp.DrawableFilter.new(drawable, operation_name, operation_name)
    filter_config = filter_object.get_config()

    for property_name, property_value in properties.items():
        filter_config.set_property(property_name, property_value)

    drawable.append_filter(filter_object)
    filter_object.update()
    drawable.merge_filter(filter_object)
