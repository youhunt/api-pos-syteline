from pathlib import Path
import xml.etree.ElementTree as ET
import sys

if len(sys.argv) != 3:
    raise SystemExit('Usage: upgrade_scheduler_rev7_ux.py input_rev6.xml output_rev7.xml')
SRC=Path(sys.argv[1])
DST=Path(sys.argv[2])

tree=ET.parse(SRC); root=tree.getroot(); form=root.find('.//Form[@Name="ue_SMK069ShipmentScheduler"]')
if form is None: raise RuntimeError('form not found')
comps=form.find('Components'); vars_el=form.find('Variables')

def comp(name):
    return next((x for x in comps.findall('Component') if x.attrib.get('Name')==name), None)

def settext(el, tag, val):
    n=el.find(tag)
    if n is None: n=ET.SubElement(el,tag)
    n.text=str(val)

def setcap(name, cap):
    c=comp(name)
    if c is None:return
    settext(c,'Caption',cap); settext(c,'EffectiveCaption',cap)

def setpos(name, top=None,left=None,width=None,height=None,hidden=None):
    c=comp(name)
    if c is None:return
    if top is not None:settext(c,'TopPos',top)
    if left is not None:settext(c,'LeftPos',left)
    if width is not None:settext(c,'Width',width)
    if height is not None:settext(c,'Height',height)
    if hidden is not None:settext(c,'Hidden','True' if hidden else 'False')

# Top status cleanup
setcap('SectionSystemStatus','SYSTEM STATUS — BUSINESS + TASKMAN RUNTIME')
setpos('SectionSystemStatus',width=66)
setcap('EngineStatusLabel','MASTER CONTROL')
setcap('ScheduleStatusLabel','BUSINESS SCHEDULE')
setcap('RunStateLabel','ACTUAL TASKMAN')
setcap('TaskStatusLabel','TASK STATUS')
setcap('TaskNumberLabel','TASK #')
setpos('TaskNumberLabel', left=88, width=10)
setpos('TaskNumberValue', left=99, width=7)
setpos('RefreshButton', left=108, width=11)
setpos('BusinessRunnerLabel', hidden=True)
setpos('BusinessRunnerValue', hidden=True)

# Dynamic operator action row.
setcap('OperationalStatusGuide','OPERATOR ACTION')
setpos('OperationalStatusGuide',top=5.8,left=2,width=14)
if not any(v.attrib.get('Name')=='OperatorAction' for v in vars_el.findall('Variable')):
    v=ET.SubElement(vars_el,'Variable',{'Name':'OperatorAction'})
    ET.SubElement(v,'Value').text='Checking scheduler state...'
    ET.SubElement(v,'Value2')
    ET.SubElement(v,'Value3')
    ET.SubElement(v,'Description').text='Human-readable recommended next action for operator'
if comp('OperatorActionValue') is None:
    c=ET.SubElement(comps,'Component',{'Name':'OperatorActionValue'})
    fields={
        'DeviceID':'-1','Type':'1','TabOrder':'0','TopPos':'5.8','LeftPos':'17','Height':'1','ListHeight':'0','Width':'100',
        'MaxCharacters':'0','ContainerName':'','ContainerSequence':'0','DataSource':'variables.OperatorAction','Binding':'6','Flags':'0',
        'ReadOnly':'True','Hidden':'False','HelpContextID':'0','Post301Format':''
    }
    for k,val in fields.items(): ET.SubElement(c,k).text=val
else:
    setpos('OperatorActionValue',top=5.8,left=17,width=100)

# Schedule settings: remove confusing default batch, present policy as 2x2.
setpos('DefaultMaxBatchSizeStatic_SITE', hidden=True)
setpos('DefaultMaxBatchSizeEdit_SITE', hidden=True)
setcap('IntervalMinutesStatic','Business Interval (min)')
setcap('MaxShipmentsStatic','Shipments / Run')
setcap('MaxAttemptsStatic_SITE','Retry Max Attempts')
setpos('IntervalMinutesStatic', top=11.4,left=2,width=14)
setpos('IntervalMinutesEdit', top=11.4,left=17,width=12)
setpos('MaxShipmentsStatic', top=11.4,left=32,width=12)
setpos('MaxShipmentsEdit', top=11.4,left=45,width=8)
setpos('MaxAttemptsStatic_SITE', top=12.9,left=2,width=14)
setpos('MaxAttemptsEdit_SITE', top=12.9,left=17,width=12)

if comp('TaskManHeartbeatStatic') is None:
    c=ET.SubElement(comps,'Component',{'Name':'TaskManHeartbeatStatic'})
    fields={'DeviceID':'-1','Type':'0','TabOrder':'0','TopPos':'12.9','LeftPos':'32','Height':'1','ListHeight':'0','Width':'12',
            'Caption':'TaskMan Heartbeat (min)','MaxCharacters':'0','ContainerName':'','ContainerSequence':'0','Binding':'0','Flags':'0','ReadOnly':'False','Hidden':'False','HelpContextID':'0','Post301Format':'','EffectiveCaption':'TaskMan Heartbeat (min)'}
    for k,val in fields.items(): ET.SubElement(c,k).text=val
if comp('TaskManHeartbeatValue') is None:
    c=ET.SubElement(comps,'Component',{'Name':'TaskManHeartbeatValue'})
    fields={'DeviceID':'-1','Type':'1','TabOrder':'0','TopPos':'12.9','LeftPos':'45','Height':'1','ListHeight':'0','Width':'8',
            'MaxCharacters':'0','ContainerName':'','ContainerSequence':'0','DataSource':'variables.HeartbeatMinutes','Binding':'6','Flags':'0','ReadOnly':'True','Hidden':'False','HelpContextID':'0','Post301Format':''}
    for k,val in fields.items(): ET.SubElement(c,k).text=val

setcap('LastStatusDisplayStatic','Run Result (N/S/W/E)')
setcap('LastMessageStatic','Last Message / Error')
setpos('LastMessageStatic',left=62,width=14)
setpos('LastMessageEdit',left=77,width=40,height=1.2)

# Cleaner action buttons.
setcap('RunNowButton','RUN ONCE (AUTO SAVE)')
setpos('SaveSettingsButton',left=2,width=13)
setpos('ActivateButton',left=16,width=16)
setpos('DeactivateButton',left=33,width=14)
setpos('RunNowButton',left=48,width=20)
setcap('ResetRetryButton','RESET SELECTED RETRY')
setpos('ResetRetryButton',left=99,width=18)

# Avoid overlapping retry title / guide.
setcap('TaskManRestartGuide','TIP: RUN ONCE auto-saves. Credential/heartbeat change: STOP until NOT REGISTERED, then START.')
setpos('TaskManRestartGuide',top=17.4,left=1,width=118)
setcap('SectionShipmentQueue','RETRY STATUS — CURRENT STATE PER DN')
setpos('SectionShipmentQueue',top=18.9,left=1,width=28)
setcap('RetryLegend','P=Pending/Retry | S=Success | X=Exhausted | HTTP 0=local / API belum di-hit')
setpos('RetryLegend',top=18.9,left=31,width=66)
setpos('ResetRetryButton',top=18.6)
setcap('RetryState','Status (P/S/X)')
setcap('RetryAttempts','Attempts')
setcap('RetryNextAttempt','Next Retry')
setcap('RetryLastAttempt','Last Attempt')
setcap('RetryError','Last Error')
setpos('gridRetryStatus',top=20.3,height=11.8)

# Shift API history and detail section down for breathing room.
shift_names=['SectionApiHitHistory','ApiHistoryLegend','gridApiHistory','ApiErrorDetailLabel','ApiErrorDetail','ApiResponseDetailLabel','ApiResponseDetail','ApiHistoryHint']
for name in shift_names:
    c=comp(name)
    if c is not None:
        try: old=float(c.findtext('TopPos')); settext(c,'TopPos',old+1.5)
        except: pass
setcap('SectionApiHitHistory','API EXECUTION HISTORY — AUDIT / TROUBLESHOOTING')
setcap('ApiHistoryLegend','Latest first | S=Success | E=Error | N=Pending | HTTP 0=local / API belum di-hit')
setcap('ApiErrorDetailLabel','SELECTED ERROR MESSAGE')
setcap('ApiResponseDetailLabel','SELECTED API RESPONSE')
setcap('ApiHistoryHint','Select a history row to inspect the full error message and API response below.')

# Keep metadata defaults aligned with actual 1-minute heartbeat.
for v in vars_el.findall('Variable'):
    if v.attrib.get('Name') == 'RecurringInterval':
        settext(v, 'Value', '1')
        settext(v, 'Description', 'Background Queue recurring interval; REV7 default 1 minute')

settext(form,'Height','64')

# Enhance the already-proven REV6 VB script with a dynamic operator recommendation.
script_lines=form.find('./Script/ScriptLines')
if script_lines is None: raise RuntimeError('script lines not found')
lines=[x.text or '' for x in script_lines.findall('ScriptLine')]
anchor='                Dim overall As String'
idx=lines.index(anchor)
insert=[
'                Dim readyShipments As Integer = IntValue(SafeSecondary(2, "ReadyCount"))',
'                Dim lastRunStatus As String = SafePrimary("LastRunStatus").ToUpperInvariant()',
'                Dim lastMessage As String = SafePrimary("LastMessage")',
'                Dim operatorAction As String = ""',
''
]
lines[idx:idx]=insert
anchor2='                Dim syncText As String = "SYNC"'
idx2=lines.index(anchor2)
action=[
'                If lastRunStatus = "E" AndAlso lastMessage.IndexOf("Login POS gagal", StringComparison.OrdinalIgnoreCase) >= 0 Then',
'                    operatorAction = "Credential POS bermasalah. STOP SCHEDULER -> update credential -> START SCHEDULER."',
'                ElseIf apiActive <> 1 Then',
'                    operatorAction = "API service inactive. Periksa konfigurasi API sebelum menjalankan scheduler."',
'                ElseIf taskCount > 1 Then',
'                    operatorAction = "Duplicate TaskMan terdeteksi. STOP dan bersihkan duplicate sebelum START kembali."',
'                ElseIf taskCount = 0 AndAlso masterEnabled = 1 AndAlso scheduleEnabled = 1 Then',
'                    operatorAction = "TaskMan belum terdaftar. Tekan START SCHEDULER untuk membuat heartbeat."',
'                ElseIf masterEnabled <> 1 OrElse scheduleEnabled <> 1 Then',
'                    operatorAction = "Scheduler stopped. Review setting lalu tekan START SCHEDULER bila siap."',
'                ElseIf runningCount > 0 Then',
'                    operatorAction = "Scheduler sedang memproses Shipment. Tunggu selesai lalu REFRESH STATUS."',
'                ElseIf readyShipments > 0 Then',
'                    operatorAction = readyShipments.ToString() & " DN ready. Scheduler akan memproses sesuai Shipments / Run."',
'                Else',
'                    operatorAction = "Scheduler healthy. Menunggu Shipment due / retry berikutnya."',
'                End If',
''
]
lines[idx2:idx2]=action
assign_anchor='                ThisForm.Variables("OverallStatus").Value = overall'
idx3=lines.index(assign_anchor)+1
lines[idx3:idx3]=['                ThisForm.Variables("OperatorAction").Value = operatorAction']
lines=[ln.replace("' RecurringInterval=5 => Every 5 minutes", "' RecurringInterval comes from HeartbeatMinutes; REV7 target = every 1 minute") for ln in lines]
for x in list(script_lines): script_lines.remove(x)
for ln in lines:
    el=ET.SubElement(script_lines,'ScriptLine')
    if ln!='': el.text=ln

ET.indent(tree,space='   ')
tree.write(DST,encoding='utf-8',xml_declaration=True)
print(DST)
