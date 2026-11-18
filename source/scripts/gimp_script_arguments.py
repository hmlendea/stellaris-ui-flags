"""Reading of the arguments supplied to a GIMP batch script."""

import os

from gimp_script_errors import GimpScriptError

ENVIRONMENT_VARIABLE_PREFIX = 'GIMP_SCRIPT_'


def read_argument(argument_name):
    """Return the environment-supplied value of the named argument."""
    environment_variable_name = f'{ENVIRONMENT_VARIABLE_PREFIX}{argument_name}'
    argument_value = os.environ.get(environment_variable_name)

    if argument_value is None:
        raise GimpScriptError(f"The argument '{argument_name}' was not supplied.")

    return argument_value


def read_integer_argument(argument_name):
    """Return the environment-supplied whole-number value of the named argument."""
    argument_value = read_argument(argument_name)

    try:
        return int(argument_value)
    except ValueError as exception:
        raise GimpScriptError(f"The argument '{argument_name}' is not a whole number.") from exception
