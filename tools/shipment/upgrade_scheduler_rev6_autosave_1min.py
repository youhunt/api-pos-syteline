#!/usr/bin/env python3
"""Upgrade the current SMK069 Shipment Scheduler XML to REV6.

REV6 changes are metadata-only:
- TaskMan heartbeat for newly created recurring task: 1 minute.
- RUN ONCE auto-saves ScheduleName / IntervalMinutes / MaxShipments first.
- Clarify UI labels so MaxBatchSize, MaxShipments and MaxAttempts are not confused.
- Keep POS credentials as local placeholders; never commit real credentials.
- Preserve the existing VB script exactly.

Usage:
    python upgrade_scheduler_rev6_autosave_1min.py input.xml output.xml

IMPORTANT:
An already REGISTERED recurring TaskMan row keeps its old task parameters.
After changing credentials or heartbeat, STOP until the old WAITING task is
removed / NOT REGISTERED, then START again so a fresh recurring task is created.
RUN ONCE submits a one-shot task and does not mutate the existing recurring row.
"""

from copy import deepcopy
from pathlib import Path
import sys
import xml.etree.ElementTree as ET


def set_caption(components, name, caption):
    target = None
    for c in components.findall("Component"):
        if c.attrib.get("Name") == name:
            target = c
            break
    if target is None:
        return
    node = target.find("Caption")
    if node is not None:
        node.text = caption
    node = target.find("EffectiveCaption")
    if node is not None:
        node.text = caption


def upgrade(src: Path, dst: Path):
    tree = ET.parse(src)
    root = tree.getroot()
    form = root.find(".//Form[@Name='ue_SMK069ShipmentScheduler']")
    if form is None:
        raise RuntimeError("ue_SMK069ShipmentScheduler not found")

    components = form.find("Components")
    handlers = form.find("EventHandlers")
    variables = form.find("Variables")
    if components is None or handlers is None or variables is None:
        raise RuntimeError("Form metadata is incomplete")

    script_before = [(n.text or "") for n in form.findall(".//ScriptLine")]

    for var in variables.findall("Variable"):
        name = var.attrib.get("Name")
        if name == "HeartbeatMinutes":
            var.find("Value").text = "1"
            desc = var.find("Description")
            if desc is not None:
                desc.text = (
                    "Fixed TaskMan heartbeat = 1 minute; takes effect after "
                    "STOP old WAITING task and START again"
                )
        elif name == "POSUsername":
            var.find("Value").text = "~LIT~(__POS_USERNAME__)"
            desc = var.find("Description")
            if desc is not None:
                desc.text = (
                    "Hidden credential; replace locally before import. RUN ONCE "
                    "uses current form value; recurring task takes value on START."
                )
        elif name == "POSPassword":
            var.find("Value").text = "~LIT~(__POS_PASSWORD__)"
            desc = var.find("Description")
            if desc is not None:
                desc.text = (
                    "Hidden credential; replace locally before import. RUN ONCE "
                    "uses current form value; recurring task takes value on START."
                )

    set_caption(components, "RunNowButton", "SAVE + RUN ONCE")
    set_caption(components, "DefaultMaxBatchSizeStatic_SITE", "Default Batch Size")
    set_caption(components, "MaxAttemptsStatic_SITE", "Retry Max Attempts")
    set_caption(components, "MaxShipmentsStatic", "Shipments / Run")
    set_caption(components, "IntervalMinutesStatic", "Business Interval (Min)")
    set_caption(
        components,
        "OperationalStatusGuide",
        "RUN ONCE auto-saves schedule. Credential/TaskMan heartbeat changes require STOP -> START.",
    )

    current_run = [
        h for h in list(handlers.findall("EventHandler"))
        if h.attrib.get("Name") == "RunNowOnce"
    ]
    if not current_run:
        raise RuntimeError("RunNowOnce handlers not found")

    for h in current_run:
        handlers.remove(h)

    def add_handler(name, sequence, response_type, response):
        h = ET.Element("EventHandler", {"Name": name, "Sequence": str(sequence)})
        ET.SubElement(h, "ResponseType").text = str(response_type)
        ET.SubElement(h, "Response").text = response
        handlers.append(h)

    add_handler(
        "RunNowOnce",
        0,
        0,
        "ue_SMK069ShipmentTransport.SMK069SaveShipmentScheduleSp( "
        "PARMS(VAR P(ScheduleCode), VAR P(ScheduleName), VAR P(IntervalMinutes), "
        "VAR P(MaxShipments), VAR P(IsEnabled), VAR V(BlankStartAt), "
        "RVAR V(Success), MESSAGE) ERRORMESSAGE(mBackEndMessage) "
        "SUCCESSMESSAGE(mBackEndMessage) )",
    )

    for h in sorted(current_run, key=lambda x: int(x.attrib.get("Sequence", "0"))):
        new_h = deepcopy(h)
        new_h.attrib["Sequence"] = str(int(h.attrib.get("Sequence", "0")) + 1)
        handlers.append(new_h)

    if not any(c.attrib.get("Name") == "TaskManRestartGuide" for c in components.findall("Component")):
        c = ET.SubElement(components, "Component", {"Name": "TaskManRestartGuide"})
        fields = {
            "DeviceID": "-1",
            "Type": "0",
            "TabOrder": "0",
            "TopPos": "17.5",
            "LeftPos": "2",
            "Height": "1",
            "ListHeight": "0",
            "Width": "70",
            "Caption": "After credential/heartbeat change: STOP until NOT REGISTERED, then START.",
            "MaxCharacters": "0",
            "ContainerName": "",
            "ContainerSequence": "0",
            "Binding": "0",
            "Flags": "0",
            "ReadOnly": "False",
            "Hidden": "False",
            "HelpContextID": "0",
            "Post301Format": "JUSTIFY(L)",
            "EffectiveCaption": "After credential/heartbeat change: STOP until NOT REGISTERED, then START.",
        }
        for tag, value in fields.items():
            ET.SubElement(c, tag).text = value

    try:
        ET.indent(tree, space="   ")
    except AttributeError:
        pass
    tree.write(dst, encoding="utf-8", xml_declaration=True)

    check = ET.parse(dst).getroot().find(".//Form[@Name='ue_SMK069ShipmentScheduler']")
    script_after = [(n.text or "") for n in check.findall(".//ScriptLine")]
    if script_before != script_after:
        raise RuntimeError("REV6 aborted: existing VB script changed unexpectedly")

    values = {
        v.attrib.get("Name"): v.findtext("Value")
        for v in check.find("Variables").findall("Variable")
    }
    if values.get("HeartbeatMinutes") != "1":
        raise RuntimeError("REV6 validation failed: HeartbeatMinutes != 1")
    if values.get("POSUsername") != "~LIT~(__POS_USERNAME__)" or values.get("POSPassword") != "~LIT~(__POS_PASSWORD__)":
        raise RuntimeError("REV6 validation failed: credential placeholders not preserved")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Usage: upgrade_scheduler_rev6_autosave_1min.py input.xml output.xml")
    upgrade(Path(sys.argv[1]), Path(sys.argv[2]))
