"""Execution of GIMP procedures using named configuration properties."""

from gi.repository import Gimp

from gimp_script_errors import GimpScriptError


def find_procedure(procedure_name):
    """Return the named GIMP procedure, or raise when it is unavailable."""
    procedure = Gimp.get_pdb().lookup_procedure(procedure_name)

    if procedure is None:
        raise GimpScriptError(f"The GIMP procedure '{procedure_name}' is not available.")

    return procedure


def run_procedure(procedure_name, properties):
    """Run the named GIMP procedure after applying the supplied properties."""
    procedure = find_procedure(procedure_name)
    config = procedure.create_config()

    for property_name, property_value in properties.items():
        config.set_property(property_name, property_value)

    result = procedure.run(config)
    status = result.index(0)

    if status != Gimp.PDBStatusType.SUCCESS:
        raise GimpScriptError(f"The GIMP procedure '{procedure_name}' failed with the status '{status}'.")

    return result
