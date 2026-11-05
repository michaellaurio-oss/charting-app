-- =====================================================================
-- Charting App — Home Health Skilled Nursing Visit (prototype schema)
-- SQLite. Run:  sqlite3 charting.db < schema.sql
--
-- Design notes
--  * One row per real-world thing; repeating data (vitals, wound
--    measurements, meds, goals) lives in child tables so trends work.
--  * Voice-note pipeline: raw dictation is stored in voice_note; each
--    field the AI extracts is traceable via extracted_field, so a nurse
--    can review/accept before it lands in the chart.
--  * Table names loosely map to HL7 FHIR resources (noted per table)
--    to ease future EHR integration.
--  * Dates are ISO-8601 TEXT ('2026-10-01', '2026-10-01T09:05').
-- =====================================================================
PRAGMA foreign_keys = ON;

-- ---------- Reference / people ------------------------------------------

-- FHIR: Organization
CREATE TABLE agency (
  agency_id     INTEGER PRIMARY KEY,
  name          TEXT NOT NULL
);

-- FHIR: Practitioner (nurses, physicians, therapists)
CREATE TABLE clinician (
  clinician_id  INTEGER PRIMARY KEY,
  agency_id     INTEGER REFERENCES agency(agency_id),
  full_name     TEXT NOT NULL,
  credential    TEXT,            -- RN, LPN, PT, MD ...
  role          TEXT NOT NULL CHECK (role IN ('nurse','physician','therapist','aide','other')),
  specialty     TEXT,
  phone         TEXT
);

-- FHIR: Patient
CREATE TABLE patient (
  patient_id     INTEGER PRIMARY KEY,
  mrn            TEXT NOT NULL UNIQUE,
  first_name     TEXT NOT NULL,
  middle_initial TEXT,
  last_name      TEXT NOT NULL,
  dob            TEXT NOT NULL,
  sex            TEXT CHECK (sex IN ('F','M','X','U')),
  address        TEXT,
  phone          TEXT,
  living_situation TEXT,          -- "Lives with daughter"
  code_status    TEXT CHECK (code_status IN ('Full Code','DNR','DNI','Comfort Care')),
  payer          TEXT,
  primary_physician_id INTEGER REFERENCES clinician(clinician_id)
);

-- FHIR: RelatedPerson
CREATE TABLE caregiver (
  caregiver_id  INTEGER PRIMARY KEY,
  patient_id    INTEGER NOT NULL REFERENCES patient(patient_id),
  full_name     TEXT NOT NULL,
  relationship  TEXT,
  phone         TEXT,
  is_primary    INTEGER NOT NULL DEFAULT 0,
  availability  TEXT                -- "Works days; pt alone 8a–5p"
);

-- FHIR: AllergyIntolerance
CREATE TABLE allergy (
  allergy_id    INTEGER PRIMARY KEY,
  patient_id    INTEGER NOT NULL REFERENCES patient(patient_id),
  substance     TEXT NOT NULL,
  reaction      TEXT
);

-- FHIR: Condition
CREATE TABLE diagnosis (
  diagnosis_id  INTEGER PRIMARY KEY,
  patient_id    INTEGER NOT NULL REFERENCES patient(patient_id),
  icd10_code    TEXT NOT NULL,
  description   TEXT NOT NULL,
  is_primary    INTEGER NOT NULL DEFAULT 0,
  onset_date    TEXT
);

-- ---------- Episode of care ---------------------------------------------

-- FHIR: EpisodeOfCare (a 60-day Medicare certification period)
CREATE TABLE episode (
  episode_id     INTEGER PRIMARY KEY,
  patient_id     INTEGER NOT NULL REFERENCES patient(patient_id),
  agency_id      INTEGER REFERENCES agency(agency_id),
  cert_start     TEXT NOT NULL,
  cert_end       TEXT NOT NULL,
  soc_date       TEXT,              -- start of care
  status         TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','discharged','transferred')),
  discharge_plan TEXT
);

-- Ordered visit frequencies per discipline ("SN 2w3, 1w3")
CREATE TABLE discipline_order (
  order_id      INTEGER PRIMARY KEY,
  episode_id    INTEGER NOT NULL REFERENCES episode(episode_id),
  discipline    TEXT NOT NULL CHECK (discipline IN ('SN','PT','OT','ST','MSW','HHA')),
  frequency     TEXT NOT NULL,      -- free text in standard notation
  total_visits  INTEGER
);

-- FHIR: Goal
CREATE TABLE care_goal (
  goal_id       INTEGER PRIMARY KEY,
  episode_id    INTEGER NOT NULL REFERENCES episode(episode_id),
  description   TEXT NOT NULL,
  target_date   TEXT
);

-- ---------- The visit (the form itself) ---------------------------------

-- FHIR: Encounter
CREATE TABLE visit (
  visit_id       INTEGER PRIMARY KEY,
  episode_id     INTEGER NOT NULL REFERENCES episode(episode_id),
  clinician_id   INTEGER NOT NULL REFERENCES clinician(clinician_id),
  visit_date     TEXT NOT NULL,
  time_in        TEXT,
  time_out       TEXT,
  visit_type     TEXT NOT NULL,     -- 'Routine SN', 'SOC', 'Recert', 'PRN', 'Discharge'
  visit_number   INTEGER,           -- 4 (of discipline_order.total_visits)
  homebound_narrative TEXT,
  next_visit_date TEXT,
  next_visit_plan TEXT,
  patient_instructions TEXT,
  status         TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','in_review','signed')),
  signed_at      TEXT,
  late_entry     INTEGER NOT NULL DEFAULT 0
);

-- Checkbox-style homebound criteria, one row per checked reason
CREATE TABLE homebound_reason (
  visit_id      INTEGER NOT NULL REFERENCES visit(visit_id),
  reason        TEXT NOT NULL,      -- 'assistive_device','dyspnea_exertion','taxing_effort',...
  PRIMARY KEY (visit_id, reason)
);

-- FHIR: Observation (vital-signs category). One row per measurement
-- so new vital types need no schema change and trends are a simple query.
CREATE TABLE vital_sign (
  vital_id      INTEGER PRIMARY KEY,
  visit_id      INTEGER NOT NULL REFERENCES visit(visit_id),
  vital_type    TEXT NOT NULL CHECK (vital_type IN
                  ('bp_systolic','bp_diastolic','heart_rate','resp_rate','temp',
                   'spo2','weight','blood_glucose','pain_score')),
  value_num     REAL NOT NULL,
  unit          TEXT,              -- mmHg, bpm, /min, F, %, lb, mg/dL, 0-10
  position      TEXT,              -- sitting / standing / lying (BP)
  site          TEXT,              -- L arm, oral, apical ...
  qualifier     TEXT,              -- 'RA', 'regular', 'pt log'
  measured_at   TEXT
);

-- FHIR: Observation (exam). One row per body system per visit.
CREATE TABLE system_assessment (
  assessment_id INTEGER PRIMARY KEY,
  visit_id      INTEGER NOT NULL REFERENCES visit(visit_id),
  body_system   TEXT NOT NULL CHECK (body_system IN
                  ('cardiovascular','respiratory','neuro_cognitive','gi_nutrition',
                   'gu','integumentary','musculoskeletal','psychosocial','pain')),
  findings      TEXT NOT NULL,
  abnormal      INTEGER NOT NULL DEFAULT 0,
  UNIQUE (visit_id, body_system)
);

-- Scored tools: MAHC-10 fall risk, Braden, PHQ-2 ...
CREATE TABLE assessment_score (
  visit_id      INTEGER NOT NULL REFERENCES visit(visit_id),
  instrument    TEXT NOT NULL,      -- 'MAHC-10','Braden','PHQ-2'
  score         INTEGER NOT NULL,
  interpretation TEXT,
  PRIMARY KEY (visit_id, instrument)
);

CREATE TABLE home_safety_item (
  visit_id      INTEGER NOT NULL REFERENCES visit(visit_id),
  item          TEXT NOT NULL,      -- 'clear_pathways','grab_bars','night_lights',...
  in_place      INTEGER NOT NULL,   -- 1 = yes, 0 = needs attention
  note          TEXT,
  PRIMARY KEY (visit_id, item)
);

-- ---------- Wounds (persist across visits) ------------------------------

-- FHIR: Condition (wound) + BodyStructure
CREATE TABLE wound (
  wound_id      INTEGER PRIMARY KEY,
  patient_id    INTEGER NOT NULL REFERENCES patient(patient_id),
  wound_number  INTEGER NOT NULL,
  wound_type    TEXT NOT NULL,      -- venous ulcer, pressure injury, surgical ...
  location      TEXT NOT NULL,
  stage         TEXT,
  identified_date TEXT,
  healed_date   TEXT,
  UNIQUE (patient_id, wound_number)
);

-- FHIR: Observation + Procedure. One row per wound per visit.
CREATE TABLE wound_assessment (
  wound_assessment_id INTEGER PRIMARY KEY,
  wound_id      INTEGER NOT NULL REFERENCES wound(wound_id),
  visit_id      INTEGER NOT NULL REFERENCES visit(visit_id),
  length_cm     REAL,
  width_cm      REAL,
  depth_cm      REAL,
  wound_bed     TEXT,
  exudate       TEXT,
  periwound     TEXT,
  odor_infection TEXT,
  treatment     TEXT,
  next_dressing_change TEXT,
  UNIQUE (wound_id, visit_id)
);

-- ---------- Medications --------------------------------------------------

-- FHIR: MedicationRequest (the active med list)
CREATE TABLE medication (
  medication_id INTEGER PRIMARY KEY,
  patient_id    INTEGER NOT NULL REFERENCES patient(patient_id),
  name          TEXT NOT NULL,
  dose          TEXT NOT NULL,
  route         TEXT NOT NULL,
  frequency     TEXT NOT NULL,
  is_prn        INTEGER NOT NULL DEFAULT 0,
  start_date    TEXT,
  end_date      TEXT,
  ordered_by_id INTEGER REFERENCES clinician(clinician_id)
);

-- FHIR: MedicationStatement — what reconciliation found this visit
CREATE TABLE med_reconciliation (
  visit_id      INTEGER NOT NULL REFERENCES visit(visit_id),
  medication_id INTEGER NOT NULL REFERENCES medication(medication_id),
  status        TEXT NOT NULL CHECK (status IN ('taking','not_taking','partial','prn','discrepancy')),
  note          TEXT,
  PRIMARY KEY (visit_id, medication_id)
);

-- ---------- Interventions, teaching, goals, coordination ----------------

-- FHIR: Procedure
CREATE TABLE intervention (
  visit_id      INTEGER NOT NULL REFERENCES visit(visit_id),
  intervention  TEXT NOT NULL,      -- 'cardiopulmonary_assessment','wound_care','med_reconciliation',...
  PRIMARY KEY (visit_id, intervention)
);

CREATE TABLE teaching (
  teaching_id   INTEGER PRIMARY KEY,
  visit_id      INTEGER NOT NULL REFERENCES visit(visit_id),
  taught_to     TEXT NOT NULL,      -- 'patient', 'patient + daughter (phone)'
  topics        TEXT NOT NULL,
  teach_back    TEXT,               -- response / comprehension
  needs_reinforcement INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE goal_progress (
  visit_id      INTEGER NOT NULL REFERENCES visit(visit_id),
  goal_id       INTEGER NOT NULL REFERENCES care_goal(goal_id),
  progress      TEXT NOT NULL CHECK (progress IN ('met','progressing','not_met','at_risk')),
  comment       TEXT,
  PRIMARY KEY (visit_id, goal_id)
);

-- FHIR: Communication. Time-stamped log of calls/messages.
CREATE TABLE care_coordination (
  coordination_id INTEGER PRIMARY KEY,
  visit_id      INTEGER NOT NULL REFERENCES visit(visit_id),
  occurred_at   TEXT NOT NULL,
  contact_with  TEXT NOT NULL,      -- "Dr. X's office (RN)", "PT"
  summary       TEXT NOT NULL
);

-- FHIR: MedicationRequest/ServiceRequest received during the visit
CREATE TABLE new_order (
  new_order_id  INTEGER PRIMARY KEY,
  coordination_id INTEGER REFERENCES care_coordination(coordination_id),
  visit_id      INTEGER NOT NULL REFERENCES visit(visit_id),
  order_text    TEXT NOT NULL,
  ordered_by_id INTEGER REFERENCES clinician(clinician_id),
  read_back_verified INTEGER NOT NULL DEFAULT 0
);

-- ---------- Voice-note pipeline ------------------------------------------

-- Raw dictation as captured on the nurse's device.
CREATE TABLE voice_note (
  voice_note_id INTEGER PRIMARY KEY,
  visit_id      INTEGER REFERENCES visit(visit_id),   -- may be linked after capture
  clinician_id  INTEGER NOT NULL REFERENCES clinician(clinician_id),
  recorded_at   TEXT NOT NULL,
  audio_uri     TEXT,                 -- path/URL to audio file
  duration_sec  INTEGER,
  transcript    TEXT,
  transcription_status TEXT NOT NULL DEFAULT 'pending'
                CHECK (transcription_status IN ('pending','done','failed')),
  extraction_status TEXT NOT NULL DEFAULT 'pending'
                CHECK (extraction_status IN ('pending','done','failed','reviewed'))
);

-- Every value the AI pulled from a transcript, with provenance, so the
-- nurse reviews before it is written into the chart tables above.
CREATE TABLE extracted_field (
  extracted_field_id INTEGER PRIMARY KEY,
  voice_note_id INTEGER NOT NULL REFERENCES voice_note(voice_note_id),
  target_table  TEXT NOT NULL,        -- 'vital_sign', 'system_assessment', ...
  target_field  TEXT NOT NULL,        -- 'weight', 'cardiovascular', ...
  proposed_value TEXT NOT NULL,
  source_text   TEXT,                 -- transcript snippet it came from
  confidence    REAL,                 -- 0–1
  review_status TEXT NOT NULL DEFAULT 'pending'
                CHECK (review_status IN ('pending','accepted','edited','rejected')),
  final_value   TEXT,
  reviewed_at   TEXT
);

-- ---------- Indexes & helper views --------------------------------------

CREATE INDEX ix_visit_episode     ON visit(episode_id, visit_date);
CREATE INDEX ix_vital_visit_type  ON vital_sign(visit_id, vital_type);
CREATE INDEX ix_woundassess_wound ON wound_assessment(wound_id);
CREATE INDEX ix_extracted_note    ON extracted_field(voice_note_id, review_status);

-- Weight trend per patient (drives the "▲2.6 lb" flag on the form)
CREATE VIEW v_weight_trend AS
SELECT e.patient_id, v.visit_id, v.visit_date, vs.value_num AS weight_lb,
       vs.value_num - LAG(vs.value_num) OVER (PARTITION BY e.patient_id ORDER BY v.visit_date)
         AS change_lb
FROM vital_sign vs
JOIN visit v   ON v.visit_id = vs.visit_id
JOIN episode e ON e.episode_id = v.episode_id
WHERE vs.vital_type = 'weight';

-- Wound size trend (area in cm²)
CREATE VIEW v_wound_trend AS
SELECT w.patient_id, w.wound_id, w.wound_number, v.visit_date,
       wa.length_cm, wa.width_cm, wa.depth_cm,
       ROUND(wa.length_cm * wa.width_cm, 2) AS area_cm2
FROM wound_assessment wa
JOIN wound w ON w.wound_id = wa.wound_id
JOIN visit v ON v.visit_id = wa.visit_id;
