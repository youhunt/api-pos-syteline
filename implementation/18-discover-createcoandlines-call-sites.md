# Implementation 18 — Discover Standard CreateCoAndLines Call Sites

## Status

```text
Environment                         : DEV
Controlled malformed probes         : COMPLETED
All four no-order checks             : COMPLETED — ZERO ROWS
Base64 input requirement             : CONFIRMED
Decoded payload type                 : JSON object / JObject
Specific order structure required    : CONFIRMED
Exact business JSON schema           : NOT YET CONFIRMED
Further property-name guessing       : STOPPED
Standard call-site discovery         : STARTED — READ-ONLY
```

## Why the Discovery Path Changes

The completed runtime probes confirmed:

```text
1. raw input is rejected unless it is valid Base64;
2. decoded content is parsed as a JSON object / JObject;
3. an empty object is treated as blank order input;
4. an arbitrary non-business property is also treated as blank order input;
5. no Customer Order was created by any of the four probes in the checked windows.
```

The method therefore expects one or more specific business members or a specific nested order structure. Guessing names such as `Order`, `Header`, `Lines`, `Co`, or similar is not authorized because tenant evidence has not confirmed them.

The next safe path is to locate a standard form event handler, form script, global script, application event action, or another metadata call site that invokes:

```text
SLCos.CreateCoAndLines
```

A standard call site may reveal the exact JSON construction and Base64 encoding behavior.

## Current Small Step — Discover Candidate Metadata Collections

Use the already confirmed read-only `IdoCollections` REST v1 load to find metadata collections related to form events and event handlers.

```http
GET {{mongooseBaseUrl}}/IDORequestService/MGRESTService.svc/json/IdoCollections/adv?props=CollectionName,CaptionOrName,CollectionDesc,ServerName,AccessAs&filter=CollectionName%20LIKE%20%27%25FormEvent%25%27%20OR%20CollectionName%20LIKE%20%27%25EventHandler%25%27
Authorization: {{mongooseSecurityToken}}
Accept: application/json
```

Capture the complete JSON response.

## Purpose

The result will identify the actual tenant metadata IDO names before attempting any filtered search for `CreateCoAndLines` references.

## Safety Boundary

```text
- Read metadata only.
- Do not invoke CreateCoAndLines again.
- Do not guess a Customer Order JSON property.
- Do not edit form handlers, scripts, events, or metadata.
- Do not create Process/Reprocess logic yet.
- Do not import CSV or create the controlled receive API method.
```
