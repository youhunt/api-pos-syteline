#!/usr/bin/env python3
"""Convert a tenant Shipment Scheduler form export to the one-form operator model.

Usage:
    python convert_scheduler_one_form.py input.xml output.xml

The generated XML intentionally uses credential placeholders. Never commit real
POS credentials to the repository.
"""

from pathlib import Path
import sys
import xml.etree.ElementTree as ET


def set_text(parent, tag, value):
    node = parent.find(tag)
    if node is None:
        node = ET.SubElement(parent, tag)
    node.text = value


def convert(src: Path, dst: Path):
    tree = ET.parse(src)
    root = tree.getroot()
    forms = root.find("Forms")
    if forms is None:
        raise RuntimeError("Forms node not found")

    for form in list(forms.findall("Form")):
        if form.attrib.get("Name") != "ue_SMK069ShipmentScheduler":
            forms.remove(form)

    main = forms.find("Form")
    if main is None or main.attrib.get("Name") != "ue_SMK069ShipmentScheduler":
        raise RuntimeError("ue_SMK069ShipmentScheduler not found")

    components = main.find("Components")
    handlers = main.find("EventHandlers")
    variables = main.find("Variables")

    def component(name):
        for item in components.findall("Component"):
            if item.attrib.get("Name") == name:
                return item
        return None

    for name, caption in {
        "ActivateButton": "Activate Scheduler",
        "DeactivateButton": "Deactivate Scheduler",
    }.items():
        item = component(name)
        if item is not None:
            set_text(item, "Caption", caption)
            effective = item.find("EffectiveCaption")
            if effective is not None:
                effective.text = caption

    schedule_name = component("ScheduleNameEdit")
    if schedule_name is not None:
        set_text(schedule_name, "ReadOnly", "False")

    for name in (
        "POSUsernameEdit", "POSUsernameLabel",
        "POSPasswordEdit", "POSPasswordLabel",
    ):
        item = component(name)
        if item is not None:
            set_text(item, "Hidden", "True")
            if name.endswith("Edit"):
                set_text(item, "ReadOnly", "True")

    for var in variables.findall("Variable"):
        name = var.attrib.get("Name")
        if name == "POSUsername":
            set_text(var, "Value", "~LIT~(__POS_USERNAME__)")
            set_text(var, "Description", "Hidden TaskMan credential; replace locally before import")
        elif name == "POSPassword":
            set_text(var, "Value", "~LIT~(__POS_PASSWORD__)")
            set_text(var, "Description", "Hidden TaskMan credential; replace locally before import")

    for event in list(handlers.findall("EventHandler")):
        if event.attrib.get("Name") in (
            "ActivateSchedule", "DeactivateSchedule", "SubmitSchedulerScheduled"
        ):
            handlers.remove(event)

    def add_handler(name, sequence, response_type, response):
        event = ET.Element("EventHandler", {"Name": name, "Sequence": str(sequence)})
        ET.SubElement(event, "ResponseType").text = str(response_type)
        ET.SubElement(event, "Response").text = response
        handlers.append(event)

    add_handler(
        "ActivateSchedule", 0, 0,
        "ue_SMK069ShipmentTransport.SMK069SaveShipmentScheduleSp( "
        "PARMS(VAR P(ScheduleCode), VAR P(ScheduleName), VAR P(IntervalMinutes), "
        "VAR P(MaxShipments), VAR V(FlagOn), VAR V(BlankStartAt), "
        "RVAR V(Success), MESSAGE) ERRORMESSAGE(mBackEndMessage) "
        "SUCCESSMESSAGE(mBackEndMessage) )"
    )
    add_handler(
        "ActivateSchedule", 1, 0,
        "ue_SMK069ShipmentTransport.SMK069SetShipmentSchedulerEnabledSp( "
        "PARMS(VAR V(FlagOn), RVAR V(Success), MESSAGE) "
        "ERRORMESSAGE(mBackEndMessage) SUCCESSMESSAGE(mBackEndMessage) )"
    )
    for seq, obj in enumerate(("object", "object2", "object3"), start=2):
        add_handler("ActivateSchedule", seq, 28, obj)

    add_handler(
        "DeactivateSchedule", 0, 0,
        "ue_SMK069ShipmentTransport.SMK069SetShipmentSchedulerEnabledSp( "
        "PARMS(VAR V(FlagOff), RVAR V(Success), MESSAGE) "
        "ERRORMESSAGE(mBackEndMessage) SUCCESSMESSAGE(mBackEndMessage) )"
    )
    add_handler(
        "DeactivateSchedule", 1, 0,
        "ue_SMK069ShipmentTransport.SMK069SaveShipmentScheduleSp( "
        "PARMS(VAR P(ScheduleCode), VAR P(ScheduleName), VAR P(IntervalMinutes), "
        "VAR P(MaxShipments), VAR V(FlagOff), VAR V(BlankStartAt), "
        "RVAR V(Success), MESSAGE) ERRORMESSAGE(mBackEndMessage) "
        "SUCCESSMESSAGE(mBackEndMessage) )"
    )
    for seq, obj in enumerate(("object", "object2", "object3"), start=2):
        add_handler("DeactivateSchedule", seq, 28, obj)

    try:
        ET.indent(tree, space="   ")
    except AttributeError:
        pass

    tree.write(dst, encoding="utf-8", xml_declaration=True)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Usage: convert_scheduler_one_form.py input.xml output.xml")
    convert(Path(sys.argv[1]), Path(sys.argv[2]))
