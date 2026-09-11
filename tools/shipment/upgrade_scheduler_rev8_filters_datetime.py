from pathlib import Path
import sys
import xml.etree.ElementTree as ET

if len(sys.argv) != 3:
    raise SystemExit("Usage: upgrade_scheduler_rev8_filters_datetime.py input.xml output.xml")

SRC = Path(sys.argv[1])
DST = Path(sys.argv[2])

tree = ET.parse(SRC)
root = tree.getroot()
form = root.find('.//Form[@Name="ue_SMK069ShipmentScheduler"]')
if form is None:
    raise RuntimeError('ue_SMK069ShipmentScheduler not found')

components = form.find('Components')
handlers = form.find('EventHandlers')
variables = form.find('Variables')
script_lines = form.find('./Script/ScriptLines')


def comp(name):
    return next((x for x in components.findall('Component') if x.attrib.get('Name') == name), None)


def var(name):
    return next((x for x in variables.findall('Variable') if x.attrib.get('Name') == name), None)


def settext(parent, tag, value):
    node = parent.find(tag)
    if node is None:
        node = ET.SubElement(parent, tag)
    node.text = str(value)


def add_var(name, value, description):
    node = var(name)
    if node is None:
        node = ET.SubElement(variables, 'Variable', {'Name': name})
        ET.SubElement(node, 'Value')
        ET.SubElement(node, 'Value2')
        ET.SubElement(node, 'Value3')
        ET.SubElement(node, 'Description')
    settext(node, 'Value', value)
    settext(node, 'Description', description)


def add_component(name, fields):
    old = comp(name)
    if old is not None:
        components.remove(old)
    node = ET.SubElement(components, 'Component', {'Name': name})
    for key, value in fields.items():
        settext(node, key, value)
    return node


def add_handler(name, response):
    for old in list(handlers.findall('EventHandler')):
        if old.attrib.get('Name') == name:
            handlers.remove(old)
    node = ET.SubElement(handlers, 'EventHandler', {'Name': name, 'Sequence': '0'})
    ET.SubElement(node, 'ResponseType').text = '35'
    ET.SubElement(node, 'Response').text = response


# Shareable generator output must never carry live credentials.
for name, value in (
    ('POSUsername', '~LIT~(__POS_USERNAME__)'),
    ('POSPassword', '~LIT~(__POS_PASSWORD__)'),
):
    node = var(name)
    if node is not None:
        settext(node, 'Value', value)

node = var('RecurringInterval')
if node is not None:
    settext(node, 'Value', '1')

# Show date + time, not date only.
for name in ('RetryLastAttempt', 'RetryNextAttempt', 'ApiHistDate', 'LastRunDateEdit', 'NextRunDateEdit'):
    node = comp(name)
    if node is not None:
        settext(node, 'Post301Format', 'DATETIME()')
for name in ('RetryLastAttempt', 'RetryNextAttempt'):
    node = comp(name)
    if node is not None:
        settext(node, 'Width', '22')

# Space for filter bar.
grid = comp('gridRetryStatus')
if grid is not None:
    settext(grid, 'TopPos', '22.6')
    settext(grid, 'Height', '8.95')
legend = comp('RetryLegend')
if legend is not None:
    caption = 'P=PENDING/RETRY | S=SUCCESS (tetap disimpan sebagai history) | X=EXHAUSTED | HTTP 0=LOCAL/BELUM HIT API'
    settext(legend, 'Caption', caption)
    settext(legend, 'EffectiveCaption', caption)
    settext(legend, 'Width', '112')

add_var('RetryFilterMode', 'OPEN', 'Retry grid filter mode: OPEN, SUCCESS, EXHAUSTED, ALL')
add_var('RetryFilterDN', '', 'Optional partial DN filter')
add_var('RetryFilterDisplay', 'OPEN', 'Human-readable active retry filter')

static = {'DeviceID':'-1','Type':'0','TabOrder':'0','Height':'1','ListHeight':'0','MaxCharacters':'0','ContainerName':'notebookTab1_SITE','ContainerSequence':'0','Binding':'0','Flags':'0','ReadOnly':'False','Hidden':'False','HelpContextID':'0','Post301Format':''}
button = {'DeviceID':'-1','Type':'8','TabOrder':'0','Height':'1.35','ListHeight':'0','MaxCharacters':'0','ContainerName':'notebookTab1_SITE','ContainerSequence':'0','Binding':'0','Flags':'0','ReadOnly':'False','Hidden':'False','HelpContextID':'0','Post301Format':''}
edit = {'DeviceID':'-1','Type':'1','TabOrder':'0','Height':'1','ListHeight':'0','MaxCharacters':'0','ContainerName':'notebookTab1_SITE','ContainerSequence':'0','Binding':'6','Flags':'0','ReadOnly':'False','Hidden':'False','HelpContextID':'0','Post301Format':''}

x = dict(static); x.update({'TopPos':'20.35','LeftPos':'2.6','Width':'7','Caption':'FILTER:','EffectiveCaption':'FILTER:'}); add_component('RetryFilterLabel', x)
for name, caption, left, width, event in (
    ('RetryFilterOpenButton','OPEN','9.5','10','FilterRetryOpen'),
    ('RetryFilterSuccessButton','SUCCESS','20','11','FilterRetrySuccess'),
    ('RetryFilterExhaustedButton','EXHAUSTED','31.5','14','FilterRetryExhausted'),
    ('RetryFilterAllButton','ALL','46','8','FilterRetryAll'),
):
    x = dict(button); x.update({'TopPos':'20.15','LeftPos':left,'Width':width,'Caption':caption,'EffectiveCaption':caption,'EventToGenerate':event}); add_component(name, x)

x = dict(static); x.update({'TopPos':'20.35','LeftPos':'56','Width':'5','Caption':'DN:','EffectiveCaption':'DN:'}); add_component('RetryFilterDNLabel', x)
x = dict(edit); x.update({'TopPos':'20.25','LeftPos':'61','Width':'17','DataSource':'variables.RetryFilterDN'}); add_component('RetryFilterDNEdit', x)
x = dict(button); x.update({'TopPos':'20.15','LeftPos':'79','Width':'9','Caption':'APPLY','EffectiveCaption':'APPLY','EventToGenerate':'ApplyRetryDNFilter'}); add_component('RetryFilterApplyButton', x)
x = dict(button); x.update({'TopPos':'20.15','LeftPos':'88.5','Width':'10','Caption':'CLEAR DN','EffectiveCaption':'CLEAR DN','EventToGenerate':'ClearRetryDNFilter'}); add_component('RetryFilterClearButton', x)
x = dict(static); x.update({'TopPos':'20.35','LeftPos':'100','Width':'8','Caption':'VIEW:','EffectiveCaption':'VIEW:'}); add_component('RetryFilterViewLabel', x)
x = dict(edit); x.update({'TopPos':'20.25','LeftPos':'108','Width':'12','DataSource':'variables.RetryFilterDisplay','ReadOnly':'True'}); add_component('RetryFilterViewValue', x)

for name, response in (
    ('FilterRetryOpen', 'FilterRetryOpen()'),
    ('FilterRetrySuccess', 'FilterRetrySuccess()'),
    ('FilterRetryExhausted', 'FilterRetryExhausted()'),
    ('FilterRetryAll', 'FilterRetryAll()'),
    ('ApplyRetryDNFilter', 'ApplyRetryDNFilter()'),
    ('ClearRetryDNFilter', 'ClearRetryDNFilter()'),
):
    add_handler(name, response)

init = [h for h in handlers.findall('EventHandler') if h.attrib.get('Name') == 'StdFormInitCompleted']
if not any((h.findtext('Response') or '') == 'FilterRetryOpen()' for h in init):
    seq = max([int(h.attrib.get('Sequence','0')) for h in init] or [0]) + 1
    node = ET.SubElement(handlers, 'EventHandler', {'Name':'StdFormInitCompleted','Sequence':str(seq)})
    ET.SubElement(node, 'ResponseType').text = '35'
    ET.SubElement(node, 'Response').text = 'FilterRetryOpen()'

lines = [x.text or '' for x in script_lines.findall('ScriptLine')]
if not any('Private Function ApplyRetryFilterInternal' in line for line in lines):
    insert_at = next(i for i, line in enumerate(lines) if line.strip() == 'End Class')
    extra = [
        '',
        '        Private Function EscapeRetryFilterLiteral(ByVal value As String) As String',
        '            If value Is Nothing Then Return ""',
        '            Return value.Replace("\'", "\'\'")',
        '        End Function',
        '',
        '        Private Function ApplyRetryFilterInternal(ByVal requestedMode As String) As Integer',
        '            Try',
        '                Dim col As IWSIDOCollection = ThisForm.GetSecondaryIDOCollection(6)',
        '                If col Is Nothing Then Return -1',
        '                Dim mode As String = If(requestedMode, "ALL").Trim().ToUpperInvariant()',
        '                Dim filterText As String = ""',
        '                Select Case mode',
        '                    Case "OPEN" : filterText = "RetryState <> \'S\'"',
        '                    Case "SUCCESS" : filterText = "RetryState = \'S\'"',
        '                    Case "EXHAUSTED" : filterText = "RetryState = \'X\'"',
        '                    Case Else : mode = "ALL"',
        '                End Select',
        '                Dim dn As String = ThisForm.Variables("RetryFilterDN").Value',
        '                If dn Is Nothing Then dn = ""',
        '                dn = dn.Trim()',
        '                If dn <> "" Then',
        '                    Dim dnClause As String = "ShipmentId LIKE \'%" & EscapeRetryFilterLiteral(dn) & "%\'"',
        '                    If filterText <> "" Then filterText = "(" & filterText & ") AND " & dnClause Else filterText = dnClause',
        '                End If',
        '                col.Filter = filterText',
        '                col.Refresh()',
        '                ThisForm.Variables("RetryFilterMode").Value = mode',
        '                ThisForm.Variables("RetryFilterDisplay").Value = If(dn = "", mode, mode & " / " & dn)',
        '                Return 0',
        '            Catch ex As Exception',
        '                Application.ShowMessage("Retry filter gagal: " & ex.Message)',
        '                Return -1',
        '            End Try',
        '        End Function',
        '',
        '        Public Function FilterRetryOpen() As Integer : Return ApplyRetryFilterInternal("OPEN") : End Function',
        '        Public Function FilterRetrySuccess() As Integer : Return ApplyRetryFilterInternal("SUCCESS") : End Function',
        '        Public Function FilterRetryExhausted() As Integer : Return ApplyRetryFilterInternal("EXHAUSTED") : End Function',
        '        Public Function FilterRetryAll() As Integer : Return ApplyRetryFilterInternal("ALL") : End Function',
        '        Public Function ApplyRetryDNFilter() As Integer : Return ApplyRetryFilterInternal(ThisForm.Variables("RetryFilterMode").Value) : End Function',
        '        Public Function ClearRetryDNFilter() As Integer',
        '            ThisForm.Variables("RetryFilterDN").Value = ""',
        '            Return ApplyRetryFilterInternal(ThisForm.Variables("RetryFilterMode").Value)',
        '        End Function',
        '',
    ]
    lines[insert_at:insert_at] = extra
    for node in list(script_lines):
        script_lines.remove(node)
    for line in lines:
        node = ET.SubElement(script_lines, 'ScriptLine')
        if line:
            node.text = line

ET.indent(tree, space='   ')
tree.write(DST, encoding='utf-8', xml_declaration=True)
ET.parse(DST)
print(DST)
