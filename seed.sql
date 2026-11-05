-- Seed data: the fictional sample patient from the visit-note mockup.
-- Run after schema.sql:  sqlite3 charting.db < seed.sql
PRAGMA foreign_keys = ON;

INSERT INTO agency (agency_id, name) VALUES (1, 'Sample Home Health');

INSERT INTO clinician (clinician_id, agency_id, full_name, credential, role, specialty) VALUES
 (1, 1, 'Sample Nurse',     'RN', 'nurse',     NULL),
 (2, NULL, 'Sample Cardiologist', 'MD', 'physician', 'Cardiology'),
 (3, 1, 'Sample Therapist', 'PT', 'therapist', NULL);

INSERT INTO patient (patient_id, mrn, first_name, middle_initial, last_name, dob, sex,
                     address, living_situation, code_status, payer, primary_physician_id)
VALUES (1, 'HH-0042817', 'Dorothy', 'M', 'Alvarez', '1948-03-14', 'F',
        '[Street address], [City, State ZIP]', 'Lives with daughter', 'Full Code', 'Medicare Part A', 2);

INSERT INTO caregiver (patient_id, full_name, relationship, is_primary, availability)
VALUES (1, '[Daughter name]', 'Daughter', 1, 'Works days; patient alone 8a–5p');

INSERT INTO allergy (patient_id, substance, reaction) VALUES
 (1, 'Sulfa', 'Rash'),
 (1, 'Latex', NULL);

INSERT INTO diagnosis (patient_id, icd10_code, description, is_primary) VALUES
 (1, 'I50.33',  'Acute on chronic diastolic heart failure', 1),
 (1, 'E11.9',   'Type 2 diabetes mellitus', 0),
 (1, 'I10',     'Essential hypertension', 0),
 (1, 'I83.012', 'Varicose veins of right lower extremity with ulcer of calf', 0);

INSERT INTO episode (episode_id, patient_id, agency_id, cert_start, cert_end, soc_date, discharge_plan)
VALUES (1, 1, 1, '2026-09-18', '2026-11-16', '2026-09-18',
        'Discharge to self-care with daughter support when goals met; est. end of cert period.');

INSERT INTO discipline_order (episode_id, discipline, frequency, total_visits) VALUES
 (1, 'SN',  '2w3, 1w3', 9),
 (1, 'PT',  '2w4',      8),
 (1, 'HHA', '1w4',      4);

INSERT INTO care_goal (goal_id, episode_id, description, target_date) VALUES
 (1, 1, 'Patient will verbalize 3 CHF symptoms requiring MD contact', '2026-10-09'),
 (2, 1, 'Patient will weigh daily and log results',                  '2026-10-09'),
 (3, 1, 'Wound size decreases 25% from SOC',                          '2026-10-30'),
 (4, 1, 'No ED visit or rehospitalization this episode',              '2026-11-16');

INSERT INTO wound (wound_id, patient_id, wound_number, wound_type, location, identified_date)
VALUES (1, 1, 1, 'Venous ulcer', 'R posterior calf', '2026-09-18');

INSERT INTO medication (medication_id, patient_id, name, dose, route, frequency, is_prn, ordered_by_id) VALUES
 (1, 1, 'Furosemide',            '40 mg',  'PO', 'daily',  0, 2),
 (2, 1, 'Metoprolol succinate',  '50 mg',  'PO', 'daily',  0, 2),
 (3, 1, 'Lisinopril',            '10 mg',  'PO', 'daily',  0, 2),
 (4, 1, 'Metformin',             '500 mg', 'PO', 'BID',    0, 2),
 (5, 1, 'Potassium chloride ER', '20 mEq', 'PO', 'daily',  0, 2),
 (6, 1, 'Acetaminophen',         '650 mg', 'PO', 'q6h PRN',1, 2);

-- ---- Prior visit (09/29) — minimal, so trends have something to compare
INSERT INTO visit (visit_id, episode_id, clinician_id, visit_date, time_in, time_out,
                   visit_type, visit_number, status, signed_at)
VALUES (3, 1, 1, '2026-09-29', '13:10', '14:05', 'Routine SN', 3, 'signed', '2026-09-29T14:30');
INSERT INTO vital_sign (visit_id, vital_type, value_num, unit) VALUES (3, 'weight', 168.8, 'lb');
INSERT INTO system_assessment (visit_id, body_system, findings, abnormal)
VALUES (3, 'cardiovascular', '+1 pitting edema bilateral ankles', 1);
INSERT INTO wound_assessment (wound_id, visit_id, length_cm, width_cm, depth_cm)
VALUES (1, 3, 3.0, 2.0, 0.2);

-- ---- Today's visit (10/01) — the form
INSERT INTO visit (visit_id, episode_id, clinician_id, visit_date, time_in, time_out,
                   visit_type, visit_number, homebound_narrative, next_visit_date, next_visit_plan,
                   patient_instructions, status, signed_at)
VALUES (4, 1, 1, '2026-10-01', '09:05', '10:10', 'Routine SN', 4,
        'Absences limited to medical appointments (cardiology 09/25). Ambulates ~25 ft with rolling walker before resting.',
        '2026-10-03', 'Wound care, weight/edema recheck, draw BMP.',
        'Call agency 24/7 line for wt gain > 2 lb overnight, increased SOB, or chest pain. Call 911 for severe SOB.',
        'signed', '2026-10-01T10:31');

INSERT INTO homebound_reason (visit_id, reason) VALUES
 (4, 'assistive_device'), (4, 'dyspnea_exertion'), (4, 'taxing_effort');

INSERT INTO vital_sign (visit_id, vital_type, value_num, unit, position, site, qualifier) VALUES
 (4, 'bp_systolic',   138,   'mmHg',  'sitting',  'L arm', NULL),
 (4, 'bp_diastolic',  82,    'mmHg',  'sitting',  'L arm', NULL),
 (4, 'bp_systolic',   130,   'mmHg',  'standing', 'L arm', NULL),
 (4, 'bp_diastolic',  78,    'mmHg',  'standing', 'L arm', NULL),
 (4, 'heart_rate',    84,    'bpm',   NULL,       'apical','regular'),
 (4, 'resp_rate',     20,    '/min',  NULL,       NULL,    NULL),
 (4, 'temp',          98.2,  'F',     NULL,       'oral',  NULL),
 (4, 'spo2',          94,    '%',     NULL,       NULL,    'RA'),
 (4, 'weight',        171.4, 'lb',    NULL,       NULL,    NULL),
 (4, 'blood_glucose', 146,   'mg/dL', NULL,       NULL,    'pt log, AM'),
 (4, 'pain_score',    3,     '0-10',  NULL,       'R calf wound', 'aching; relieved with elevation');

INSERT INTO system_assessment (visit_id, body_system, findings, abnormal) VALUES
 (4, 'cardiovascular',  'S1 S2 regular. +2 pitting edema bilateral ankles (was +1 on 09/29). Pedal pulses +2. Cap refill < 3 sec. Denies chest pain, palpitations.', 1),
 (4, 'respiratory',     'Fine crackles bilateral bases. DOE after ~25 ft; sleeping on 2 pillows (was 1). No cough. No O2 in home.', 1),
 (4, 'neuro_cognitive', 'A&O x4. Speech clear. Follows multi-step commands.', 0),
 (4, 'gi_nutrition',    'Appetite fair. Abdomen soft, non-tender, BS active x4. Last BM 09/30. Canned soup 3x this week (high sodium).', 1),
 (4, 'gu',              'Continent. Voiding without difficulty, nocturia x3.', 0),
 (4, 'integumentary',   'Skin warm, dry, intact except wound #1.', 0),
 (4, 'musculoskeletal', 'Generalized weakness; gait steady with rolling walker. Transfers with standby assist.', 0),
 (4, 'psychosocial',    'Daughter is primary caregiver, works days. Worried about rehospitalization.', 0);

INSERT INTO assessment_score (visit_id, instrument, score, interpretation) VALUES
 (4, 'MAHC-10', 6,  'High fall risk'),
 (4, 'Braden',  18, 'Mild risk'),
 (4, 'PHQ-2',   1,  'Negative screen');

INSERT INTO home_safety_item (visit_id, item, in_place, note) VALUES
 (4, 'clear_pathways',       1, NULL),
 (4, 'grab_bars',            1, NULL),
 (4, 'night_lights',         0, 'Recommended bedroom to bathroom'),
 (4, 'smoke_detector',       1, NULL),
 (4, 'emergency_plan',       1, NULL),
 (4, 'throw_rugs_removed',   0, 'Hallway rug; daughter to remove today'),
 (4, 'meds_stored_safely',   1, NULL);

INSERT INTO wound_assessment (wound_id, visit_id, length_cm, width_cm, depth_cm, wound_bed, exudate,
                              periwound, odor_infection, treatment, next_dressing_change)
VALUES (1, 4, 2.8, 1.9, 0.2, '80% granular, 20% slough', 'Moderate serous',
        'Hemosiderin staining, no maceration', 'None noted',
        'Cleansed with NS. Skin prep to periwound. Calcium alginate to bed, foam border dressing.',
        '2026-10-03');

INSERT INTO med_reconciliation (visit_id, medication_id, status, note) VALUES
 (4, 1, 'discrepancy', 'Skipped 9/29 & 9/30 to avoid bathroom trips while alone'),
 (4, 2, 'taking',      'HR 84, within hold parameters'),
 (4, 3, 'taking',      NULL),
 (4, 4, 'taking',      'With meals'),
 (4, 5, 'taking',      NULL),
 (4, 6, 'prn',         'None taken past 48 h');

INSERT INTO intervention (visit_id, intervention) VALUES
 (4, 'cardiopulmonary_assessment'), (4, 'wound_care'), (4, 'med_reconciliation'),
 (4, 'disease_mgmt_teaching'), (4, 'physician_notified');

INSERT INTO teaching (visit_id, taught_to, topics, teach_back, needs_reinforcement) VALUES
 (4, 'Patient and daughter (phone)',
  'Daily weights; 2 lb/day or 5 lb/week rule; low-sodium choices; morning diuretic timing; CHF red-zone symptoms',
  'Correctly stated when to call agency; needs reinforcement reading sodium on labels', 1);

INSERT INTO goal_progress (visit_id, goal_id, progress, comment) VALUES
 (4, 1, 'met',         'Stated wt gain, SOB, swelling'),
 (4, 2, 'progressing', 'Missed 1 day this week'),
 (4, 3, 'progressing', '~13% reduction since SOC'),
 (4, 4, 'at_risk',     'Wt gain + missed diuretic');

INSERT INTO care_coordination (coordination_id, visit_id, occurred_at, contact_with, summary) VALUES
 (1, 4, '2026-10-01T09:52', 'Cardiologist office (RN)',
  'Reported 2.6 lb wt gain in 48 h, +2 edema, crackles, missed furosemide.'),
 (2, 4, '2026-10-01T10:05', 'PT',
  'Message left re: fatigue — adjust session intensity.');

INSERT INTO new_order (coordination_id, visit_id, order_text, ordered_by_id, read_back_verified) VALUES
 (1, 4, 'Furosemide 40 mg PO BID x 3 days, then resume daily. BMP on 10/03.', 2, 1);

-- ---- Example voice note feeding the pipeline
INSERT INTO voice_note (voice_note_id, visit_id, clinician_id, recorded_at, duration_sec, transcript,
                        transcription_status, extraction_status)
VALUES (1, 4, 1, '2026-10-01T10:12', 48,
 'Weight today one seventy-one point four, up about two and a half pounds since Monday. Plus-two pitting edema both ankles, was plus-one. Crackles at both bases. She says she skipped her Lasix Monday and Tuesday so she would not have to keep getting up while her daughter is at work.',
 'done', 'reviewed');

INSERT INTO extracted_field (voice_note_id, target_table, target_field, proposed_value, source_text,
                             confidence, review_status, final_value, reviewed_at) VALUES
 (1, 'vital_sign',         'weight',          '171.4 lb',
  'one seventy-one point four', 0.97, 'accepted', '171.4 lb', '2026-10-01T10:25'),
 (1, 'system_assessment',  'cardiovascular',  '+2 pitting edema bilateral ankles (was +1)',
  'Plus-two pitting edema both ankles, was plus-one', 0.93, 'accepted', NULL, '2026-10-01T10:25'),
 (1, 'system_assessment',  'respiratory',     'Fine crackles bilateral bases',
  'Crackles at both bases', 0.88, 'edited', 'Fine crackles bilateral bases', '2026-10-01T10:25'),
 (1, 'med_reconciliation', 'furosemide',      'discrepancy: skipped 9/29 & 9/30',
  'skipped her Lasix Monday and Tuesday', 0.91, 'accepted', NULL, '2026-10-01T10:25');
