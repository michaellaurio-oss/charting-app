# Home Visit Charting App

A prototype app that turns a home health nurse's spoken notes into a completed patient chart.

**Status:** Prototype, version 1. Uses fictional patients only. Not for real patient data.

---

## The idea

The nurse starts the app when a home visit begins. As she works, she says her findings out loud into an earbud. The earbud picks up her voice and not the other voices in the room. She works the way she normally does, for example:

- "Let me verify, your name is Dorothy Alvarez? Great. And your birthday, March 14th 1948. Member number..."
- "BP is 138 over 82, heart rate 84."
- "Plus two pitting edema, left ankle. Right is the same."

The app puts each item where it belongs in the chart. At the end of the visit, she reviews the chart and signs it.

## Version 1 features

| Feature | What it does |
|---|---|
| **Identity check** | Compares the name, birth date and member number she says out loud with the patient record. A mismatch shows a red alert and blocks signing. The check runs on the phone, not through AI. |
| **Live chart filling** | Each part of the dictation fills vitals, the systems assessment, wounds, medication review and teaching. Tapping a field shows the words it came from. Later corrections replace earlier values, and the corrections are logged. |
| **Review and sign** | A checklist covers identity, whether all dictation has been processed, and any missing core items. Signing is blocked until identity is verified and processing is finished. |
| **Physician request draft** | Recommendations such as "we need to order oxygen" become proposed orders that need physician approval. The app drafts a Teams message to the physician, which she edits and sends herself. |

### Physician approval workflow

1. Recommendations she dictates are kept apart from observations. Nothing is ordered without physician approval.
2. Each request includes the clinical reason, taken from findings earlier in the visit.
3. Details she didn't state, such as a morphine dose, show as highlighted blanks. The app never guesses them.
4. She can edit the draft freely. **Update & Copy** compares her edited text with what she dictated, then shows what was added, changed and removed. She confirms, the records update, and the text is copied.
5. She pastes the message into Teams herself. Copying instead of auto-sending makes an accidental send less likely.
6. **Mark as sent** records that the request went out, so the status reads *awaiting physician*.
7. What happens after the physician approves or rejects is still to be designed.

## How to run version 1

- **Live app:** [Home Visit Charting](https://claude.ai/artifact/RACdBb4PoqbfPTQf1UWJPY) (private; open it on your phone or PC)
- **Source:** `visit-app.html` in this folder
- **Voice input:** use your keyboard's dictation. On a phone, that's the mic button on the keyboard. On Windows, press **Windows key + H** with the cursor in the dictation box.
- **Demo:** open Dorothy Alvarez and use the **Sample line** button to step through a scripted visit.
- **First use:** the app asks permission to use Claude. Processing uses the viewer's own Claude usage.

### Known limits of version 1

- No always-on microphone. The hosting doesn't allow direct mic access, so each part of the dictation starts with a tap. An always-on mic needs the app hosted on its own site or built as an Android app.
- Nothing is saved between sessions. Reloading the page starts the day over.
- No offline mode and no audio playback yet.
- The database in this folder isn't connected to the app yet.

## Files in this folder

| File | What it is |
|---|---|
| `README.md` | This file |
| `visit-app.html` | Version 1 app (single web page) |
| `schema.sql` | SQLite database design: 26 tables plus trend views |
| `seed.sql` | Sample data: one fictional patient, two visits, one voice note with extracted fields |
| `charting.db` | Ready-built database (schema plus seed). Open it with DB Browser for SQLite. |
| `Charting App Test Scripts.docx` | Six test scripts with expected results and a results log |
| `Raw material/` | Reference material: chart and visit templates, a home health form, a hand-off report sheet, a charting training transcript, nursing documentation videos, and a Pega care management blueprint |

Related online pages:

- [Test scripts (live doc)](https://claude.ai/code/artifact/a9a0f803-f4c9-4033-87cd-3568daaaad56): the same scripts, with Pass/Fail dropdowns
- [Sample visit note](https://claude.ai/artifact/N6tPqzBmHkikgiVLzNiunS): a filled-in skilled nursing visit note used as the model for the chart

## Data model

The schema is in `schema.sql`. Table names loosely follow HL7 FHIR resources to make EHR integration easier later.

- **People and the episode of care:** patient, caregiver, clinician, allergy, diagnosis, episode (60-day certification period), discipline orders, care goals
- **The visit:** visit, homebound reasons, vital signs (one row per measurement so trends work), systems assessment, scored tools (MAHC-10, Braden, PHQ-2), home safety
- **Ongoing items:** wounds and wound assessments across visits, medications and medication reconciliation
- **Care:** interventions, teaching, goal progress, care coordination, new orders
- **Voice pipeline:** `voice_note` stores the transcript. `extracted_field` stores each value the AI pulled out, with its source snippet, a confidence score, and the nurse's review (accepted, edited or rejected).

### Schema changes still to make

- `proposed_order`: item, details, rationale, missing details, approval status
- `physician_message`: drafted text, sent text, sent time, and amendments
- Split a visit's voice note into time-stamped transcript segments
- An identity verification record
- A superseded flag on extracted fields when a later value corrects them

## Design decisions

- **Observations and recommendations are kept apart.** Observations go into the chart. Recommendations become proposed orders that wait for physician approval.
- **AI-filled values need review.** Every extracted value is traceable to what was said and is reviewed before signing.
- **Copy instead of auto-send** for physician requests.
- **The sent text is the record.** If the nurse edits the draft, her final message becomes the record. The original dictation and the app's draft are kept for the audit trail.
- **Signal is never required during the visit.** The patient record downloads ahead of time, recording is saved on the phone, and processing catches up when signal returns. Planned for after version 1.
- **Audio is kept until signing, plus a short window** such as 7 days, then deleted. The signed chart and transcript are the permanent record. Each agency would set the window.

## Open issues to solve before real use

| Issue | Planned approach |
|---|---|
| Corrections ("actually, let me retake that") | Latest value wins; earlier value kept in the audit trail. Done in version 1. |
| Context carryover ("right is the same") | Resolved from earlier dictation. Done in version 1. |
| Findings in any order | Routed by meaning, not form order. Done in version 1. |
| Missing items | Flagged on the sign checklist. Done in version 1. |
| Earbud audio quality | Bluetooth headset mics can lower transcription accuracy. Test early with the actual earbuds. |
| Wrong-patient charting | A mismatch blocks signing. Need a firm rule for what happens next. |
| Poor signal in homes | Record on the phone, queue processing, and sync later. Planned. |
| Things voice handles poorly | Wound photos and signatures still need a tap. |
| After physician approval or rejection | Not yet designed. |
| Real patient data | Requires HIPAA safeguards, encrypted storage, and an agency-approved hosting setup. |

## Next steps

1. Run the six test scripts and log the results.
2. Test real speech through earbuds and compare the transcript with what was said.
3. Design what happens after physician approval or rejection.
4. Add the remaining schema tables and connect saved data to the app.
5. Decide when to move to an always-on mic (own hosted site or Android app).
