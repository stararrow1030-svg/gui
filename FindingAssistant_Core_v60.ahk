
global gCoreVersion := "v60"

; ===== Included: FindingAssistant_MAP_v31_module (inlined) =====
; ============================================================================================
; FindingAssistant MAP v3.1
; Deterministic FINDINGS generator using structured section mapping
; No LLM required - pure dictionary lookup with sectioned output
;
; v3.1 Changes:
;   - Noun-phrase finding map integrated (no more "is noted" / "are noted" in map outputs)
;   - Header auto-parse block reviewed & bug-fixed:
;       • Fixed regex escaping in DetectContrastFromTitle (with/?without)
;       • Fixed for-loop syntax for AHKv2 array enumeration
;       • Added "Post-contrast only" to contrast dropdown
;       • Wired BuildStudyHeader into BtnGenerate output
;   - Expanded mediastinal lymph node mappings in chest CT map
; ============================================================================================

; -------- CONFIG --------
; MapDir and all map file paths are injected externally by FindingAssistant_Hotkeys.ahk
; (via FA_runner.ahk #Include order). Core only sets non-path defaults here.
; A_LineFile-based fallback keeps Core runnable standalone during development.
CFG := Map()
CFG["Backend"] := "MAP"                 ; Use deterministic mapping (no LLM)
CFG["ShowUnmatched"] := false           ; [v34] Clinical mode: suppress unmatched UI block
CFG["AutoCopyToClipboard"] := true      ; Auto copy result to clipboard

; Safety fallback: if MapDir was not injected, default to Core's own folder.
if !CFG.Has("MapDir") || CFG["MapDir"] = "" {
    CFG["MapDir"] := SubStr(A_LineFile, 1, InStr(A_LineFile, "\",, -1) - 1)
}
_md := CFG["MapDir"]
if !CFG.Has("ChestMapFile")        CFG["ChestMapFile"]        := _md "\map_chest_v3.txt"
if !CFG.Has("ChestSynFile")        CFG["ChestSynFile"]        := _md "\synonym_map_v3.txt"
if !CFG.Has("CTAAortaMapFile")     CFG["CTAAortaMapFile"]     := _md "\finding_map_cta_aorta_current.txt"
if !CFG.Has("BrainMapFile")        CFG["BrainMapFile"]        := _md "\finding_map_brain_ct_current.txt"
if !CFG.Has("CTAHeadNeckMapFile")  CFG["CTAHeadNeckMapFile"]  := _md "\finding_map_cta_headneck_current.txt"
if !CFG.Has("FacialCTMapFile")     CFG["FacialCTMapFile"]     := _md "\finding_map_facial_ct_current.txt"
if !CFG.Has("BrainMRIMapFile")     CFG["BrainMRIMapFile"]     := _md "\finding_map_brain_mri_current.txt"
if !CFG.Has("AbdomenMapFile")      CFG["AbdomenMapFile"]      := _md "\finding_map_abdomen_ct_current.txt"
if !CFG.Has("AbdomenMRIMapFile")   CFG["AbdomenMRIMapFile"]   := _md "\finding_map_abdomen_mri_current.txt"
if !CFG.Has("PelvisCTMapFile")     CFG["PelvisCTMapFile"]     := _md "\finding_map_pelvis_ct_current.txt"
if !CFG.Has("CSpineCTMapFile")     CFG["CSpineCTMapFile"]     := _md "\finding_map_cspine_ct_current.txt"
if !CFG.Has("SpineMRIMapFile")     CFG["SpineMRIMapFile"]     := _md "\finding_map_spine_mri_current.txt"
if !CFG.Has("ExtremityMRIMapFile") CFG["ExtremityMRIMapFile"] := _md "\finding_map_extremity_mri_current.txt"
if !CFG.Has("LegCTMapFile")        CFG["LegCTMapFile"]        := _md "\finding_map_leg_ct_current.txt"
if !CFG.Has("UniversalMapFile")    CFG["UniversalMapFile"]    := _md "\finding_map_universal.txt"

; ========================= EXAM REGISTRY (v50) =========================
; Central registry: adding a new exam type = add one block in BuildExamRegistry()
; + place the corresponding mapping .txt file in the script folder.
; Nothing else in the core engine needs to change.
;
; Required keys per entry:
;   mapFile        - path to .txt mapping file
;   sections       - array of section header strings (with trailing ":")
;   modality       - "CT" or "MR"  (for study header generation)
;   bodyPart       - canonical body-part string (for study header generation)
;   aliases        - lowercase body-part synonyms used by MapToExamType()
;   filterFn       - FilterBullet_Xxx function ref, or "" for no filter
;   heuristicFn    - HeuristicRoutes_Xxx function ref, or "" for none
;   defaultContent - written to mapFile when it is missing ("" = leave empty)
;   synFile        - synonym .txt file path, or "" for none
;   useRouter      - true = GenerateFindings_Router; false = MAP/dictionary engine
; =======================================================================
global ExamRegistry := Map()   ; populated by BuildExamRegistry() at startup

; =======================================================================
; Helper: construct a registry entry Map (AHK v2 does NOT allow nested functions)
; =======================================================================
MakeExamRegistryEntry(mapFile, sections, modality, bodyPart, aliases
    , filterFn := "", heuristicFn := "", defaultContent := "", synFile := "", useRouter := false) {
    r := Map()
    r["mapFile"]        := mapFile
    r["sections"]       := sections
    r["modality"]       := modality
    r["bodyPart"]       := bodyPart
    r["aliases"]        := aliases
    r["filterFn"]       := filterFn
    r["heuristicFn"]    := heuristicFn
    r["defaultContent"] := defaultContent
    r["synFile"]        := synFile
    r["useRouter"]      := useRouter      ; true = Router; false = MAP engine
    return r
}

BuildExamRegistry() {
    global ExamRegistry, CFG


    ; ─── Chest CT ─────────────────────────────────────────────────────────────
    ExamRegistry["Chest CT"] := MakeExamRegistryEntry(
        CFG["ChestMapFile"],
        ["Lung parenchyma:", "Airways:", "Pleura:", "Mediastinum and lymph nodes:",
         "Heart and vessels:", "Thyroid gland:", "Liver:", "Biliary system and pancreas:",
         "Spleen:", "Adrenal glands:", "Kidneys:", "Osseous and soft tissues:", "Others:"],
        "CT", "Chest", ["chest", "thorax", "lung"],
        FilterBullet_ChestCT, HeuristicRoutes_ChestCT, "", CFG["ChestSynFile"], true)
    ; [v58] Auto-impression control
    ExamRegistry["Chest CT"]["enableAutoImpression"] := true
    ExamRegistry["Chest CT"]["defaultNegativeImpression"] := "No acute cardiopulmonary finding."


    ; ─── CTA Aorta / Great Vessels ────────────────────────────────────────────
    ExamRegistry["CTA Aorta / Great Vessels"] := MakeExamRegistryEntry(
        CFG["CTAAortaMapFile"],
        ["Thoracic aorta:", "Arch and great vessels:", "Abdominal aorta:",
         "Branch vessels:", "Pulmonary arteries:", "Mediastinum/hemorrhage:"],
        "CT", "CTA Aorta", ["aorta"],
        FilterBullet_CTAAorta, HeuristicRoutes_CTAAorta, "", "", true)

    ; ─── Brain CT ─────────────────────────────────────────────────────────────
    ExamRegistry["Brain CT"] := MakeExamRegistryEntry(
        CFG["BrainMapFile"],
        ["Brain parenchyma:", "Ventricular system:", "Extra-axial spaces:",
         "Basal cisterns:","Cerebral vasculature:",
         "Calvarium and skull base:", "Paranasal sinuses and mastoid air cells:",
         "Ocular / Others:"],
        "CT", "Brain", ["brain", "head", "intracranial"],
        FilterBullet_BrainCT, HeuristicRoutes_BrainCT,
        "# Brain CT mapping template`nhypodense area => Brain parenchyma: | A hypodense area is noted.`neffacement of the basal cisterns => Basal cisterns: | Effacement of the basal cisterns is noted.`n",
        "", true)
    ; [v58] Auto-impression control
    ExamRegistry["Brain CT"]["enableAutoImpression"] := true
    ExamRegistry["Brain CT"]["defaultNegativeImpression"] := "No definite evidence of intracranial lesion."


    ; ─── CTA Head & Neck ──────────────────────────────────────────────────────
    ExamRegistry["CTA Head & Neck"] := MakeExamRegistryEntry(
        CFG["CTAHeadNeckMapFile"],
        ["Intracranial arteries:", "Extracranial carotid and vertebral arteries:", "Venous sinuses:"],
        "CT", "CTA Head and Neck", ["carotid", "vertebral"],
        FilterBullet_CTAHeadNeck, HeuristicRoutes_CTAHeadNeck, "", "", true)

    ; ─── Facial Bone CT ───────────────────────────────────────────────────────
    ExamRegistry["Facial Bone CT"] := MakeExamRegistryEntry(
        CFG["FacialCTMapFile"],
        ["Facial bones:", "Orbits:", "Paranasal sinuses:", "Nasal cavity:", "Soft tissues:"],
        "CT", "Facial Bone", ["face", "facial"],
        FilterBullet_FacialCT, HeuristicRoutes_FacialCT, "", "", true)

    ; ─── Brain MRI ────────────────────────────────────────────────────────────
    ExamRegistry["Brain MRI"] := MakeExamRegistryEntry(
        CFG["BrainMRIMapFile"],
        ["Brain parenchyma:", "DWI/ADC:", "Post-contrast enhancement:",
         "Ventricular system:", "Extra-axial spaces:", "Basal cisterns:",
         "Intracranial hemorrhage:", "Cerebral vasculature:",
         "Calvarium and skull base:", "Paranasal sinuses and mastoid air cells:"],
        "MR", "Brain", [],
        FilterBullet_BrainMRI, HeuristicRoutes_BrainMRI, "", "", true)

    ; ─── Abdomen CT ───────────────────────────────────────────────────────────
    ExamRegistry["Abdomen CT"] := MakeExamRegistryEntry(
        CFG["AbdomenMapFile"],
        ["Liver:", "Biliary system:", "Pancreas:", "Spleen:",
         "Adrenal glands:", "Urinary system:",
         "GI tract:", "Vessels and lymph nodes:",
         "Peritoneum/ascites:", "Reproductive system:", "Osseous and soft tissues:", "Others:"],
        "CT", "Abdomen", ["abdomen", "abdominal"],
        FilterBullet_AbdomenCT, HeuristicRoutes_AbdomenCT, "", "", true)

    ; ─── Abdomen MRI ──────────────────────────────────────────────────────────
    ExamRegistry["Abdomen MRI"] := MakeExamRegistryEntry(
        CFG["AbdomenMRIMapFile"],
        ["Liver:", "Biliary system:", "Pancreas:", "Spleen:",
         "Adrenal glands:", "Urinary system:",
         "GI tract:", "Vessels and lymph nodes:",
         "Peritoneum/ascites:", "Reproductive system:", "Osseous and soft tissues:", "Others:"],
        "MR", "Abdomen", [],
        FilterBullet_AbdomenCT, HeuristicRoutes_AbdomenCT, "", "", true)

    ; ─── Pelvis CT ────────────────────────────────────────────────────────────
    ExamRegistry["Pelvis CT"] := MakeExamRegistryEntry(
        CFG["PelvisCTMapFile"],
        ["Pelvic ring:", "Acetabulum and hip joints:", "Sacrum and coccyx:",
         "Sacroiliac joints:", "Soft tissues:"],
        "CT", "Pelvis", ["pelvis"],
        FilterBullet_PelvisCT, HeuristicRoutes_PelvisCT, "", "", true)

    ; ─── Cervical Spine CT ────────────────────────────────────────────────────
    ExamRegistry["Cervical Spine CT"] := MakeExamRegistryEntry(
        CFG["CSpineCTMapFile"],
        ["Alignment:", "Vertebral bodies:", "Posterior elements:",
         "Intervertebral disc spaces:", "Prevertebral soft tissues:", "Spinal canal:"],
        "CT", "Cervical Spine", ["neck", "cervical"],
        FilterBullet_CSpineCT, HeuristicRoutes_CSpineCT, "", "", true)

    ; ─── Spine MRI (split by level — same sections for all three) ────────────
    _spineSections := ["Alignment:", "Vertebral bodies:", "Intervertebral discs:",
                       "Spinal canal and cord:", "Neural foramina:", "Paraspinal soft tissues:"]
    ExamRegistry["C-spine MRI"] := MakeExamRegistryEntry(
        CFG["SpineMRIMapFile"], _spineSections,
        "MR", "C-spine", ["cervical spine", "c-spine"],
        FilterBullet_SpineMRI, HeuristicRoutes_SpineMRI, "", "", true)
    ExamRegistry["T-spine MRI"] := MakeExamRegistryEntry(
        CFG["SpineMRIMapFile"], _spineSections,
        "MR", "T-spine", ["thoracic spine", "t-spine"],
        FilterBullet_SpineMRI, HeuristicRoutes_SpineMRI, "", "", true)
    ExamRegistry["L-spine MRI"] := MakeExamRegistryEntry(
        CFG["SpineMRIMapFile"], _spineSections,
        "MR", "L-spine", ["lumbar spine", "lumbosacral spine", "l-spine"],
        FilterBullet_SpineMRI, HeuristicRoutes_SpineMRI, "", "", true)
    ; [v58] Auto-impression control
    ExamRegistry["L-spine MRI"]["enableAutoImpression"] := true
    ExamRegistry["L-spine MRI"]["defaultNegativeImpression"] := "No significant central canal or foraminal stenosis."


    ; ─── Extremity MRI (Hip / Femur / Thigh / Leg) ────────────────────────────
    _extMRSections := ["Bones:", "Joints:", "Muscles and tendons:", "Ligaments:", "Neurovascular structures:", "Soft tissues:"]
    ExamRegistry["Extremity MRI"] := MakeExamRegistryEntry(
        CFG["ExtremityMRIMapFile"], _extMRSections,
        "MR", "Extremity", ["hip", "femur", "thigh", "leg", "calf", "lower extremity", "extremity"],
        FilterBullet_ExtremityMRI, HeuristicRoutes_ExtremityMRI,
        "; key = section`n; Example:`n; marrow edema = Bones:`njoint effusion = Joints:`nmuscle strain = Muscles and tendons:`nligament tear = Ligaments:`nnerve entrapment = Neurovascular structures:`nsoft tissue mass = Soft tissues:`n",
        "", true)

    ; ─── Leg CT ───────────────────────────────────────────────────────────────
    ExamRegistry["Leg CT"] := MakeExamRegistryEntry(
        CFG["LegCTMapFile"],
        ["Bones:", "Joints:", "Soft tissues:", "Vessels:"],
        "CT", "Leg", ["leg", "lower"],
        FilterBullet_LegCT, HeuristicRoutes_LegCT, ( "; key = section`n; Example: fracture = Bones:`nfracture = Bones:`ntibia = Bones:`nfibula = Bones:`nankle = Joints:`nknee = Joints:`nhematoma = Soft tissues:`nabscess = Soft tissues:`ncellulitis = Soft tissues:`ngas = Soft tissues:`nextravasation = Vessels:`n"),"" , true)

    ; ─── Universal (All Regions) ──────────────────────────────────────────────
    ExamRegistry["Universal (All Regions)"] := MakeExamRegistryEntry(
        CFG["UniversalMapFile"],
        ["Brain and skull:", "Orbits and paranasal sinuses:", "Neck:", "Thyroid gland:",
         "Lung parenchyma:", "Airways:", "Pleura:", "Mediastinum and lymph nodes:",
         "Heart and vessels:", "Liver:", "Gallbladder and bile ducts:", "Pancreas:",
         "Spleen:", "Adrenal glands:", "Kidneys and ureters:", "Urinary bladder:",
         "GI tract:", "Peritoneum/ascites:", "Pelvis and reproductive organs:",
         "Musculoskeletal:", "Soft tissues:"],
        "CT", "Whole Body", [],
        "", "", "", "", true)
}

BuildExamRegistry()   ; populate at startup

; =====================================================================

; Global state
gExamType := ""
gBulletText := ""
gReportMode := "General"          ; "General" or "Oncology"
gModeManual := false               ; true = user changed manually; suppress auto-detect
gClinicalText := ""               ; clinical information free text
gMainGui := ""
gExamChanging := false             ; [v56] guard flag for two-column exam selector

; ============================================================
;  Header Auto-Parse Block (PACS title → Dose/Contrast tags)
;  - Supports: Low-dose + LDCT tags, and contrast tags:
;      Auto / Non-enhanced / Post-contrast only / Pre- and post-contrast
;  - Output example:
;      Chest CT (Low-dose, LDCT, Non-enhanced), compared with prior (2026-02-12).
;
;  HOW TO USE (4 lines):
;    title := WinGetTitle("A")
;    gDoseTags := DetectDoseTagsFromTitle(title)
;    gAutoContrast := DetectContrastFromTitle(title)
;    header := BuildStudyHeader(modality, finalBodyPart, gContrastChoice, gHasPrior, gPriorDate, gDoseTags)
; ============================================================

; ---------- 1) Detect dose-related tags (Low-dose / LDCT) ----------
DetectDoseTagsFromTitle(title) {
    t := StrLower(title)
    tags := []
    ; Low-dose: "low dose" / "low-dose"
    if RegExMatch(t, "\blow[-\s]?dose\b")
        tags.Push("Low-dose")
    ; LDCT: "ldct" or screening phrases
    if RegExMatch(t, "\bldct\b|\blung\s*screen(ing)?\b|\blung\s*cancer\s*screen(ing)?\b")
        tags.Push("LDCT")
    return tags
}

; ---------- 2) Detect contrast tag from title ----------
; BUG FIX v3.1: Corrected regex -- AHKv2 uses "\" for literal chars,
;   but "/" does NOT need escaping. Changed "with\/?without" → "with/?without".
;   Also made patterns more robust with optional hyphens.
DetectContrastFromTitle(title) {
    t := StrLower(title)
    ; Most specific first: "with/without contrast" or "with and without contrast"
    ; Handle possible spaces around "/" and flexible patterns
    if RegExMatch(t, "with\s*/\s*without\s+contrast")
        return "Pre- and post-contrast"
    if RegExMatch(t, "with\s*(and|&)\s*without\s+contrast")
        return "Pre- and post-contrast"
    ; "without contrast" → Non-enhanced (must check BEFORE "with contrast")
    if RegExMatch(t, "without\s+contrast")
        return "Non-enhanced"
    ; "with contrast" → Post-contrast only
    if RegExMatch(t, "with\s+contrast")
        return "Post-contrast only"
    return "Auto"
}

; ---------- 3) Build header sentence ----------
; BUG FIX v3.1: Changed "for _, d in doseTags" → "for d in doseTags"
;   (AHKv2 array enumeration: "for value in arr" or "for idx, value in arr")
BuildStudyHeader(modality, bodyPart, contrastTag, hasPrior, priorDate, doseTags := "") {
    title := bodyPart . " " . modality
    tags := []
    ; doseTags: ["Low-dose","LDCT"]
    if IsObject(doseTags) {
        for d in doseTags {
            if (d != "")
                tags.Push(d)
        }
    }
    ; contrast tag (CT/MR only)
    if (modality = "CT" || modality = "MR") {
        if (contrastTag != "" && contrastTag != "Auto")
            tags.Push(contrastTag)
    }
    if (tags.Length)
        title .= " (" . StrJoin(", ", tags*) . ")"
    if (hasPrior) {
        if (priorDate != "")
            title .= ", compared with prior (" . priorDate . ")."
        else
            title .= ", compared with prior."
    } else {
        title .= "."
    }
    return title
}

; ---------- 4) Utility: join strings ----------
StrJoin(sep, params*) {
    out := ""
    for p in params {
        if (p = "")
            continue
        out .= (out = "" ? "" : sep) . p
    }
    return out
}

; ========================= MODALITY / BODY PART DETECTION =========================
; Derive modality and body part from the exam type dropdown for header generation.
; Returns a Map with keys "modality" and "bodyPart".
DetectModalityFromExamType(examType) {
    global ExamRegistry
    ; [v50] Registry-driven: no if/else needed when adding new exam types
    result := Map("modality", "CT", "bodyPart", "Chest")
    if ExamRegistry.Has(examType) {
        reg := ExamRegistry[examType]
        result["modality"] := reg["modality"]
        result["bodyPart"] := reg["bodyPart"]
    }
    return result
}

; ========================= GUI CREATION =========================

; [v56] Mutual-exclusion handlers for two-column CT / MR exam selector
OnExamCTChange(*) {
    global gExamType, gExamChanging, ddlExamCT, ddlExamMR
    if gExamChanging
        return
    gExamChanging := true
    if (ddlExamCT.Value > 1) {
        gExamType := ddlExamCT.Text
        ddlExamMR.Choose(1)          ; clear MR selection
    } else {
        gExamType := ""
    }
    gExamChanging := false
}

OnExamMRChange(*) {
    global gExamType, gExamChanging, ddlExamCT, ddlExamMR
    if gExamChanging
        return
    gExamChanging := true
    if (ddlExamMR.Value > 1) {
        gExamType := ddlExamMR.Text
        ddlExamCT.Choose(1)          ; clear CT selection
    } else {
        gExamType := ""
    }
    gExamChanging := false
}

CreateMainGUI() {
    global gExamType, gBulletText, gMainGui
    global gAutoBodyPart, gFinalBodyPart            ; 由外部先設定 gAutoBodyPart
    global gAutoExamType, gAutoContrast              ; auto-detected from PACS title
    global gContrastChoice, gHasPrior, gPriorDate    ; 讓後端可讀
    global gDoseTags                                 ; dose tags from PACS title
    global gEdtManualBodyPart, gChkPrior, gEdtPriorDate, gDdlContrast
    global gReportMode, gModeManual, gClinicalText, gDdlMode, gEdtClinical
    global ddlExamCT, ddlExamMR, gExamChanging       ; [v56] two-column exam selector

    ; ---- 如果 GUI 已經存在，先摧毀舊的 ----
    if IsSet(gMainGui) && IsObject(gMainGui) {
        try {
            gMainGui.Destroy()
        }
    }

    ; [v60_fix] Reset session-specific state on each launch (Alt+A)
    gClinicalText := ""
    gBulletText := ""
    gModeManual := false
    if IsSet(gCandidatesText)
        gCandidatesText := ""

    ; ---- Initialise globals that may not be set by external caller ----
    if !IsSet(gAutoBodyPart)
        gAutoBodyPart := ""
    if !IsSet(gDoseTags)
        gDoseTags := []
    if !IsSet(gAutoExamType)
        gAutoExamType := ""
    if !IsSet(gAutoContrast)
        gAutoContrast := ""

    ; ---- settings (remember last manual body part) ----
    INI_PATH := SubStr(A_LineFile, 1, InStr(A_LineFile, "\",, -1) - 1) . "\FindingAssistant_settings.ini"
    INI_SEC  := "Header"
    INI_KEY  := "LastManualBodyPart"

    _guiLabel := (IsSet(gCoreFileLabel) && gCoreFileLabel != "") ? gCoreFileLabel : ("Finding Assistant " . gCoreVersion)
    gMainGui := Gui("+Resize", _guiLabel . " | Prior-aware + Primary Monitor")
    gMainGui.SetFont("s11", "Segoe UI")

    ; ------------------------------
    ; [v56] Exam Type Selection — two-column layout (CT left | MR right)
    ; ------------------------------
    gExamChanging := false
    gMainGui.Add("Text", "x20  y20 w80",  "Exam Type:")
    gMainGui.Add("Text", "x103 y20 w25",  "CT:")
    gMainGui.Add("Text", "x348 y20 w28",  "MR:")

    ; Build separate CT and MR lists from Registry (insertion order preserved)
    ctTypes := [""]   ; blank first item = nothing selected
    mrTypes := [""]
    for _name, _reg in ExamRegistry {
        _mod := StrUpper(_reg["modality"])
        if (_mod = "CT")
            ctTypes.Push(_name)
        else if (_mod = "MR")
            mrTypes.Push(_name)
    }

    ; [v56] Equal widths (w210 each); MR label at x348, MR DDL starts at x376
    ddlExamCT := gMainGui.Add("DropDownList", "x128 y17 w210 vExamTypeCT", ctTypes)
    ddlExamMR := gMainGui.Add("DropDownList", "x376 y17 w210 vExamTypeMR", mrTypes)

    ddlExamCT.OnEvent("Change", OnExamCTChange)
    ddlExamMR.OnEvent("Change", OnExamMRChange)

    ; Auto-select exam type if detected from PACS title
    examChosen := false
    if (gAutoExamType != "") {
        for idx, et in ctTypes {
            if (et = gAutoExamType) {
                ddlExamCT.Choose(idx)
                gExamType := et
                examChosen := true
                break
            }
        }
        if (!examChosen) {
            for idx, et in mrTypes {
                if (et = gAutoExamType) {
                    ddlExamMR.Choose(idx)
                    gExamType := et
                    examChosen := true
                    break
                }
            }
        }
    }
    if !examChosen {
        ddlExamCT.Choose(2)          ; index 1 = blank, index 2 = first real CT exam
        gExamType := ctTypes[2]
    }

    ; ------------------------------
    ; [v41] Body Part -- always visible, editable, auto-filled from PACS title
    ; ------------------------------
    gMainGui.Add("Text", "x20 y50 w150", "Body Part:")
    gEdtManualBodyPart := gMainGui.Add("Edit", "x180 y47 w300 vManualBodyPart", "")

    ; Auto-fill from PACS title detection; user can always override
    if (gAutoBodyPart != "" && gAutoBodyPart != "Unknown") {
        gEdtManualBodyPart.Value := gAutoBodyPart
    } else {
        ; Try last manual entry from settings
        last := IniRead(INI_PATH, INI_SEC, INI_KEY, "")
        if (last != "")
            gEdtManualBodyPart.Value := last
    }

    ; ------------------------------
    ; Contrast -- auto-select from PACS title if detected
    ; ------------------------------
    gMainGui.Add("Text", "x20 y80 w150", "Contrast:")
    contrastOptions := ["Auto", "Non-enhanced", "Post-contrast only", "Pre- and post-contrast"]
    gDdlContrast := gMainGui.Add("DropDownList", "x180 y77 w300 vContrastChoice", contrastOptions)

    ; Auto-select contrast if detected from PACS title
    contrastChosen := false
    if (gAutoContrast != "" && gAutoContrast != "Auto") {
        for idx, co in contrastOptions {
            if (co = gAutoContrast) {
                gDdlContrast.Choose(idx)
                gContrastChoice := co
                contrastChosen := true
                break
            }
        }
    }
    if !contrastChosen {
        gDdlContrast.Choose(1)
        gContrastChoice := "Auto"
    }
    gDdlContrast.OnEvent("Change", (*) => (gContrastChoice := gDdlContrast.Text))

    ; ------------------------------
    ; [v41] LDCT / Low-dose checkbox -- auto-checked from PACS title, user can uncheck
    ; Only appears in header when checked; not forced on every report.
    ; ------------------------------
    global gChkLDCT
    gChkLDCT := gMainGui.Add("CheckBox", "x500 y80 w120 vIsLDCT", "LDCT")
    ; Auto-check if PACS title contained LDCT/low-dose/screening
    if IsObject(gDoseTags) {
        for d in gDoseTags {
            if (d = "LDCT" || d = "Low-dose") {
                gChkLDCT.Value := 1
                break
            }
        }
    }

    ; ------------------------------
    ; Prior comparison
    ; ------------------------------
    gChkPrior := gMainGui.Add("CheckBox", "x20 y110 vHasPrior", "Compare with prior")
    gMainGui.Add("Text", "x180 y110 w80", "Prior date:")
    gEdtPriorDate := gMainGui.Add("Edit", "x260 y107 w220 vPriorDate", "")
    gEdtPriorDate.Enabled := false

    gHasPrior := 0
    gPriorDate := ""

    gChkPrior.OnEvent("Click", (*) => (
        gHasPrior := gChkPrior.Value,
        gEdtPriorDate.Enabled := gChkPrior.Value
    ))

    ; keep globals updated
    gEdtPriorDate.OnEvent("Change", (*) => (gPriorDate := gEdtPriorDate.Value))

    ; ------------------------------
    ; Report Mode (P3)
    ; ------------------------------
    gMainGui.Add("Text", "x20 y140 w150", "Report Mode:")
    gDdlMode := gMainGui.Add("DropDownList", "x180 y137 w300 vReportMode"
        , ["General", "Oncology follow-up"])
    gDdlMode.Choose(1)   ; default General
    gReportMode := "General"
    gDdlMode.OnEvent("Change", (*) => (
        gReportMode := (gDdlMode.Value = 1) ? "General" : "Oncology",
        gModeManual := true
    ))

    ; ------------------------------
    ; Clinical Information (P5)
    ; ------------------------------
    gMainGui.Add("Text", "x20 y170 w150", "Clinical Info:")
    gEdtClinical := gMainGui.Add("Edit", "x180 y167 w440 h38 vClinicalInfo Multi")
    gEdtClinical.OnEvent("Change", (*) => (gClinicalText := gEdtClinical.Value))

    ; ------------------------------
    ; ------------------------------
    
; [v52] Bullet Input + Extract (collapsible)
; ------------------------------
; Row: label + Extract button on the same line
gMainGui.Add("Text",   "x20  y210", "Paste RIS bullets here:")
gMainGui.Add("Button", "x233 y206 w120 h22 vBtnExtract", "✨ Extract").OnEvent("Click", BtnExtract)

; Raw input
edit := gMainGui.Add("Edit", "x20 y233 w600 h130 vBulletInput Multi WantReturn")
edit.OnEvent("Change", (*) => (gBulletText := edit.Value))

; --- Collapsible extracted/candidates area (hidden by default) ---
global gTxtExtractedTitle, gEdtExtracted
gTxtExtractedTitle := gMainGui.Add("Text", "x20 y371 w600 h20 cBlue Hidden vTxtExtractedTitle", "📌 Extracted Entities (Editable):")
gEdtExtracted := gMainGui.Add("Edit", "x20 y393 w600 h100 Hidden vEdtExtracted Multi WantReturn", "")
gEdtExtracted.OnEvent("Change", (*) => (gCandidatesText := gEdtExtracted.Value))

    
; ------------------------------
; Buttons (will shift up in collapsed state)
; ------------------------------
global gBtnGenerate, gBtnClear, gBtnCopy, gBtnInsert, gBtnNoChange
global gCollapseDelta, gIsExpanded, gMoveDownCtrls

gCollapseDelta := 155
gIsExpanded := false
gMoveDownCtrls := []

gBtnGenerate := gMainGui.Add("Button", "x20 y348 w140 h35 vBtnGenerate", "Generate FINDINGS")
gBtnGenerate.OnEvent("Click", BtnGenerate)

gBtnClear := gMainGui.Add("Button", "x170 y348 w140 h35 vBtnClear", "Clear")
gBtnClear.OnEvent("Click", BtnClear)

gBtnCopy := gMainGui.Add("Button", "x320 y348 w140 h35 vBtnCopy", "Copy Result")
gBtnCopy.OnEvent("Click", BtnCopy)

gBtnInsert := gMainGui.Add("Button", "x470 y348 w140 h35 vBtnInsert", "Insert to RIS")
gBtnInsert.OnEvent("Click", BtnInsert)

; Quick stamp: No interval change
gBtnNoChange := gMainGui.Add("Button", "x20 y391 w600 h28 vBtnNoChange"
    , "▶ No interval change compared with previous study")
gBtnNoChange.OnEvent("Click", BtnNoChange)

; ------------------------------
; Result Display
; ------------------------------
global gResultEdit, gStatusBar
gResultEdit := gMainGui.Add("Edit", "x20 y429 w600 h120 vResultText Multi ReadOnly")

; Status Bar
gStatusBar := gMainGui.Add("StatusBar",, "Ready | Backend: Router " . gCoreVersion . " (Prior-aware + Clean Findings)")

; ------------------------------
; Initial collapsed layout (controls already placed in collapsed Y)
; ------------------------------
; Track which controls must move down when expanded
; (they are already in collapsed positions; ExpandExtractedUI() will move them down)

gMainGui.OnEvent("Close", (*) => gMainGui.Hide())   ; [v56] Hide only — script stays alive
gMainGui.OnEvent("Size", GuiSize)

; ==============================
; SHOW GUI (定位到右下角) — collapsed by default
; [v60_fix] DPI-aware positioning: convert physical work area to logical coordinates
;   so the GUI appears at bottom-right on any display scaling (100%, 125%, 150%, etc.)
; ==============================
mon := MonitorGetPrimary()
MonitorGetWorkArea(mon, &waL, &waT, &waR, &waB)
_dpiScale := A_ScreenDPI / 96
guiW := 640
guiH := 720          ; [v56] collapsed: no Extract area reserved
xPos := Round(waR / _dpiScale) - guiW - 10
yPos := Round(waB / _dpiScale) - guiH - 10
gMainGui.Show("x" . xPos . " y" . yPos . " w" . guiW . " h" . guiH)
    return gMainGui
}

GuiSize(thisGui, MinMax, Width, Height) {
    if (MinMax = -1)
        return

    w := Width - 40   ; usable content width

    ; [v51] BulletInput: fixed height 130, stretch width only
    thisGui["BulletInput"].Move(,, w, 130)
    thisGui["BulletInput"].GetPos(&bx, &by, &bw, &bh)   ; bh=130

    ; Candidates / Extracted section: label + edit box immediately below BulletInput
    candLabelY := by + bh + 8

    ; v52: label was renamed from LblCandidates -> TxtExtractedTitle
    ctrl := ""
    try ctrl := thisGui["TxtExtractedTitle"]
    if (ctrl) {
        ctrl.Move(, candLabelY)
    } else {
        ctrl2 := ""
        try ctrl2 := thisGui["LblCandidates"]
        if (ctrl2)
            ctrl2.Move(, candLabelY)
    }

    candY := candLabelY + 22
    ctrlEdit := ""
    try ctrlEdit := thisGui["EdtExtracted"]
    if (ctrlEdit)
        ctrlEdit.Move(, candY, w, 100)          ; fixed height 100

    ; [v56] Action buttons: tight below BulletInput when collapsed; below Extract area when expanded
    global gIsExpanded
    btnY := gIsExpanded ? (candY + 100 + 15) : (by + bh + 15)
    thisGui["BtnGenerate"].Move(, btnY)
    thisGui["BtnClear"].Move(, btnY)
    thisGui["BtnCopy"].Move(, btnY)
    thisGui["BtnInsert"].Move(, btnY)

    ; [v50/v51] No Interval Change stamp: second button row
    btn2Y := btnY + 42
    thisGui["BtnNoChange"].Move(, btn2Y, w)   ; y, w — height stays 28

    ; ResultText fills all remaining vertical space
    ; [v53] Fix: start BELOW BtnNoChange bottom edge (btn2Y + h28 + gap8)
    resultY := btn2Y + 28 + 8
    resultH := Height - resultY - 50
    if (resultH < 80)
        resultH := 80
    thisGui["ResultText"].Move(, resultY, w, resultH)
}

; ========================= BUTTON HANDLERS =========================

BtnGenerate(*) {
    global gCapturedImpList  ; [v55_8] ensure clean per-click
    gCapturedImpList := []
    global gExamType, gBulletText, gCandidatesText, gMainGui
    global gContrastChoice, gHasPrior, gPriorDate, gDoseTags
    global gReportMode, gModeManual, gClinicalText
    global gLastResult  ; [v59_fix] must be global so BtnNoChange/BtnCopy/BtnInsert can read it

    ; [v51] If Candidates box is non-empty → use it (Extract → Edit → Generate flow).
    ;        Otherwise fall back to raw BulletInput (existing plain-bullet workflow).
    _bullets := (Trim(gCandidatesText) != "") ? gCandidatesText : gBulletText
    _usingCandidates := (Trim(gCandidatesText) != "")

    if (Trim(_bullets) = "") {
        ; [v53] Allow empty bullets for registered exam types → all-negative output
        if (Trim(gExamType) = "" || !ExamRegistry.Has(Trim(gExamType))) {
            UpdateStatus(gMainGui, "Error: paste bullets above (or use Extract (>) first)")
            return
        }
        ; Registered exam type with no bullets → fall through to generate all-negative findings
    }

    UpdateStatus(gMainGui, "Generating FINDINGS" . (_usingCandidates ? " from candidates…" : " from mapping…"))

    ; --- P4: Auto-detect Oncology context — always use raw gBulletText for better signal ---
    AutoSetModeFromContext(gClinicalText, gBulletText)

    ; --- Build header line ---
    ; [v41] Use user-editable Body Part field; fall back to exam-type inference
    manualBP := Trim(gEdtManualBodyPart.Value)
    info := DetectModalityFromExamType(gExamType)
    if (manualBP != "") {
        info["bodyPart"] := manualBP
        ; Save for next session
        try IniWrite(manualBP, SubStr(A_LineFile, 1, InStr(A_LineFile, "\",, -1) - 1) . "\FindingAssistant_settings.ini", "Header", "LastManualBodyPart")
    }
    ; [v41] Build dose tags from LDCT checkbox (not auto-injected from PACS title)
    global gChkLDCT
    userDoseTags := []
    if (gChkLDCT.Value)
        userDoseTags.Push("LDCT")
    header := BuildStudyHeader(info["modality"], info["bodyPart"]
        , gContrastChoice, gHasPrior, gPriorDate, userDoseTags)

    ; --- Generate findings body ---
    ; [v41] Robust comparison: trim + exact match
    ;       Chest CT -> Router mode (keep original sentences, no dictionary, no UNMATCHED)
    ;       All other exam types -> Dictionary/MAP mode
    cleanExam := Trim(gExamType)
    ; [v53_8] Normalize exam type for Registry lookup (strip trailing tags like "(Non-enhanced)" and trailing period)
    cleanExam := RegExReplace(cleanExam, "\s*\([^)]*\)\s*\.?\s*$", "")
    cleanExam := Trim(cleanExam, " .`t")
    ; [v53_9] Router-only backend: dictionary/MAP engine disabled
    findings := GenerateFindings_Router(_bullets, cleanExam, gContrastChoice)
    routeUsed := "Router"


    ; --- [v55_9] Auto-generate Impression ---
    ; [v59_fix] Always run GenerateImpression and pass as impressionBase into BuildImpressionFromList
    ; so actionable findings (e.g. breast cancer, known tumor) are never lost when
    ; gCapturedImpList is non-empty (previously GenerateImpression was skipped entirely).
    if (gCapturedImpList.Length) {
        _autoImp := GenerateImpression(_bullets, gClinicalText, gReportMode, gHasPrior)
        impression := BuildImpressionFromList(gCapturedImpList, _autoImp, _bullets)
    } else {
        impression := GenerateImpression(_bullets, gClinicalText, gReportMode, gHasPrior)
    }
        ; --- Combine: Clinical Info → header → FINDINGS → impression (RIS-safe CRLF) ---
    ct := Trim(gClinicalText)
    ; [v60_fix] Flatten multi-line clinical text into single line (join with "; ")
    ct := RegExReplace(ct, "\r?\n", "; ")
    ct := RegExReplace(ct, ";\s*;\s*", "; ")  ; collapse double separators
    ct := Trim(Trim(ct), ";")
    ct := Trim(ct)
    findingsBlock := "FINDINGS:`r`n" . findings

    if (ct != "")
        combined := "Clinical Information: " . ct . "`r`n`r`n" . header . "`r`n`r`n" . findingsBlock
    else
        combined := header . "`r`n`r`n" . findingsBlock

    if (impression != "")
        combined .= "`r`n`r`n" . impression
    gLastResult := WrapText(combined, 76)   ; [v50] 保存 wrap 後文字，clipboard/Insert 一致
    gMainGui["ResultText"].Value := gLastResult

    modeTag  := (gReportMode = "Oncology") ? " [Oncology]" : ""
    routeTag := " [" . routeUsed . " | " . cleanExam . "]"
              . (_usingCandidates ? " [Extracted]" : "")
    if (CFG["AutoCopyToClipboard"]) {
        A_Clipboard := gLastResult
        UpdateStatus(gMainGui, "FINDINGS generated and copied to clipboard" . modeTag . routeTag)
    } else {
        UpdateStatus(gMainGui, "FINDINGS generated" . modeTag . routeTag)
    }
}

BtnClear(*) {
    global gMainGui, gBulletText, gCandidatesText

    gMainGui["BulletInput"].Value  := ""
    gMainGui["EdtExtracted"].Value   := ""    ; [v51] clear candidates too
    gMainGui["ResultText"].Value   := ""
    gBulletText      := ""
    gCandidatesText  := ""
    UpdateStatus(gMainGui, "Cleared")
}

BtnCopy(*) {
    global gMainGui, gLastResult
    
    result := gLastResult  ; [v45] 從原始變數讀，不受 Edit 折行污染
    if (result = "")
        result := gMainGui["ResultText"].Value  ; fallback
    if (result != "") {
        A_Clipboard := result
        UpdateStatus(gMainGui, "Copied to clipboard")
    }
}

BtnInsert(*) {
    global gExamType, gMainGui, gLastResult

    result := gLastResult
    if (result = "")
        result := gMainGui["ResultText"].Value
    if (result = "") {
        UpdateStatus(gMainGui, "Error: No FINDINGS to insert")
        return
    }

    ; [v59_fix] Auto-find RIS report editing window by known title patterns
    ; Use SetTitleMatchMode 2 (substring) so "報告編輯 041xxxxx 姓名" can be matched
    risHwnd := 0
    _savedMatchMode := A_TitleMatchMode
    SetTitleMatchMode(2)
    for titlePat in ["報告編輯", "Report Edit", "ReportEdit"] {
        risHwnd := WinExist(titlePat)
        if (risHwnd)
            break
    }
    SetTitleMatchMode(_savedMatchMode)

    UpdateStatus(gMainGui, "Inserting...")

    if (risHwnd) {
        ; Found RIS window — activate directly, no need to minimize FindingAssistant
        WinActivate("ahk_id " . risHwnd)
        WinWaitActive("ahk_id " . risHwnd, , 2)
    } else {
        ; Fallback: minimize and hope RIS comes to front (original behavior)
        gMainGui.Minimize()
        Sleep(600)
    }

    PasteToRIS(result)

    Sleep(300)
    UpdateStatus(gMainGui, "FINDINGS inserted to RIS")
    if (risHwnd)
        gMainGui.Show()
}

; [v50] Quick-stamp: No interval change compared with previous study
BtnNoChange(*) {
    global gMainGui, gLastResult

    stamp := "IMPRESSION:`r`nNo interval change compared with previous study."

    ; If there is already generated text, keep the FINDINGS section and replace
    ; the IMPRESSION block (identified by the double-blank-line before it).
    base := gLastResult
    if (base = "")
        base := Trim(gMainGui["ResultText"].Value)

    if (base != "") {
        ; Strip existing IMPRESSION section (always follows \r\n\r\n or \n\n)
        impPos := InStr(base, "`r`n`r`nIMPRESSION:")
        if (impPos = 0)
            impPos := InStr(base, "`n`nIMPRESSION:")
        if (impPos > 0)
            base := SubStr(base, 1, impPos - 1)
        base := RTrim(base, "`r`n ")
        newText := base . "`r`n`r`n" . stamp
    } else {
        newText := stamp
    }

    gLastResult := newText
    gMainGui["ResultText"].Value := newText
    if (CFG["AutoCopyToClipboard"]) {
        A_Clipboard := newText
        UpdateStatus(gMainGui, "No interval change — copied to clipboard")
    } else {
        UpdateStatus(gMainGui, "No interval change — result ready")
    }
}

; =========================================================================================
; [v51] EXTRACT (>) HANDLER
;   BtnExtract        : click handler — reads BulletInput, calls ExtractFromPaste
;   ExtractFromPaste  : pulls '>' (and '-' / '*') lines, strips junk, populates Candidates
;   IsJunkSentence    : returns true for unremarkable / pure-negative / boilerplate lines
; =========================================================================================


BtnExtract(*) {
    global gMainGui
    ExtractFromPaste()
    ExpandExtractedUI()
}

ExtractFromPaste() {
    global gMainGui, gCandidatesText

    raw := gMainGui["BulletInput"].Value
    if (Trim(raw) = "") {
        UpdateStatus(gMainGui, "Extract: nothing in the paste box")
        return
    }

    lines := StrSplit(raw, "`n", "`r")
    out   := []
    lastIdx := 0   ; index into out[] of the last accepted bullet (1-based; 0 = none yet)

    for _, line in lines {
        t := Trim(line)
        if (t = "")
            continue

        ; ── Step 1: accept lines starting with '>' (primary), '-', '•', '*' ────
        ;   '>' lines come from structured report output (section sub-bullets)
        ;   '-' / '•' / '*' lines are plain bullet input
        if RegExMatch(t, "^\s*>\s*(.+)$", &mGt)
            s := Trim(mGt[1])
        else if RegExMatch(t, "^\s*[-•\*]\s*(.+)$", &mBul) {
            s := Trim(mBul[1])
            ; Skip section header lines: "• Section title:" (text followed by colon, no content)
            if RegExMatch(s, "^[A-Za-z][A-Za-z ,/()]+:$")
                continue
        } else {
            ; No bullet prefix — treat as continuation of previous accepted line.
            ; Includes: "DDx: ..." lines, "(0.3-0.4cm, Se/Im...)" parenthetical lines, etc.
            if (lastIdx >= 1 && lastIdx <= out.Length) {
                _cont := Trim(t)
                if (StrLen(_cont) >= 3)
                    out[lastIdx] .= " " . _cont
            }
            continue
        }

        ; ── Step 2: normalise whitespace ─────────────────────────────────────────
        s := RegExReplace(s, "\s+", " ")
        s := Trim(s)

        ; ── Step 2b: strip leading "Section title: " prefix if present ───────────
        ;   e.g. "• Cerebral vasculature: Atherosclerotic calcifications..."
        ;   → keep only "Atherosclerotic calcifications..."
        if RegExMatch(s, "^[A-Za-z][A-Za-z ,/()']+:\s*(.+)$", &_mSecStrip)
            s := Trim(_mSecStrip[1])

        s := Trim(s)
        if (StrLen(s) < 8)           ; too short to be meaningful
            continue

        ; ── Step 3: filter negative / boilerplate sentences ──────────────────────
        ;   - IsJunkSentence: unremarkable, no acute, section headers, pure recommendations
        ;   - Additional: pure negative single-finding sentences from sub-bullets
        if IsJunkSentence(s)
            continue
        if IsNegativeFinding(s)
            continue

        out.Push(s)
        lastIdx := out.Length
    }

    if (out.Length = 0) {
        UpdateStatus(gMainGui, "Extract: no usable findings found (all filtered as normal/junk)")
        return
    }

    ; ── Step 4: join and populate the Candidates edit box ───────────────────────
    joined := ""
    for i, v in out
        joined .= (i = 1 ? "" : "`r`n") . v

    gMainGui["EdtExtracted"].Value := joined
    gCandidatesText := joined
    UpdateStatus(gMainGui, "Extracted " . out.Length . " finding(s) — edit then Generate")
}

; Returns true for pure-negative imaging sentences that add no finding content.
; Distinct from IsJunkSentence (which handles boilerplate/headers).
IsNegativeFinding(s) {
    lc := StrLower(Trim(s))
    ; Patterns: "No X identified/noted/seen.", "No evidence of X.", "No significant X."
    if RegExMatch(lc, "^no\s+(evidence\s+of\s+|significant\s+|definite\s+|acute\s+|focal\s+)?[a-z]")
        return true
    ; "Without X."
    if RegExMatch(lc, "^without\s+[a-z]")
        return true
    ; "Section title: No X." or "Section title: Unremarkable." — section header with inline negative
    if RegExMatch(s, "^[A-Za-z][A-Za-z ,/()']+:\s*(.+)$", &_mSec) {
        _rest := StrLower(Trim(_mSec[1]))
        if RegExMatch(_rest, "^(no|without)\s+[a-z]")
            return true
        if RegExMatch(_rest, "\bunremarkable\b|\bno acute\b|\bwithin normal\b")
            return true
    }
    return false
}


ExpandExtractedUI() {
    global gMainGui, gTxtExtractedTitle, gEdtExtracted
    global gIsExpanded, gCollapseDelta, gMoveDownCtrls

    if (gIsExpanded)
        return

    ; show extracted title + edit box
    if IsSet(gTxtExtractedTitle)
        gTxtExtractedTitle.Visible := true
    if IsSet(gEdtExtracted)
        gEdtExtracted.Visible := true

    ; [v56] Set flag BEFORE resize so GuiSize sees gIsExpanded = true
    ;       and places buttons below the Extract area (not tight below BulletInput).
    ;       Move() fires GuiSize which reflows all controls automatically.
    gIsExpanded := true
    MonitorGetWorkArea(MonitorGetPrimary(), &waL, &waT, &waR, &waB)
    _dpiScale := A_ScreenDPI / 96
    guiW := 640
    guiH := 880          ; expanded height: ~160px taller than collapsed (720px)
    xPos := Round(waR / _dpiScale) - guiW - 10
    yPos := Round(waB / _dpiScale) - guiH - 10
    try gMainGui.Move(xPos, yPos, guiW, guiH)
}

; Returns true if the sentence is a boilerplate negative / unremarkable / pure recommendation.
; [v51] Keep clinical assertions intact ("Suspect fibrosis", "Likely carcinoma") — only filter
; clearly empty / template phrases that add no diagnostic content.
IsJunkSentence(s) {
    lc := StrLower(Trim(s))

    ; A) Explicitly unremarkable / normal
    if RegExMatch(lc, "\bunremarkable\b|\bwithin normal limits?\b|\bno acute\b")
        return true

    ; B) Generic negative single findings — the most common canned phrases
    ;    Pattern: starts with "no" + one of the listed nouns
    if RegExMatch(lc, "^no\b.{0,25}\b(pleural effusion|pneumothorax|consolidation|pericardial effusion"
                     . "|focal lesion|enlarged lymph node|lymphadenopathy|significant finding"
                     . "|free air|free fluid|pneumoperitoneum)\b")
        return true

    ; C) Pure recommendation / management lines (no imaging content)
    if RegExMatch(lc, "^(recommend|please|follow[\-\s]?up|further evaluation|clinical correlation"
                     . "|suggest follow|advise follow)\b")
        return true

    ; D) Section headers from structured reports (e.g. "Lung parenchyma:")
    ;    These are "• Section:" lines — they become empty after stripping '•', so they
    ;    should already be < 8 chars, but guard here too
    if RegExMatch(lc, "^[a-z ]+:$")
        return true

    ; [v60_fix] E) Technical notes: motion artifact, ** wrapped text **, image quality limitations
    if RegExMatch(lc, "motion\s+artifact")
        return true
    if RegExMatch(Trim(s), "^\*\*\s+")
        return true
    if RegExMatch(lc, "\bimage\s+quality\b")
        return true
    if RegExMatch(lc, "\bmay\s+be\s+obscured\b")
        return true

    return false
}

; =========================================================================================
; [v45] NORMALIZE + WORD-WRAP FOR RIS
;   NormalizeNewlines : 統一換行為 CRLF（RIS 最相容）
;   WrapText          : 逐段保留換行，每行自動 wrap 到指定欄寬
;   WrapOneLine       : 單行 word-wrap，tab 轉空白，無空白可斷時硬切
;   PasteToRIS        : 備份剪貼簿 → 貼上 → 還原，避免污染剪貼簿
; =========================================================================================
NormalizeNewlines(s) {
    s := StrReplace(s, "`r`n", "`n")
    s := StrReplace(s, "`r",   "`n")
    return StrReplace(s, "`n", "`r`n")
}

WrapText(s, width := 76) {
    s := NormalizeNewlines(s)
    lines := StrSplit(s, "`r`n")
    out := ""
    for _, line in lines
        out .= WrapOneLine(line, width) . "`r`n"
    return RTrim(out, "`r`n")
}

WrapOneLine(line, width) {
    if (Trim(line) = "")
        return ""
    line := StrReplace(line, "`t", " ")   ; tab → space

    ; --- Detect bullet/quote prefix for hanging-indent ---
    ; Continuation lines align to the FIRST LETTER after the bullet prefix.
    ; e.g. "  > Small nodule..."
    ;       ^^^^  prefix (4 chars)
    ;      "    continuation..."  (4 spaces on next line)
    prefix := ""
    if RegExMatch(line, "^(\s*(?:\d+\.\s+|[>\-•\*]\s+))", &mP)
        prefix := mP[1]
    else if RegExMatch(line, "^(\s+)", &mS)
        prefix := mS[1]

    ; Build contIndent = same length as prefix, all spaces
    contIndent := ""
    Loop StrLen(prefix)
        contIndent .= " "

    ; Extract content after prefix (avoids losing leading spaces via StrSplit)
    content := SubStr(line, StrLen(prefix) + 1)

    words := StrSplit(content, " ")
    buf   := ""
    cur   := 0
    curPfx := prefix          ; first line uses real prefix; rest use contIndent
    for _, w in words {
        if (w = "")
            continue
        wLen := StrLen(w)
        if (cur = 0) {
            ; Start of a new line: prepend current prefix
            buf .= curPfx . w
            cur := StrLen(curPfx) + wLen
            curPfx := contIndent   ; subsequent wrapped lines use contIndent
        } else if (cur + 1 + wLen > width) {
            ; Word doesn't fit: wrap to next line with contIndent
            buf .= "`r`n" . contIndent . w
            cur := StrLen(contIndent) + wLen
        } else {
            buf .= " " . w
            cur += 1 + wLen
        }
    }

    ; Hard-cut fallback: if a single token exceeds width (no spaces to break on)
    if (InStr(buf, "`r`n") = 0 && StrLen(buf) > width) {
        out   := ""
        s     := buf
        first := true
        while (StrLen(s) > width) {
            if first {
                out .= SubStr(s, 1, width)
                s := SubStr(s, width + 1)
                first := false
            } else {
                chunk := width - StrLen(contIndent)
                out .= "`r`n" . contIndent . SubStr(s, 1, chunk)
                s := SubStr(s, chunk + 1)
            }
        }
        if (s != "")
            out .= (first ? s : "`r`n" . contIndent . s)
        return out
    }
    return buf
}


EnsureBlankLineAfterClinicalInfo(txt) {
    ; Ensure exactly ONE blank line between the Clinical Information: block
    ; and the next exam-type section header (e.g., "Chest CT (Enhanced).", "Brain CT.").
    ; Study headers end with "." (from BuildStudyHeader), not ":".
    ; Runs BEFORE WrapText, so Clinical Information is always a single line.
    return RegExReplace(
        txt,
        "(?m)(^Clinical Information:(?:[^\r\n]*\R)+?)(\R*)(^[A-Z][^\r\n]*[.:])",
        "$1`r`n$3"
    )
}

RIS_LINE_WIDTH := 44   ; RIS 視覺顯示欄寬（等寬字型約 44 半形字元）

PasteToRIS(text) {
    ; 1. 保護 FINDINGS:/IMPRESSION: 前的空行（用 sentinel 標記）
    ; 2. 移除其餘 section 間的空行（防校稿跨行 join）
    ; 3. 還原 sentinel 為空行
    ; 4. 每行補滿 76 半形空白（讓校稿無法把下一行塞進當前行）
    text := NormalizeNewlines(text)
    text := StrReplace(text, "`r`n`r`nClinical Information:", "`r`n@@ClinicalInfo:")
    text := StrReplace(text, "`r`n`r`nFINDINGS:",   "`r`n@@FINDINGS:")
    text := StrReplace(text, "`r`n`r`nIMPRESSION:", "`r`n@@IMPRESSION:")
    while InStr(text, "`r`n`r`n")
        text := StrReplace(text, "`r`n`r`n", "`r`n")
    text := StrReplace(text, "`r`n@@ClinicalInfo:", "`r`n`r`nClinical Information:")
    text := StrReplace(text, "`r`n@@FINDINGS:",   "`r`n`r`nFINDINGS:")
    text := StrReplace(text, "`r`n@@IMPRESSION:", "`r`n`r`nIMPRESSION:")
    text := EnsureBlankLineAfterClinicalInfo(text)
    ; Word-wrap to RIS 76-char behavior (with bullet/quote continuation alignment)
    text := WrapText(text, 76)
    lines := StrSplit(text, "`r`n")
    out := ""
    for _, line in lines {
        padded := line
        loop (76 - StrLen(line)) {
            if (StrLen(padded) < 76)
                padded .= " "
        }
        out .= padded . "`r`n"
    }
    text := RTrim(out, "`r`n")
    clipSaved := ClipboardAll()
    A_Clipboard := text
    ClipWait(1)
    Send("^v")
    Sleep(80)
    A_Clipboard := clipSaved
}

; 舊版相容名稱（保留，內部改呼叫 WrapText）
WordWrapForRIS(text, maxWidth := 76) {
    return WrapText(text, maxWidth)
}

UpdateStatus(guiObj, msg) {
    try {
        sb := guiObj["SB"]
        sb.SetText(msg)
    }
}

; ========================= MAP TEMPLATE GENERATORS =========================

; [v50] Generic map-file initialiser used by the Registry engine.
; Creates the file with defaultContent when it is missing.
; Replaces the individual EnsureXxxMapExists() functions (kept below for safety).
EnsureMapFromRegistry(file, defaultContent) {
    if FileExist(file)
        return
    if (defaultContent != "")
        FileAppend(defaultContent, file, "UTF-8")
    ; Empty defaultContent → file creation is the user's responsibility (silent no-op)
}

EnsureChestMapExists(file) {
    if FileExist(file)
        return
}

; =========================================================================================
; [v41] LINE-JOINING PREPROCESSOR
;   Joins lines that were broken mid-sentence (e.g. from RIS copy-paste).
;   Rule: if a line does NOT end with sentence-ending punctuation (. ! ? :)
;   AND the next line does not start with a bullet marker (- • * digit.)
;   → merge them into one line.
; =========================================================================================
JoinWrappedLines(text) {
    lines := StrSplit(text, "`n")
    if (lines.Length <= 1)
        return text

    out := []
    i := 1
    while (i <= lines.Length) {
        current := Trim(lines[i], " `t`r")

        ; Keep merging while current line doesn't end with sentence punctuation
        ; and next line looks like a continuation (not a new bullet)
        while (i < lines.Length) {
            next := Trim(lines[i + 1], " `t`r")

            ; If current ends with sentence-ending punctuation → stop merging
            ; EXCEPTIONS:
            ;   - Next starts with "(" → parenthetical/series annotation, keep merging
            ;   - Current ends with "DDx:" or "Suggest:" → continuation of finding, keep merging
            if RegExMatch(current, "[\.!\?]\s*$") {
                ; Allow merge if next line is a parenthetical annotation (size, Se/Im)
                ; [v59_fix] Also merge if next line starts with "DDx:" (DDx is continuation of finding)
                ; [v60_fix] Also merge if next line starts with "Suggest/Recommend/Advise/Please"
                ;   — these are recommendation tails of the preceding finding/DDx sentence.
                ;   e.g. "DDx: pneumonitis...\nSuggest clinical correlation and follow-up."
                ;   Without this, "Suggest..." becomes a separate bullet → separate impression item.
                if (!RegExMatch(next, "^\(")
                 && !RegExMatch(next, "(?i)^ddx:\s*")
                 && !RegExMatch(next, "(?i)^(Suggest|Recommend|Advise|Please)\b"))
                    break
            }
            if RegExMatch(current, ":\s*$") {
                ; Colon at end — only stop if NOT a known inline label (DDx/Suggest/Se-Im, etc.)
                ; Keep Se/Im-style annotations on the same finding line:
                ;   "... (0.3-0.9cm, Se/Im:" + newline + "5/26, 45, 64, 71), stationary"
                if (!RegExMatch(current, "i)\b(DDx|Suggest|Recommend|Note|Comment|Finding|Se/Im|Series/Image|Ser(?:ies)?/Im(?:age)?):\s*$")
                 && !RegExMatch(next, "^\("))
                    break
            }

            ; If next line starts with bullet marker or '>' sub-bullet → it's a new item, stop
            if RegExMatch(next, "^[\-•\*>]|^\d+[\.\)]")
                break

            ; If next line is empty → stop
            if (next = "")
                break

            ; [v7_sync] Don't join when cur has unclosed Se/Im paren and nxt starts a new finding
            if (InStr(current, "Se/Im:") || InStr(current, "se/im:")) {
                _openP := 0
                _closeP := 0
                Loop StrLen(current) {
                    _ch := SubStr(current, A_Index, 1)
                    if (_ch = "(")
                        _openP += 1
                    else if (_ch = ")")
                        _closeP += 1
                }
                if (_openP > _closeP && RegExMatch(next, "^[A-Z]"))
                    break
            }

            ; Merge: append next to current with a space
            current .= " " . next
            i += 1
        }

        out.Push(current)
        i += 1
    }

    ; Rejoin with newlines
    result := ""
    for line in out
        result .= line . "`n"
    return RTrim(result, "`n")
}

; [v50] stripLeadSuspect=true  → MAP/dictionary mode (strips "Suspect X" → "X" for key lookup)
;        stripLeadSuspect=false → Router mode (keeps full sentence text, e.g. "Suspect fibrosis…")
FilterBullet_ChestCT(raw, stripLeadSuspect := true) {
    s := Trim(raw)
    if (s = "")
        return ""

    ; [v60_fix] Filter out technical notes wrapped in ** ... ** (e.g., ** motion artifact **)
    ; Also filter "** text" without closing ** and any line mentioning "motion artifact"
    _preStrip := RegExReplace(s, "^[\s\-•>]+", "")
    _preStrip := Trim(_preStrip)
    if RegExMatch(_preStrip, "^\*\*\s+.*\*\*\s*$")
        return ""
    if RegExMatch(_preStrip, "^\*\*\s+")
        return ""
    if RegExMatch(StrLower(_preStrip), "motion\s+artifact")
        return ""

    ; Remove leading bullet markers
    s := RegExReplace(s, "^[\s\-•\*>]+\s*", "")

    ; [v41] Strip leading RIS noise: page numbers, bare numbers, short fragments
    s := RegExReplace(s, "^[\d\)\.\s]+$", "")  ; pure number/punctuation lines like "57)"
    s := Trim(s)
    if (StrLen(s) < 10)
        return ""   ; too short to be meaningful (e.g. "study", "57)")

    low := StrLower(s)

    ; A) Recommendation / management (no imaging content): skip entirely
    ;    [v7_sync] "consider" removed from blanket filter — handled separately below
    if RegExMatch(low, "^(recommend|advise|please|suggest)\b")
        return ""
    ; [v7_sync] "Consider" + generic advice → filter; "Consider" + diagnosis → keep
    if RegExMatch(low, "^consider\s+(follow|clinical|further|regular|routine|repeat|evaluation)")
        return ""
    if RegExMatch(low, "^\s*(follow[- ]?up|further evaluation|sonography|clinical correlation)\b")
        return ""
    ; A2) Pure DDx line with no imaging finding → skip (DDx handled via impression)
    if RegExMatch(low, "^ddx:\s*")
        return ""
    
    ; B) Mixed bullets: imaging finding + trailing interpretation/recommendation
    ;    Keep the imaging-description part, truncate at the recommendation keyword
    ;    [v41] Leading "suspect(ed)/consider/suggest(ed)" — strip for MAP/dictionary mode
    ;           (keyword lookup needs the noun, not the qualifier)
    ;    [v50] In Router mode (stripLeadSuspect=false) keep full text so output reads naturally:
    ;           "Suspect fibrosis in the left upper lobe" stays intact.
    if (stripLeadSuspect && RegExMatch(low, "^(suspect(ed)?|consider|suggest(ed)?)\s+", &mLead)) {
        s := SubStr(s, mLead.Len + 1)
        s := RTrim(Trim(s), ".")
        ; [v41] Re-check: if stripped content is pure recommendation, discard
        sLow := StrLower(s)
        if RegExMatch(sLow, "^(clinical correlation|follow[- ]?up|further evaluation|sonography|ct scan|mri|ultrasound)")
            return ""
        return (StrLen(s) >= 8) ? s : ""
    }
    ; [v60_fix] Removed "compatible with|consistent with|suggestive of|concerning for" from
    ;   detection & truncation — these are DIAGNOSTIC INTERPRETATION keywords that should stay
    ;   in FINDINGS text (e.g. "Lesion compatible with hemangioma" → keep full finding).
    ;   Only MANAGEMENT keywords (recommend/suggest/follow-up/DDx) cause truncation.
    ;   Impression capture uses rawSentence (pre-truncation) so interpretation is always preserved there.
    if RegExMatch(low, "recommend|suggest|advise|consider|follow[- ]?up|correlation|sonography|further evaluation|suspect|likely|probably|possible|may represent|could represent|\bddx\b|\bddx:\b") {
        cutPos := 0

        ; First: find sentence-ending punctuation (skip decimal points like "1.5cm")
        for sep in [".", ";"] {
            startPos := 1
            Loop {
                p := InStr(s, sep,, startPos)
                if (!p)
                    break
                ; Skip decimal points: digit.digit (e.g. "1.5cm", "3.2mm")
                if (sep = "." && p > 1 && p < StrLen(s)) {
                    charBefore := SubStr(s, p - 1, 1)
                    charAfter := SubStr(s, p + 1, 1)
                    if IsDigit(charBefore) && IsDigit(charAfter) {
                        startPos := p + 1
                        continue
                    }
                }
                ; Skip periods followed by Se/Im/size annotation parenthetical
                ; e.g. "BLL. (0.3-0.5cm, Se/Im: 5/75)" → period is NOT a sentence boundary
                if (sep = "." && p < StrLen(s)) {
                    _afterP := SubStr(s, p + 1)
                    if RegExMatch(_afterP, "^\s*\([^)]*(?:Se|Im|cm|mm)[^)]*\)") {
                        startPos := p + 1
                        continue
                    }
                }
                if (cutPos = 0 || p < cutPos)
                    cutPos := p
                break
            }
        }

        ; Second: keyword position — ALWAYS run (not gated on cutPos=0)
        ; Takes the EARLIER of punct-cut and keyword-cut.
        ; Rationale: punct-cut may land at sentence end (e.g. "...Se/Im: 5/75, 82) Recommend follow-up.")
        ;   where the only period is at the very end, so keyword cut must still win.
        ; [v60_fix] Removed "compatible with", "consistent with", "suggestive of", "concerning for"
        ;   from keyword list — these are diagnostic descriptors, not management directives.
        for kw in [" ddx:", " ddx", " suspect", " likely", " probably", " possible", " may represent", " could represent", " recommend", " suggest", " advise", " consider", " follow-up", " follow up", " correlation", " sonography", " further evaluation"] {
            p2 := InStr(low, kw)
            if (p2 && (cutPos = 0 || p2 < cutPos))
                cutPos := p2
        }
        
        if (cutPos)
            s := Trim(SubStr(s, 1, cutPos - 1))

        ; [v7_sync] Clean up ". (" → " (" (reattach parenthetical Se/Im/cm/mm annotation)
        s := RegExReplace(s, "\.\s*(\([^)]*(?:Se|Im|cm|mm)[^)]*\))", " $1")
        s := RTrim(Trim(s), ". `t")

        if (StrLen(s) < 8)
            return ""
    }

    return s
}


; =========================
; [v53] Clean finding sentence (Findings only)
; - Remove DDx: and any trailing Suggest/Recommend/Correlation part
; - Keep imaging description + size + Se/Im
; =========================
CleanFindingSentence(sentence) {
    s := Trim(sentence)
    if (s = "")
        return ""

    ; Cut at DDx:
    if RegExMatch(s, "i)\bDDx:\b", &mDdx)
        s := Trim(SubStr(s, 1, mDdx.Pos - 1))

    ; Cut at recommendation/management keywords
    if RegExMatch(s, "i)\b(Suggest|Recommend|Advise|Consider|Clinical correlation|Follow[- ]?up|Further evaluation)\b", &mRec)
        s := Trim(SubStr(s, 1, mRec.Pos - 1))

    s := Trim(s, " .;")
    if (s = "")
        return ""

    return s "."
}

EnsureBrainMapExists(file) {
    if FileExist(file)
        return
    tpl := "# Brain CT mapping template`n"
    tpl .= "hypodense area => Brain parenchyma: | A hypodense area is noted.`n"
    tpl .= "effacement of the basal cisterns => Basal cisterns: | Effacement of the basal cisterns is noted.`n"
    tpl .= "`n"
    FileAppend(tpl, file, "UTF-8")
}

EnsureCTAAortaMapExists(file) {
    if FileExist(file)
        return
}

EnsureCTAHeadNeckMapExists(file) {
    if FileExist(file)
        return
}

EnsureFacialCTMapExists(file) {
    if FileExist(file)
        return
}

EnsureBrainMRIMapExists(file) {
    if FileExist(file)
        return
}

EnsureAbdomenMapExists(file) {
    if FileExist(file)
        return
}

EnsurePelvisCTMapExists(file) {
    if FileExist(file)
        return
}

EnsureCSpineCTMapExists(file) {
    if FileExist(file)
        return
}

EnsureSpineMRIMapExists(file) {
    if FileExist(file)
        return
}

EnsureLegCTMapExists(file) {
    if FileExist(file)
        return
}

EnsureUniversalMapExists(file) {
    if FileExist(file)
        return
}

; ========================= CHEST CT HEURISTIC =========================

; ========================= CHEST CT ROUTER v57_6 =========================
; Three-layer pipeline:
;   Layer 1 - ExtractLocation_ChestCT   : find anatomical location token
;   Layer 2 - LocationToSection_ChestCT : location token → section header
;   Layer 3 - RefineSection_ChestCT     : modifier micro-adjustment (pass-through for now)
; Fallback: lesion-type regex → "Osseous and soft tissues:"
; ==========================================================================

ExtractLocation_ChestCT(line) {
    lc := StrLower(Trim(line))

    ; ── Priority 0: sentence-level overrides (compound findings) ──────────────
    ; [v60_fix] "pleural effusion" must route to Pleura even when sentence also
    ;   contains lung-lobe anchors (e.g. "...with passive atelectasis of RLL").
    ;   The effusion IS the primary finding; atelectasis is secondary.
    if RegExMatch(lc, "\bpleural\s+effusion")
        return "pleura"
    ; [v60_fix] Lung parenchymal finding near hilum → Lung (not Mediastinum)
    ;   e.g. "Ground glass opacity near left pulmonary hilum" — GGO is the primary finding,
    ;   hilum is just the anatomical landmark. Must override hilum → mediastinum mapping.
    ;   Excludes hilar lymphadenopathy/adenopathy which IS a mediastinal finding.
    if RegExMatch(lc, "ground.?glass|\bgg[on]\b|opaci|consolidat|atelectas|infiltrat|pneumoni|fibrosis|fibrot") && RegExMatch(lc, "\bhil(ar|um)\b") && !RegExMatch(lc, "lymph|adenopathy")
        return "lung"
    ; [v60_fix] Abdominal/retroperitoneal lymphadenopathy → Others (not Mediastinum/Liver)
    ;   "hepatic hilar" = porta hepatis, NOT pulmonary hilum
    ;   "retroperitoneal" = abdomen, not chest mediastinum
    if RegExMatch(lc, "(hepatic\s+hil|retroperitoneal|mesenteric|para-?aortic|celiac|porta\s+hepatis).{0,30}(lymph|adenopathy)")
        return "gi"
    if RegExMatch(lc, "(lymph|adenopathy).{0,30}(hepatic\s+hil|retroperitoneal|mesenteric|para-?aortic|celiac|porta\s+hepatis)")
        return "gi"
    ; [v60_fix] Portal venous gas → liver (not GI/Osseous)
    ;   "Portal veinous gas" / "Portal venous gas" — gas in the hepatic portal vein system.
    ;   portal\s+gas (line 1700) misses "portal veinous gas" (word in between).
    if RegExMatch(lc, "portal\s+(venous|veinous|vein)\s+(gas|air)|portal\s+gas")
        return "liver"
    ; [v7_sync] Subphrenic findings → GI (Others)
    if RegExMatch(lc, "\bsubphrenic\b")
        return "gi"
    ; [v60_fix] Biliary duct structures → biliary_pancreas (not Liver)
    ;   "Dilated hepatic duct" / "Intrahepatic duct dilatation" / "Dilated IHDs"
    ;   contain "hepatic" which would match Liver at Priority 2 line 1656. Override here.
    if RegExMatch(lc, "(hepatic|intrahepatic|intra.hepatic)\s+(bile\s+)?duct|\bihd\b|\bihds\b|common\s+hepatic\s+duct|biliary\s+dil|duct\s+dil")
        return "biliary_pancreas"

    ; ── Priority 1: explicit preposition anchor "in/at/of/within (the) <organ>" ──
    ; Ordered from most-specific to least-specific to avoid early exit on partial match

    ; Thyroid / goiter
    if RegExMatch(lc, "\b(in|at|of|within)\s+(?:the\s+)?(?:left\s+|right\s+|bilateral\s+)?(?:thyroid(?:\s+gland)?|goiter)")
        return "thyroid"
    ; Liver / hepatic
    if RegExMatch(lc, "\b(in|at|of|within)\s+(?:the\s+)?(?:left\s+|right\s+|bilateral\s+)?(?:liver|hepatic\s+parenchyma|hepat)")
        return "liver"
    ; Adrenal
    if RegExMatch(lc, "\b(in|at|of|within)\s+(?:the\s+)?(?:left\s+|right\s+|bilateral\s+)?adrenal(?:\s+gland)?")
        return "adrenal"
    ; Spleen
    if RegExMatch(lc, "\b(in|at|of|within)\s+(?:the\s+)?(?:left\s+|right\s+|bilateral\s+)?(?:spleen|splenic)")
        return "spleen"
    ; Kidney
    if RegExMatch(lc, "\b(in|at|of|within)\s+(?:the\s+)?(?:left\s+|right\s+|bilateral\s+)?(?:kidney|renal\s+parenchyma|ureter)")
        return "kidney"
    ; Lung lobes / parenchyma
    if RegExMatch(lc, "\b(in|at|of|within)\s+(?:the\s+)?(?:left\s+|right\s+|bilateral\s+)?(?:upper\s+lobe|lower\s+lobe|middle\s+lobe|lung|pulmonary\s+parenchyma|lobe\b)")
        return "lung"
    ; [v59_fix] "aspect of right/left lung" — preposition anchor fails when intervening words exist
    ; e.g. "in the anterior aspect of right lung", "at the peripheral aspect of left lung"
    if RegExMatch(lc, "aspect\s+of\s+(?:the\s+)?(?:right|left|bilateral)?\s*lung")
        return "lung"
    ; Pleura
    if RegExMatch(lc, "\b(in|at|of|within)\s+(?:the\s+)?(?:left\s+|right\s+|bilateral\s+)?(?:pleura|pleural\s+space|pleural\s+cavity)")
        return "pleura"
    ; Mediastinum / hilum
    if RegExMatch(lc, "\b(in|at|of|within)\s+(?:the\s+)?(?:anterior\s+|posterior\s+|middle\s+|superior\s+)?(?:mediastin|hila\b|hilum\b|hilar\s+region)")
        return "mediastinum"
    ; Heart / great vessels
    if RegExMatch(lc, "\b(in|at|of|within)\s+(?:the\s+)?(?:left\s+|right\s+)?(?:heart|aorta|pulmonary\s+artery|pulmonary\s+vein|vena\s+cava|coronary\s+artery)")
        return "heart_vessel"
    ; Pericardium
    if RegExMatch(lc, "\b(in|at|of|within)\s+(?:the\s+)?pericardi")
        return "heart_vessel"
    ; Gallbladder / biliary / pancreas
    if RegExMatch(lc, "\b(in|at|of|within)\s+(?:the\s+)?(?:gallbladder|bile\s+duct|biliary|pancreat|pancreatic\s+(?:head|body|tail))")
        return "biliary_pancreas"
    ; GI tract
    if RegExMatch(lc, "\b(in|at|of|within)\s+(?:the\s+)?(?:bowel|colon|rectum|sigmoid|appendix|stomach|duodenum|jejunum|ileum|esophag|oesophag)")
        return "gi"
    ; Spine / vertebra
    if RegExMatch(lc, "\b(in|at|of|within)\s+(?:the\s+)?(?:spine|vertebr|thoracic\s+spine|lumbar\s+spine|cervical\s+spine|thoracolumbar)")
        return "spine"
    ; Chest wall / ribs
    if RegExMatch(lc, "\b(in|at|of|within)\s+(?:the\s+)?(?:rib\b|ribs\b|sternum|clavicle|scapula|chest\s+wall|intercostal|costophrenic)")
        return "chest_wall"

    ; ── Priority 2: direct organ mention (no preposition) ──
    ; Post-procedure / status terms — map to organ of procedure
    if RegExMatch(lc, "splenectomy|post.splenectomy|s/p\s+splenectomy|status\s+post\s+splenectomy")
        return "spleen"
    if RegExMatch(lc, "hepatectomy|liver\s+resection|liver\s+transplant|hepatic\s+resection") {
        ; [v59_fix] Combined hepatectomy+cholecystectomy → biliary_pancreas (cholecystectomy dominant)
        if RegExMatch(lc, "cholecystectomy")
            return "biliary_pancreas"
        return "liver"
    }
    if RegExMatch(lc, "nephrectomy|renal\s+transplant")
        return "kidney"
    if RegExMatch(lc, "port\s+catheter|portacath|port.a.cath|venous\s+port|subclavian.*catheter|catheter.*subclavian|central\s+venous.*catheter|picc\b|hickman\b|mediport\b|implanted.*port|totally\s+implanted")
        return "device"
    if RegExMatch(lc, "pacemaker|defibrillator|icd\b|cardiac\s+device|cardiac\s+lead")
        return "heart_vessel"
    if RegExMatch(lc, "cholecystectomy|whipple|pancreaticoduodenectomy")
        return "biliary_pancreas"

    ; Organ direct mention
    if RegExMatch(lc, "\bthyroid(?:\s+gland)?\b|\bgoiter\b|\bgoitre\b")
        return "thyroid"
    if RegExMatch(lc, "\bliver\b|\bhepatom|\bhepatoc|\bhepatic\b|fatty\s+liver|hepatic\s+(cyst|mass|lesion|metastas|segment|steatosis)")
        return "liver"
    if RegExMatch(lc, "\badrenal(?:\s+gland)?\b|\badrenals\b|pheochromocytoma")
        return "adrenal"
    if RegExMatch(lc, "\bspleen\b|\bsplenic\b|\bsplenomegaly\b|accessory\s+spleen")
        return "spleen"
    ; [v60_fix] Added perinephric|perirenal — \bnephr misses "perinephric" (no word boundary)
    if RegExMatch(lc, "\bkidney\b|\brenal\b|\bnephr|\bureter\b|hydronephrosis|nephrolithiasis|urolithiasis|perinephric|perirenal")
        return "kidney"
    if RegExMatch(lc, "\blung\b|pulmonary\s+parenchyma|upper\s+lobe|lower\s+lobe|middle\s+lobe|\bbilateral\s+lob|\bcentrilobular\b")
        return "lung"
    ; [v59_fix] Lung lesion abutting/touching pleura → still Lung parenchyma, not Pleura
    ; e.g. "calcified granuloma abutting the right upper pleura"
    ;       "nodule abutting the pleural surface"
    if RegExMatch(lc, "(nodule|granuloma|mass|lesion|opacity|consolidation).{0,40}(abutting|touching|adjacent\s+to|contacting).{0,20}pleura")
        return "lung"
    if RegExMatch(lc, "(abutting|touching|adjacent\s+to|contacting).{0,20}pleura.{0,40}(nodule|granuloma|mass|lesion)")
        return "lung"
    if RegExMatch(lc, "\bpleura\b|\bpleural\b|\bpneumothorax\b|h[ae]mothorax|empyema|mesothelioma")
        return "pleura"
    ; [v59_fix] Axillary / breast → chest_wall (Osseous and soft tissues) BEFORE mediastinum rule
    ; [v60_fix] \baxillar\b → \baxillar (removed trailing \b so "axillary" also matches)
    ; [v60_fix] Added subcutaneous/muscular/abdominal wall — soft tissue findings, not lung
    if RegExMatch(lc, "\baxillar|\baxilla\b|\bbreast\b|\bintramammar|\bmammary\b|\bsubcutan|\bmuscular\s+infilt|\babdominal\s+wall")
        return "chest_wall"
    if RegExMatch(lc, "\bmediastin|\bhilar\b|\bhilum\b|pretracheal|paratracheal|subcarinal|prevascular|thymus|thymoma|pneumomediastinum")
        return "mediastinum"
    ; [v7_sync] Added \bsubclavian\s+arter for aberrant subclavian artery routing
    if RegExMatch(lc, "\bheart\b|cardiac|cardiomegaly|\baorta\b|\baortic\b|pulmonary\s+artery|pulmonary\s+vein|pulmonary\s+trunk|coronary|\bivc\b|\bsvc\b|inferior\s+vena|superior\s+vena|\baneurysm\b|pericardi|atherosclerosis|calcif.*(?:aorta|coronary)|(?:aorta|coronary).*calcif|\bsubclavian\s+arter")
        return "heart_vessel"
    if RegExMatch(lc, "gallbladder|bile\s+duct|biliary|cholecyst|cholelith|\bcbd\b|choledoch|pancreat|\bihd\b|\bihds\b|intrahepatic\s+(bile\s+)?duct|intra.hepatic\s+(bile\s+)?duct|biliary\s+dil|duct\s+dil|pneumobilia")
        return "biliary_pancreas"
    ; [v60_fix] Removed portal\s+gas from GI — now caught as Priority 0 → liver
    if RegExMatch(lc, "diverticul|\bbowel\b|\bcolon\b|\bcolonic\b|\brectum\b|sigmoid|\bappendix\b|\bileum\b|\bjejunum\b|\bduodenum\b|small\s+bowel|large\s+bowel|\bcolitis\b|\benteritis\b|intussusception|pneumatosis|mesenteric|omentum")
        return "gi"
    ; [v59_fix] Traction bronchiectasis = parenchymal finding (secondary to fibrosis/radiation)
    ; must be caught BEFORE the generic \bbronch → airway rule below
    if RegExMatch(lc, "traction\s+bronchiectasis|radiation.{0,20}bronchiectasis|fibrosis.{0,20}bronchiectasis")
        return "lung"
    if RegExMatch(lc, "\btrachea\b|\bbronch|\bairway\b|bronchomalacia|mucus\s+plug|endobronchial")
        return "airway"
    if RegExMatch(lc, "esophag|oesophag")
        return "mediastinum"
    if RegExMatch(lc, "\bspine\b|\bvertebr|\bspondyl|\bthoracolumbar\b|\bthoracic\s+spine\b|lumbar\s+spine|cervical\s+spine|\bdisk\b|\bdisc\b|compression\s+fracture|vertebral\s+fracture|vertebroplasty|kyphoplasty")
        return "spine"
    ; [v60_fix] Added rib.{0,30}fracture and fracture.{0,30}rib for any word-order
    if RegExMatch(lc, "\brib\b|\bribs\b|\bsternum\b|\bclavicle\b|\bscapula\b|chest\s+wall|\bcostophrenic\b|\bintercostal\b|humeral\s+head|shoulder\s+joint|old.{0,20}(rib|ribs)|rib.{0,30}fracture|fracture.{0,30}rib")
        return "chest_wall"

    return ""  ; no location found
}

LocationToSection_ChestCT(loc) {
    static _map := Map(
        "thyroid",          "Thyroid gland:",
        "liver",            "Liver:",
        "adrenal",          "Adrenal glands:",
        "spleen",           "Spleen:",
        "kidney",           "Kidneys:",
        "lung",             "Lung parenchyma:",
        "pleura",           "Pleura:",
        "mediastinum",      "Mediastinum and lymph nodes:",
        "airway",           "Airways:",
        "heart_vessel",     "Heart and vessels:",
        "biliary_pancreas", "Biliary system and pancreas:",
        "gi",               "Others:",
        "device",           "Others:",
        "spine",            "Osseous and soft tissues:",
        "chest_wall",       "Osseous and soft tissues:"
    )
    return _map.Has(loc) ? _map[loc] : ""
}

RefineSection_ChestCT(line, sec) {
    ; [v57_6] Pass-through — reserved for future sub-section logic
    ; e.g. Lung parenchyma: distinguish nodule / consolidation / emphysema sub-types
    ; e.g. Mediastinum: distinguish lymph node vs vascular vs soft tissue mass
    return sec
}

HeuristicRoutes_ChestCT(line) {
    lc := StrLower(Trim(line))
    if (lc = "")
        return ""

    ; ── Layer 1+2: location-based routing ────────────────────────────────
    loc := ExtractLocation_ChestCT(line)
    if (loc != "") {
        sec := LocationToSection_ChestCT(loc)
        if (sec != "")
            return RefineSection_ChestCT(line, sec)
    }

    ; ── Layer 3: lesion-type fallback (no location anchor found) ─────────
    ; Lung parenchyma — primary lung findings
    ; [v7_sync] Traction bronchiectasis → Lung (before airway)
    if RegExMatch(lc, "traction\s+bronchiectasis|radiation.{0,20}bronchiectasis")
        return "Lung parenchyma:"
    ; [v7_sync] Bony/bone metastases → Osseous BEFORE generic metastas → Lung
    if RegExMatch(lc, "\b(?:bony|bone|osseous|skeletal|osteoblastic|osteolytic)\s+metastas")
        return "Osseous and soft tissues:"
    ; [v60_fix] Perinephric/perirenal → Kidneys BEFORE Lung's "infiltrat" catches non-lung infiltration
    if RegExMatch(lc, "perinephric|perirenal|peri[\-\s]?nephric|peri[\-\s]?renal")
        return "Kidneys:"
    ; [v60_fix] Subcutaneous/muscular/abdominal wall → Osseous BEFORE Lung's "infiltrat"
    ;   "Suspect increased subcutaneous and muscular infiltration..." is soft tissue, not lung.
    if RegExMatch(lc, "\bsubcutan|\bmuscular\s+infilt|\babdominal\s+wall|\bchest\s+wall\b")
        return "Osseous and soft tissues:"
    if RegExMatch(lc, "atelectasis|consolidation|pneumonia|pneumonitis|ground.?glass|nodules?\b|granuloma|fibrosis|emphysema|centrilobular|hyperinflat|bulla\b|bleb\b|air.?space|alveolar|infiltrat|opaci|pulmonary\s+parenchyma|bronchiectasis|air\s+trapping|tree.?in.?bud|crazy.?paving|honeycombing|aspiration|pulmonary\s+infarct|contusion|laceration|cavit|cystic\s+lung|juxtapleural|subpleural\s+(nodules?|lesion|mass|cyst)|paramediastinal\s+(nodules?|lesion)|metastas")
        return "Lung parenchyma:"
    ; Lung cancer explicit
    if RegExMatch(lc, "lung\s+(cancer|carcinoma|adenocarcinoma|squamous|malignancy|tumor|tumour|mass)|\bnsclc\b|\bsclc\b")
        return "Lung parenchyma:"
    ; Pleura
    if RegExMatch(lc, "pleura|pleural|pneumothorax|h[ae]mothorax|empyema|pleural\s+thick|pleural\s+plaque|mesothelioma|apical\s+cap|\bapex\b|\bapical\b")
        return "Pleura:"
    ; Mediastinum
    ; [v59_fix] Axillary/breast lymph node → Osseous and soft tissues, not Mediastinum
    ; [v60_fix] \baxillar\b → \baxillar (removed trailing \b so "axillary" also matches)
    if RegExMatch(lc, "\baxillar|\baxilla\b|\bbreast\b|\bintramammar|\bmammary\b")
        return "Osseous and soft tissues:"
    if RegExMatch(lc, "mediastin|lymph\s+node|lymphadenopathy|adenopathy|hilar\b|pretracheal|paratracheal|subcarinal|prevascular|thymus|thymoma|pneumomediastinum")
        return "Mediastinum and lymph nodes:"
    ; Airways
    if RegExMatch(lc, "\bairway\b|trachea\b|main\s+bronch|lobar\s+bronch|segmental\s+bronch|bronchial\b|bronchomalacia|mucus\s+plug|endobronchial")
        return "Airways:"
    ; Heart and vessels
    if RegExMatch(lc, "\bheart\b|cardiac|cardiomegaly|\baorta\b|\baortic\b|pulmonary\s+artery|pulmonary\s+vein|coronary|atherosclerosis|aneurysm|dissection|embolism|\bpe\b|pulmonary\s+embol|thrombosis")
        return "Heart and vessels:"
    ; [v60_fix] Biliary duct structures → Biliary (not Liver) — must precede \bhepat below
    if RegExMatch(lc, "(hepatic|intrahepatic|intra.hepatic)\s+(bile\s+)?duct|\bihd\b|\bihds\b|common\s+hepatic\s+duct|biliary\s+dil|duct\s+dil")
        return "Biliary system and pancreas:"
    ; Liver
    if RegExMatch(lc, "\bliver\b|\bhepat|fatty\s+liver")
        return "Liver:"
    ; Biliary / pancreas
    if RegExMatch(lc, "gallbladder|bile\s+duct|biliary|cholecyst|cholelith|pancreat|\bcbd\b|choledoch|\bihd\b|\bihds\b|intrahepatic\s+(bile\s+)?duct|intra.hepatic\s+(bile\s+)?duct|pneumobilia")
        return "Biliary system and pancreas:"
    ; Spleen
    if RegExMatch(lc, "\bspleen\b|splenic|splenomegaly|splenectomy")
        return "Spleen:"
    ; Adrenal
    if RegExMatch(lc, "adrenal|pheochromocytoma")
        return "Adrenal glands:"
    ; Kidneys
    ; [v60_fix] Added perinephric|perirenal — \bnephr misses "perinephric"
    if RegExMatch(lc, "\bkidney\b|\brenal\b|\bnephr|\bureter\b|hydronephrosis|nephrolithiasis|perinephric|perirenal")
        return "Kidneys:"
    ; [v60_fix] Portal venous gas → Liver (not GI/Osseous)
    if RegExMatch(lc, "portal\s+(venous|veinous|vein)\s+(gas|air)|portal\s+gas")
        return "Liver:"
    ; GI / incidental bowel findings → Others
    if RegExMatch(lc, "diverticul|\bbowel\b|\bcolon\b|\brectum\b|\bcolitis\b|mesenteric|pneumatosis")
        return "Others:"
    ; Tubes, lines, catheters, devices → Others
    if RegExMatch(lc, "port\s+catheter|portacath|port.a.cath|venous\s+port|picc\b|hickman\b|mediport\b|implanted\s+port|totally\s+implanted|nasogastric|ng\s+tube|drainage\s+tube|chest\s+tube|intercostal\s+drain|feeding\s+tube|gastrostomy|pacemaker|\bicd\b|defibrillator|subclavian.*catheter|catheter.*subclavian|central\s+venous.*catheter")
        return "Others:"

    ; [v60_fix] Fracture / vertebroplasty / kyphoplasty → Osseous (safety net)
    if RegExMatch(lc, "\bfracture\b|vertebroplasty|kyphoplasty")
        return "Osseous and soft tissues:"

    ; Final fallback
    return "Osseous and soft tissues:"
}

; ========================= BULLET FILTERS =========================; ========================= BULLET FILTERS =========================

FilterBullet_BrainCT(raw) {
    s := Trim(raw)
    if (s = "")
        return ""

    ; [v60_fix] Filter out technical notes (** motion artifact ** etc.)
    _preStrip := RegExReplace(s, "^[\s\-•>]+", "")
    _preStrip := Trim(_preStrip)
    if RegExMatch(_preStrip, "^\*\*\s+")
        return ""
    if RegExMatch(StrLower(_preStrip), "motion\s+artifact")
        return ""

    ; Remove leading bullet markers
    s := RegExReplace(s, "^[\s\-•\*>]+\s*", "")

    ; [v55_5] Findings-clean: keep imaging description, drop DDx / Suggest / Recommend tails
    ; Cut off "DDx:" and anything after
    s := RegExReplace(s, "(?i)DDx:\s*.*$", "")

    ; Cut off suggestion/recommendation clauses (keep the imaging part before it)
    s := RegExReplace(s, "(?i)(suggest|recommend|correlat(e|ion)|follow[- ]?up|further evaluation).*$", "")

    s := Trim(s, " .`t")
    if (s = "")
        return ""
    return s "."
}

; ========================= BRAIN CT: HEURISTIC ROUTING (Impression → Section) =========================
; v48-style output is preserved by reusing the existing buckets/sections renderer.
; This only runs when a line does NOT match the brain mapping file.

HeuristicRoutes_BrainCT(line) {
    lc := StrLower(Trim(line))
    if (lc = "")
        return ""

    ; =========================
    ; 1) Calvarium / Skull base (check FIRST — scalp/skull findings must not leak to parenchyma)
    ; =========================
    if RegExMatch(lc, "subgaleal|scalp|cephalhematoma|extracranial|calvarium|calvaria|calvarial|skull\s+fracture|skull\s+base\s+fracture|temporal\s+bone\s+fracture|craniotomy|cranioplasty|craniectomy|bone\s+flap|titanium\s+mesh|osteoma|ostoma")
        return "Calvarium and skull base:"

    ; =========================
    ; 2) Paranasal sinuses / Mastoid
    ; =========================
    if RegExMatch(lc, "maxillary\s+sinus|ethmoid|sphenoid|frontal\s+sinus|paranasal|mastoid|otomastoiditis|otitis|pneumatiz|air\s+cell")
        return "Paranasal sinuses and mastoid air cells:"

    ; =========================
    ; 3) Extra-axial spaces (SAH / SDH / EDH / hygroma)
    ; =========================
    if RegExMatch(lc, "subarachnoid.*(hemorrhage|haemorrhage)|\bsah\b")
        return "Extra-axial spaces:"
    if RegExMatch(lc, "subdural|epidural|extra.axial|hygroma|csf\s+collection|subdural\s+(fluid|collection)")
        return "Extra-axial spaces:"

    ; =========================
    ; 3.5) Cortical atrophy compound split — "cortical atrophy with/and ventricular dilation/enlargement"
    ;      Splits into Brain parenchyma + Ventricular system via §Section:§Text payload
    ; =========================
    if RegExMatch(lc, "cortical\s+atrophy|cerebral\s+atrophy|brain\s+atrophy|cerebral\s+cortical\s+atrophy") {
        ; Check for co-occurring ventricular component (with OR and)
        if RegExMatch(lc, "ventricular\s+(dilat|enlarg)|ventriculomegal|dilated\s+ventricl") {
            ; Build atrophy text: strip " with/and ventricular ..." tail (case-insensitive on original line)
            _aText := RegExReplace(line, "i)\s*(with|and)\s+(ventricular\s+(dilat\w*|enlarg\w*)|ventriculomegal\w*|dilated\s+ventricl\w*).*$", "")
            _aText := Trim(_aText, " .,")
            if (_aText = "")
                _aText := "Cerebral cortical atrophy"
            return "§Brain parenchyma:§" . _aText . ".§Ventricular system:§Ventricular dilatation."
        }
        ; Simple atrophy — no ventricular component
        return "Brain parenchyma:"
    }

    ; =========================
    ; 4) Ventricular system
    ; =========================
    if RegExMatch(lc, "intraventricular.*(hemorrhage|haemorrhage)|\bivh\b")
        return "Ventricular system:"
    if RegExMatch(lc, "ventricle|ventricular|hydrocephalus|ventriculomegaly|ventriculo.*shunt|\bvp\s+shunt\b|\bshunt\b|ventricular\s+dilatation|ventricular\s+enlargement")
        return "Ventricular system:"

    ; =========================
    ; 5) Basal cisterns
    ; =========================
    if RegExMatch(lc, "basal\s+cistern|cisternal|perimesencephalic\s+cistern")
        return "Basal cisterns:"

    ; =========================
    ; 6) Calcification resolver — parenchymal physiologic calcifications (NOT vasculature)
    ; =========================
    if RegExMatch(lc, "(basal\s+ganglia|globus\s+pallidus|lentiform|putamen|caudate|thalamus|pineal|choroid\s+plexus).{0,30}(calcif)")
        return "Brain parenchyma:"
    if RegExMatch(lc, "(calcif).{0,30}(basal\s+ganglia|globus\s+pallidus|lentiform|putamen|caudate|thalamus|pineal|choroid\s+plexus)")
        return "Brain parenchyma:"

    ; =========================
    ; 7) Cerebral vasculature
    ; =========================
    ; Vessel + vascular pathology (either order)
    if RegExMatch(lc, "(carotid|internal\s+carotid|\bica\b|vertebral|basilar|vertebrobasilar|\bmca\b|\baca\b|\bpca\b|circle\s+of\s+willis|siphon).{0,40}(atherosclerosis|arteriosclerosis|calcif|stenosis|occlusion|aneurysm|dissection|dolichoectasia|irregularit)")
        return "Cerebral vasculature:"
    if RegExMatch(lc, "(atherosclerosis|arteriosclerosis|calcif|stenosis|occlusion|aneurysm|dissection|dolichoectasia).{0,40}(carotid|internal\s+carotid|\bica\b|vertebral|basilar|vertebrobasilar|\bmca\b|\baca\b|\bpca\b|circle\s+of\s+willis|siphon)")
        return "Cerebral vasculature:"
    ; Standalone arteriosclerosis/atherosclerosis in a brain CT → vasculature
    if RegExMatch(lc, "\barteriosclerosis\b|\batherosclerosis\b")
        return "Cerebral vasculature:"

    ; =========================
    ; 8) Orbits / Ocular / Soft tissue (extracranial)
    ; =========================
    if RegExMatch(lc, "\borbit\b|orbital|globe|lens\b|cataract|ocular|intraocular|periorbital|phthisis|bulbi")
        return "Ocular / Others:"
    ; Subcutaneous/soft tissue at any cranial region → Ocular / Others (before parenchyma rule steals "occipital")
    if RegExMatch(lc, "subcutaneous|soft\s+tissue\s+(nodule|mass|lesion|swelling|lump)|scalp\s+(nodule|mass|lesion|cyst)|skin\b|sebaceous|dermoid\b|epidermoid\b|lipoma")
        return "Ocular / Others:"

    ; =========================
    ; 9) Brain parenchyma — posterior fossa / brainstem / pituitary
    ; =========================
    if RegExMatch(lc, "cerebell|cerebellum|cerebellar|pontine|\bpons\b|midbrain|medulla|brainstem|posterior\s+fossa|\bcpa\b|cerebellopontine|acoustic\s+neuroma|vestibular\s+schwannoma")
        return "Brain parenchyma:"
    if RegExMatch(lc, "pituitary|sellar|\bsella\b|suprasellar|adenoma")
        return "Brain parenchyma:"

    ; =========================
    ; 10) Brain parenchyma — specific anatomy (including plural Latin forms)
    ; =========================
    if RegExMatch(lc, "lentiform|putamen|caudate|thalamus|basal\s+ganglia|corona.?radiata|coronae.?radiatae|centrum.?semiovale|centra.?semiovales|internal\s+capsule|white\s+matter|gray\s+matter|deep\s+white|subcortical|periventricular|juxtacortical|cortical|insul|hippocampus|hippocampal|amygdala|cingulate|corpus\s+callosum|splenium|genu|frontal|temporal|parietal|occipital|hemisphere|parenchyma")
        return "Brain parenchyma:"

    ; =========================
    ; 11) Brain parenchyma — pathology keywords
    ; =========================
    if RegExMatch(lc, "infarct|ischemi|gliosis|gliotic|encephalomalacia|leukoaraiosis|white\s+matter\s+change|atrophy|volume\s+loss|edema|encephalitis|demyelin|microbleed|lacunar|contusion|intracerebral|intraparenchymal|\bich\b|hemorrhagic\s+contusion")
        return "Brain parenchyma:"

    ; Lesion/mass/tumor require a co-occurring brain location to be safe
    if RegExMatch(lc, "\blesion\b|\bmass\b|tumo[ur]|neoplasm|metastas|nodule\b|\bcyst\b|hypodens|hyperdens") {
        if RegExMatch(lc, "brain|cerebr|cortical|subcortical|parenchyma|frontal|temporal|parietal|occipital|cerebell|pons|medulla|thalamus|basal\s+ganglia|corona|centrum|white\s+matter|gray\s+matter|hemisphere|lobe")
            return "Brain parenchyma:"
    }

    return ""
}

; ========================= BRAIN MRI: HEURISTIC ROUTING =========================
; Sections: Brain parenchyma: | DWI/ADC: | Post-contrast enhancement: |
;           Ventricular system: | Extra-axial spaces: | Basal cisterns: |
;           Intracranial hemorrhage: | Cerebral vasculature: |
;           Calvarium and skull base: | Paranasal sinuses and mastoid air cells:
HeuristicRoutes_BrainMRI(line) {
    lc := StrLower(Trim(line))
    if (lc = "")
        return ""

    ; 1) Calvarium / Skull base
    if RegExMatch(lc, "subgaleal|scalp|calvarium|calvarial|skull\s+fracture|craniotomy|cranioplasty|craniectomy|bone\s+flap|titanium\s+mesh|osteoma|ostoma")
        return "Calvarium and skull base:"

    ; 2) Paranasal sinuses / Mastoid
    if RegExMatch(lc, "maxillary\s+sinus|ethmoid|sphenoid|frontal\s+sinus|paranasal|mastoid|otomastoiditis|otitis|pneumatiz|air\s+cell")
        return "Paranasal sinuses and mastoid air cells:"

    ; 3) DWI/ADC — diffusion restriction (must check BEFORE generic infarct rule)
    if RegExMatch(lc, "\bdwi\b|diffusion.weighted|diffusion\s+restriction|restricted\s+diffusion|\badc\b|apparent\s+diffusion|hyperintense.*dwi|dwi.*hyperintense|acute\s+ischemic\s+infarct|acute\s+infarct")
        return "DWI/ADC:"

    ; 4) Post-contrast enhancement
    if RegExMatch(lc, "enhance|enhancing|contrast|gadolinium|leptomeningeal|meningeal\s+enhance|blood.brain\s+barrier|post.contrast|ring.enhanc|nodular\s+enhanc")
        return "Post-contrast enhancement:"

    ; 5) Extra-axial spaces
    if RegExMatch(lc, "subarachnoid.*(hemorrhage|haemorrhage)|\bsah\b|subdural|epidural|extra.axial|hygroma|csf\s+collection")
        return "Extra-axial spaces:"

    ; 6) Cortical atrophy — before ventricular rule
    if RegExMatch(lc, "cortical\s+atrophy|cerebral\s+atrophy|brain\s+atrophy")
        return "Brain parenchyma:"

    ; 7) Ventricular system
    if RegExMatch(lc, "intraventricular.*(hemorrhage|haemorrhage)|\bivh\b|ventricle|ventricular|hydrocephalus|ventriculomegaly|vp\s+shunt|\bshunt\b|ventricular\s+dilatation")
        return "Ventricular system:"

    ; 8) Basal cisterns
    if RegExMatch(lc, "basal\s+cistern|cisternal|perimesencephalic")
        return "Basal cisterns:"

    ; 9) Intracranial hemorrhage (dedicated section in Brain MRI — unlike Brain CT)
    if RegExMatch(lc, "intracerebral|intraparenchymal|\bich\b|parenchymal.*(hemorrhage|haemorrhage)|hemorrhagic\s+contusion|cerebral.*(hemorrhage|haemorrhage)|blood\s+products|hemosiderin|microbleed|\bbloom\b")
        return "Intracranial hemorrhage:"

    ; 10) Calcification resolver → parenchyma (not vasculature)
    if RegExMatch(lc, "(basal\s+ganglia|globus\s+pallidus|lentiform|putamen|caudate|thalamus|pineal|choroid\s+plexus).{0,30}(calcif)")
        return "Brain parenchyma:"
    if RegExMatch(lc, "(calcif).{0,30}(basal\s+ganglia|globus\s+pallidus|lentiform|putamen|caudate|thalamus|pineal|choroid\s+plexus)")
        return "Brain parenchyma:"

    ; 11) Cerebral vasculature
    if RegExMatch(lc, "(carotid|internal\s+carotid|\bica\b|vertebral|basilar|vertebrobasilar|\bmca\b|\baca\b|\bpca\b|circle\s+of\s+willis).{0,40}(atherosclerosis|arteriosclerosis|stenosis|occlusion|aneurysm|dissection|dolichoectasia|vasculitis|vasospasm)")
        return "Cerebral vasculature:"
    if RegExMatch(lc, "(atherosclerosis|arteriosclerosis|stenosis|occlusion|aneurysm|dissection|dolichoectasia|vasculitis|vasospasm).{0,40}(carotid|internal\s+carotid|\bica\b|vertebral|basilar|vertebrobasilar|\bmca\b|\baca\b|\bpca\b|circle\s+of\s+willis)")
        return "Cerebral vasculature:"
    if RegExMatch(lc, "\barteriosclerosis\b|\batherosclerosis\b|flow\s+void|vascular\s+malformation|\bavm\b|dural\s+fistula")
        return "Cerebral vasculature:"

    ; 12) Brain parenchyma — anatomy (plurals included)
    if RegExMatch(lc, "lentiform|putamen|caudate|thalamus|basal\s+ganglia|corona.?radiata|coronae.?radiatae|centrum.?semiovale|centra.?semiovales|internal\s+capsule|white\s+matter|gray\s+matter|subcortical|periventricular|cortical|insul|hippocampus|hippocampal|amygdala|cingulate|corpus\s+callosum|frontal|temporal|parietal|occipital|hemisphere|parenchyma|cerebell|brainstem|\bpons\b|midbrain|medulla|posterior\s+fossa|pituitary|sellar")
        return "Brain parenchyma:"

    ; 13) Brain parenchyma — pathology
    if RegExMatch(lc, "infarct|ischemi|gliosis|gliotic|encephalomalacia|leukoaraiosis|white\s+matter\s+change|demyelin|atrophy|volume\s+loss|edema|encephalitis|lesion|mass\b|tumor|neoplasm|metastas|abscess|cyst")
        return "Brain parenchyma:"

    return ""
}

HeuristicRoutes_LegCT(line) {
    lc := StrLower(Trim(line))
    if (lc = "")
        return ""

    ; Bones
    if RegExMatch(lc, "fracture|fx\b|cortical|tibia|fibula|malleol|talus|calcane|metatars|phalanx|perioste|callus|displac|sublux|disloc")
        return "Bones:"

    ; Joints
    if RegExMatch(lc, "knee|ankle|tibiotalar|subtalar|effusion|intra-?articular|joint")
        return "Joints:"

    ; Soft tissues
    if RegExMatch(lc, "swelling|edema|haematoma|hematoma|contusion|abscess|cellulitis|gas|emphysema|ulcer|sinus|foreign body")
        return "Soft tissues:"

    ; Vessels
    if RegExMatch(lc, "extravasation|runoff|artery|arterial|vein|venous|dvt|thrombos|occlus")
        return "Vessels:"

    return ""
}

HeuristicRoutes_ExtremityMRI(line) {
    lc := StrLower(Trim(line))
    if (lc = "")
        return ""

    ; Soft tissues — checked FIRST: subcutaneous/cystic/mass findings are never bone
    ; "thigh" as location without bone-specific keywords also defaults here
    if RegExMatch(lc, "subcutaneous|cyst\b|cystic|lipoma|lipomatous|seroma|abscess|cellulitis|soft\s+tissue|fascia|fasciitis|foreign\s+body|skin\b|fluid\s+collection|collection\b|mass\b|lesion\b|tumor\b")
        return "Soft tissues:"

    ; Bones — specific bone pathology keywords (lesion/tumor removed; too broad above)
    if RegExMatch(lc, "fracture|fx\b|marrow|bone\s+marrow|stress\s+reaction|stress\s+fracture|cortical|perioste|osteonecrosis|avascular\s+necrosis|avn\b|metasta|osteomyel|lytic|sclerotic|bone\s+lesion|bony\s+lesion")
        return "Bones:"

    ; Joints
    if RegExMatch(lc, "joint|effusion|synovitis|cartilage|chondral|labrum|acetabul|femoroacetabular|cam\b|pincer\b|impingement|bursitis|degenerative|osteoarthrit")
        return "Joints:"

    ; Muscles and tendons (contusion/edema/hematoma belong here, not Bones)
    if RegExMatch(lc, "muscle|myositis|strain|tear|rupture|tendon|tendin|tenosynov|contusion|edema|hematoma|haematoma")
        return "Muscles and tendons:"

    ; Ligaments
    if RegExMatch(lc, "ligament|lig\b|sprain|acl\b|pcl\b|mcl\b|lcl\b|capsule|capsular")
        return "Ligaments:"

    ; Neurovascular
    if RegExMatch(lc, "nerve|neural|neuropathy|entrapment|radicul|vascular|artery|vein|thromb|dvt|varix|avm|malformation")
        return "Neurovascular structures:"

    return ""
}


FilterBullet_CTAAorta(raw) {
    s := Trim(raw)
    if (s = "")
        return ""
    s := RegExReplace(s, "^[\s\-•\*>]+\s*", "")
    low := StrLower(s)
    if RegExMatch(low, "recommend|suggest|follow[- ]?up|correlation")
        return ""
    return s
}

; ========================= CTA AORTA: HEURISTIC ROUTING =========================
; Sections: Thoracic aorta: | Arch and great vessels: | Abdominal aorta: |
;           Branch vessels: | Pulmonary arteries: | Mediastinum/hemorrhage:
HeuristicRoutes_CTAAorta(line) {
    lc := StrLower(Trim(line))
    if (lc = "")
        return ""

    ; Pulmonary arteries — check early (PE must not route to aorta)
    if RegExMatch(lc, "pulmonary\s+artery|pulmonary\s+arteries|pulmonary\s+embolism|\bpe\b|pulmonary\s+trunk|main\s+pulmonary|lobar\s+pulm|segmental\s+pulm|filling\s+defect.*pulm|pulm.*filling\s+defect|pulmonary.*thrombus|thrombus.*pulmonary")
        return "Pulmonary arteries:"

    ; Abdominal aorta (check before generic aorta rules)
    if RegExMatch(lc, "abdominal\s+aorta|infrarenal|suprarenal|juxta.?renal|\baaa\b|aorto.?iliac")
        return "Abdominal aorta:"

    ; Branch vessels (aortic branches distal to arch)
    if RegExMatch(lc, "celiac|hepatic\s+artery|splenic\s+artery|\bsma\b|\bima\b|superior\s+mesenteric|inferior\s+mesenteric|renal\s+artery|renal\s+arteries|\biliac\b|femoral\s+artery|aorto.?femoral")
        return "Branch vessels:"

    ; Arch and great vessels
    if RegExMatch(lc, "aortic\s+arch|\barch\b|subclavian|innominate|brachiocephalic|common\s+carotid|great\s+vessel")
        return "Arch and great vessels:"

    ; Mediastinum / hemorrhage / pericardium
    if RegExMatch(lc, "mediastin|pericardial|hemopericardium|tamponade|hemorrhage|haemorrhage|hematoma|haematoma|hemothorax|pleural\s+effusion|lymph\s+node|lymphadenopathy|trachea|esophag")
        return "Mediastinum/hemorrhage:"

    ; Thoracic aorta — catch-all for any remaining aortic/dissection findings
    if RegExMatch(lc, "\baorta\b|\baortic\b|ascending|descending|dissection|intramural\s+hematoma|\bimh\b|penetrating\s+ulcer|\bpau\b|aortic\s+root|sinotubular|sinus\s+of\s+valsalva|aneurysm|dilation|ectasia|coarctation")
        return "Thoracic aorta:"

    return ""
}

FilterBullet_CTAHeadNeck(raw) {
    s := Trim(raw)
    if (s = "")
        return ""
    s := RegExReplace(s, "^[\s\-•\*>]+\s*", "")
    low := StrLower(s)
    if RegExMatch(low, "recommend|suggest|follow[- ]?up|correlation")
        return ""
    return s
}

; ========================= CTA HEAD & NECK: HEURISTIC ROUTING =========================
; Sections: Intracranial arteries: | Extracranial carotid and vertebral arteries: | Venous sinuses:
HeuristicRoutes_CTAHeadNeck(line) {
    lc := StrLower(Trim(line))
    if (lc = "")
        return ""

    ; Venous sinuses (check early — avoid arterial cross-routing)
    if RegExMatch(lc, "venous\s+sinus|dural\s+sinus|superior\s+sagittal|transverse\s+sinus|sigmoid\s+sinus|cavernous\s+sinus|sinus\s+thrombosis|venous\s+thrombosis|cerebral\s+venous|\bjugular\b|cerebral\s+venous\s+thrombosis|\bcvt\b")
        return "Venous sinuses:"

    ; Intracranial arteries
    if RegExMatch(lc, "intracranial|\bterminal\s+ica\b|\bmca\b|\baca\b|\bpca\b|\bpica\b|\baica\b|\bsca\b|\bbasil\b|basilar|aneurysm|\bavm\b|arteriovenous\s+malformation|perforat|lenticulostriate|posterior\s+communicating|anterior\s+communicating|\bpcom\b|\bacom\b|circle\s+of\s+willis")
        return "Intracranial arteries:"

    ; Extracranial carotid and vertebral arteries
    if RegExMatch(lc, "carotid|vertebral|subclavian|\bcca\b|\bica\b|\beca\b|carotid\s+bulb|bifurcation|plaque|stenosis|dissection|occlusion|fibromuscular\s+dysplasia|\bfmd\b|endarterectomy|stent")
        return "Extracranial carotid and vertebral arteries:"

    return ""
}

FilterBullet_FacialCT(raw) {
    s := Trim(raw)
    if (s = "")
        return ""
    s := RegExReplace(s, "^[\s\-•\*>]+\s*", "")
    low := StrLower(s)
    if RegExMatch(low, "recommend|suggest|follow[- ]?up|correlation")
        return ""
    return s
}

; ========================= FACIAL BONE CT: HEURISTIC ROUTING =========================
; Sections: Facial bones: | Orbits: | Paranasal sinuses: | Nasal cavity: | Soft tissues:
HeuristicRoutes_FacialCT(line) {
    lc := StrLower(Trim(line))
    if (lc = "")
        return ""

    ; Orbits (check before paranasal sinuses — orbital walls are facial bones but proptosis etc. → Orbits)
    if RegExMatch(lc, "\borbit\b|orbital|intraorbital|retrobulbar|globe|ocular|optic\s+nerve|optic\s+canal|extraocular\s+muscle|proptosis|enophthalmos|subperiosteal|retro.?orbital")
        return "Orbits:"

    ; Paranasal sinuses
    if RegExMatch(lc, "maxillary\s+sinus|ethmoid|sphenoid|frontal\s+sinus|paranasal|sinusitis|mucosal|mucous\s+retention|polyp|air.fluid\s+level|sinus\s+opacif")
        return "Paranasal sinuses:"

    ; Nasal cavity
    if RegExMatch(lc, "nasal\s+septum|nasal\s+cavity|turbinate|concha\b|nasal\s+bone|nasopharynx|adenoid|choanal|nasal\s+polyp")
        return "Nasal cavity:"

    ; Facial bones — fractures and specific facial skeleton structures
    if RegExMatch(lc, "fracture|zygomatic|zygoma|orbital\s+(wall|floor|rim)|maxilla|mandible|naso.orbital|naso.ethmoid|le\s+fort|frontal\s+bone|tripod|blow.out|blow.in|alveolar|dental|\btmj\b|temporomandibular|condyle|symphysis|ramus")
        return "Facial bones:"

    ; Soft tissues — catch-all
    return "Soft tissues:"
}

FilterBullet_BrainMRI(raw) {
    s := Trim(raw)
    if (s = "")
        return ""
    s := RegExReplace(s, "^[\s\-•\*>]+\s*", "")
    low := StrLower(s)
    if RegExMatch(low, "recommend|suggest|follow[- ]?up|correlation")
        return ""
    return s
}

FilterBullet_SpineMRI(raw) {
    s := Trim(raw)
    if (s = "")
        return ""

    ; [v60_fix] Filter out technical notes (** motion artifact **, image quality, etc.)
    _preStrip := RegExReplace(s, "^[\s\-•>]+", "")
    _preStrip := Trim(_preStrip)
    if RegExMatch(_preStrip, "^\*\*\s+")
        return ""
    _lcPre := StrLower(_preStrip)
    if RegExMatch(_lcPre, "motion\s+artifact")
        return ""
    if RegExMatch(_lcPre, "\bimage\s+quality\b")
        return ""
    if RegExMatch(_lcPre, "\bmay\s+be\s+obscured\b")
        return ""

    s := RegExReplace(s, "^[\s\-•\*>]+\s*", "")   ; [v56] include > bullet marker
    ; Strip trailing DDx / Suggest / Recommend clauses
    s := RegExReplace(s, "(?i)DDx:\s*.*$", "")
    s := RegExReplace(s, "(?i)(suggest|recommend|correlat(e|ion)|follow[- ]?up|further evaluation).*$", "")
    s := Trim(s, " .`t")
    if (s = "")
        return ""
    return s "."
}

; ========================= SPINE MRI: HEURISTIC ROUTING =========================
; Routes findings for C-spine / T-spine / L-spine MRI.
; [v56] Disc pathology is routed to Intervertebral discs: as primary section.
; When the same finding also describes canal or foraminal involvement, it is
; ALSO routed to those sections via pipe-delimited multi-section return value,
; so secondary sections are not left with a false-negative wording.
HeuristicRoutes_SpineMRI(line) {
    lc := StrLower(Trim(line))
    if (lc = "")
        return ""

    ; [v60_fix] Split "vertebra/vertebral body and paraspinal soft tissue" into two sections
    ; e.g. "Increased signal intensity of the L4 vertebra and paraspinal soft tissue on T2WI"
    ;   → Vertebral bodies: "Increased signal intensity of the L4 vertebra on T2WI."
    ;   → Paraspinal soft tissues: "Increased signal intensity of paraspinal soft tissue on T2WI."
    if RegExMatch(lc, "\bvertebr") && RegExMatch(lc, "\bparaspinal\b") && RegExMatch(lc, "\band\b") {
        if RegExMatch(line, "i)^(.*?)((?:the\s+)?(?:\w+\s+)?vertebr\w*(?:\s+bod(?:y|ies))?)\s+and\s+(paraspinal\s+soft\s+tissue\w*)(.*)$", &mVP) {
            _prefix := Trim(mVP[1])
            _vObj := Trim(mVP[2])
            _pObj := Trim(mVP[3])
            _suffix := Trim(mVP[4], " .`t")

            _vText := _prefix . " " . _vObj
            _pText := _prefix . " " . _pObj
            if (_suffix != "") {
                _vText .= " " . _suffix
                _pText .= " " . _suffix
            }
            _vText := Trim(_vText)
            _pText := Trim(_pText)
            if (_vText != "" && SubStr(_vText, -1) != ".")
                _vText .= "."
            if (_pText != "" && SubStr(_pText, -1) != ".")
                _pText .= "."
            return "§Vertebral bodies:§" . _vText . "§Paraspinal soft tissues:§" . _pText
        }
    }

    ; [v56_1] Complex compound sentence: disc + canal/foramina -> pre-split by Router sentence splitter
    isComplex := RegExMatch(lc, "disc|disk|bulg|protrusion|prolapse|herniat|extrusion|sequestration|annular|annulus|nucleus pulposus|disc height|disc desiccation|disc degeneration|disc dessication|modic")
             && RegExMatch(lc, "thecal sac|lateral recess|spinal canal|canal stenosis|central stenosis|spinal stenosis|foramin|foraminal|encroachment|nerve root|radiculopathy")

    if (isComplex) {
        ; Return per-section fragments in "§Section:§Text..." format (handled by GenerateFindings_Router)
        return GenerateFindings_Router_SpineMRI(line)
    }


    ; 1) Intervertebral discs (disc is primary — check BEFORE canal/foramina)
    if RegExMatch(lc, "disc|disk|bulg|protrusion|prolapse|herniat|extrusion|sequestration|annular|annulus|nucleus pulposus|disc height|disc desiccation|disc degeneration|disc dessication|modic") {
        sec := "Intervertebral discs:"
        ; [v56] also push to canal section if canal/thecal/lateral-recess involvement mentioned
        if RegExMatch(lc, "thecal sac|lateral recess|spinal canal|canal stenosis|central stenosis|spinal stenosis|\bcord\b|myelopathy|myelomalacia|cauda equina|conus")
            sec .= "|Spinal canal and cord:"
        ; [v56] also push to foramina section if foraminal involvement mentioned
        if RegExMatch(lc, "foramin|foraminal|encroachment|nerve root|radiculopathy")
            sec .= "|Neural foramina:"
        return sec
    }

    ; 2) Alignment
    if RegExMatch(lc, "\balignment\b|scoliosis|kyphosis|lordosis|listhesis|spondylolisthesis|retrolisthesis|anterolisthesis|subluxation|curvature")
        return "Alignment:"

    ; 3) Vertebral bodies
    ; [v60_fix] Added post-op keywords: internal fixation, laminectomy, cage, fusion, hardware, pedicle screw
    if RegExMatch(lc, "vertebra|spondylosis|spondyl|fracture|compression|end.?plate|marrow|schmorl|hemangioma|metastas|height loss|wedging|sacrum|sacral|coccyx|status\s+post|post.?op|internal\s+fixation|laminectomy|cage\s+insertion|spinal\s+fusion|\bhardware\b|pedicle\s+screw|instrumentation")
        return "Vertebral bodies:"

    ; 4) Spinal canal and cord (standalone — no disc keyword present)
    if RegExMatch(lc, "spinal canal|canal stenosis|central stenosis|thecal sac|spinal cord|\bcord\b|myelopathy|myelomalacia|syrinx|conus|cauda equina|lateral recess|spinal stenosis")
        return "Spinal canal and cord:"

    ; 5) Neural foramina (standalone — no disc keyword present)
    if RegExMatch(lc, "foramin|neural foramin|foraminal|nerve root|radiculopathy|encroachment")
        return "Neural foramina:"

    ; 6) Paraspinal soft tissues
    if RegExMatch(lc, "paraspinal|psoas|epidural|abscess|collection|ligament|ligamentum flavum|facet|zygoapophys|interspinous|posterior element|soft tissue")
        return "Paraspinal soft tissues:"

    return ""
}


; [v56_1] Router sentence splitter for Spine MRI:
; Input: a single sentence potentially mixing disc + canal/foramina effects.
; Output: "§Section:§fragment§Section2:§fragment2..." (no "SPLIT:" prefix).
; Notes:
; - Splits on ",", ";", ".", and the pivot " with ".
; - For clauses that were created *after* splitting by "with", auto-prepend "adjacent "
;   when routing into "Spinal canal and cord:" and the clause does not already contain "adjacent".
GenerateFindings_Router_SpineMRI(line) {
    line := Trim(line)
    if (line = "")
        return ""

    lineLC := StrLower(line)

    ; --- Tokenize while remembering whether the token follows a causal/pivot phrase ---
    ; Pivot phrases: "with", "causing", "resulting in", "leading to"
    tokens := []  ; each item: Map("txt", "...", "afterPivot", true/false)
    pos := 1
    afterPivot := false

    ; Delimiters: comma, semicolon, period (followed by optional space), or pivot phrases (case-insensitive)
    ; Note: punctuation resets afterPivot; pivot phrases set afterPivot for the next token.
    while RegExMatch(line, "(?i)(,|;|\.)\s*|\s+with\s+|\s+causing\s+|\s+resulting\s+in\s+|\s+leading\s+to\s+", &m, pos) {
        seg := Trim(SubStr(line, pos, m.Pos - pos))
        if (seg != "")
            tokens.Push(Map("txt", seg, "afterPivot", afterPivot))

        delim := SubStr(line, m.Pos, m.Len)
        if RegExMatch(delim, "(?i)\bwith\b|\bcausing\b|\bresulting\b|\bleading\b")
            afterPivot := true
        else
            afterPivot := false

        pos := m.Pos + m.Len
    }

    tail := Trim(SubStr(line, pos))
    if (tail != "")
        tokens.Push(Map("txt", tail, "afterPivot", afterPivot))

    ; [v60_fix] Merge level-only tokens (e.g. "L3-4", "L3-4 and L5-S1") with previous disc token
    ; so "Broad-based disc protrusion at L2-3, L3-4 and L5-S1" stays as one finding
    ; A token is "level-only" if after removing all spine levels, "and", commas, whitespace → nothing remains
    _mergedTokens := []
    for item in tokens {
        _tok := Trim(item["txt"])
        _chk := RegExReplace(_tok, "i)[LTSC]\d+[\-/][LTSC]?\d+", "")
        _chk := RegExReplace(_chk, "i)\band\b", "")
        _chk := RegExReplace(_chk, "[,\s]+", "")
        _isLevelOnly := (_chk = "" && _tok != "")
        if (_mergedTokens.Length > 0 && _isLevelOnly) {
            _prev := _mergedTokens[_mergedTokens.Length]
            _prev["txt"] := _prev["txt"] . ", " . _tok
        } else {
            _mergedTokens.Push(item)
        }
    }
    tokens := _mergedTokens

    result := ""

    for item in tokens {
        tok := Trim(item["txt"])
        if (tok = "")
            continue
        tokLC := StrLower(tok)

        ; Logic 3: Neural foramina (highest priority)
        if RegExMatch(tokLC, "foramin|foraminal|encroachment|nerve root|radiculopathy") {
            needAdj := (!RegExMatch(tokLC, "\badjacent\b")) && ( item["afterPivot"] || RegExMatch(lineLC, "disc|disk|bulg|protrusion|prolapse|herniat|extrusion|sequestration") )
            prefix := needAdj ? "adjacent " : ""
            result .= "§Neural foramina:§" . prefix . tok
        }
        ; Logic 2: Spinal canal and cord
        else if RegExMatch(tokLC, "thecal sac|lateral recess|spinal canal|canal stenosis|central stenosis|spinal stenosis|\bcord\b|myelopathy|myelomalacia|cauda equina|conus") {
            needAdj := (!RegExMatch(tokLC, "\badjacent\b")) && ( item["afterPivot"] || RegExMatch(lineLC, "disc|disk|bulg|protrusion|prolapse|herniat|extrusion|sequestration") )
            prefix := needAdj ? "adjacent " : ""
            result .= "§Spinal canal and cord:§" . prefix . tok
        }
        ; Logic 1: Intervertebral discs (default)
        else {
            result .= "§Intervertebral discs:§" . tok
        }
    }

    return result
}

; [v56] Split a complex disc finding into section-specific sub-phrases.
; Looks for "with", "causing", "resulting in", or "leading to" as the split pivot.
; Effects are then split at ", " and each clause is classified by keyword.
; Returns "" when splitting is not applicable (caller falls through to normal routing).
; Returns "SPLIT:§sec1§text1§sec2§text2..." when splitting succeeds.
; The full original sentence is added to Impression by the caller.
_SplitDiscFinding_SpineMRI(line) {
    ; Locate split pivot word
    if !RegExMatch(line, "(?i)\b(with|causing|resulting in|leading to)\b", &mSplit)
        return ""

    discPart    := Trim(SubStr(line, 1, mSplit.Pos - 1))
    effectsPart := Trim(SubStr(line, mSplit.Pos + mSplit.Len))

    if (discPart = "" || effectsPart = "")
        return ""

    ; Split effects at ", " (comma-space) → individual consequence clauses
    effectTokens := StrSplit(effectsPart, ", ")

    result := "SPLIT:§Intervertebral discs:§" . discPart

    for tok in effectTokens {
        tok := Trim(tok)
        if (tok = "")
            continue
        tokLC := StrLower(tok)
        ; Foraminal keywords take precedence over canal for mixed clauses
        ; (e.g. "bilateral lateral recess stenosis and neural foramina encroachment"
        ;  stays together under Neural foramina:)
        if RegExMatch(tokLC, "foramin|foraminal|encroachment|nerve root|radiculopathy")
            result .= "§Neural foramina:§" . tok
        else if RegExMatch(tokLC, "thecal sac|lateral recess|spinal canal|canal stenosis|central stenosis|spinal stenosis|\bcord\b|myelopathy|myelomalacia|cauda equina|conus")
            result .= "§Spinal canal and cord:§" . tok
        else
            result .= "§Intervertebral discs:§" . tok   ; unclassified → stays with disc
    }

    return result
}

FilterBullet_ExtremityMRI(raw) {
    s := Trim(raw)
    if (s = "")
        return ""
    s := RegExReplace(s, "^[\s\-•\*>]+\s*", "")  ; strip bullet markers including >
    s := RegExReplace(s, "(?i)DDx:\s*.*$", "")     ; strip DDx tail
    s := RegExReplace(s, "(?i)(suggest|recommend|correlat|follow[- ]?up|further\s+evaluation).*$", "")
    return Trim(s)
}

FilterBullet_LegCT(raw) {
    s := Trim(raw)
    if (s = "")
        return ""
    s := RegExReplace(s, "^[\s\-•\*>]+\s*", "")
    low := StrLower(s)
    if RegExMatch(low, "recommend|suggest|follow[- ]?up|correlation")
        return ""
    return s
}

FilterBullet_PelvisCT(raw) {
    s := Trim(raw)
    if (s = "")
        return ""
    s := RegExReplace(s, "^[\s\-•\*>]+\s*", "")
    low := StrLower(s)
    if RegExMatch(low, "recommend|suggest|follow[- ]?up|correlation")
        return ""
    return s
}

; ========================= PELVIS CT: HEURISTIC ROUTING =========================
; Sections: Pelvic ring: | Acetabulum and hip joints: | Sacrum and coccyx: |
;           Sacroiliac joints: | Soft tissues:
HeuristicRoutes_PelvisCT(line) {
    lc := StrLower(Trim(line))
    if (lc = "")
        return ""

    ; Acetabulum and hip joints
    if RegExMatch(lc, "acetabulum|acetabular|femoral\s+head|femoral\s+neck|\bhip\b|hip\s+joint|dislocation|avascular\s+necrosis.*hip|hip.*avascular|osteoarthrit.*hip|hip.*osteoarthrit|effusion.*hip|hip.*effusion")
        return "Acetabulum and hip joints:"

    ; Sacrum and coccyx
    if RegExMatch(lc, "\bsacrum\b|\bsacral\b|\bcoccyx\b|coccygeal|sacral\s+fracture|sacral\s+ala|sacral\s+body|sacral\s+stress")
        return "Sacrum and coccyx:"

    ; Sacroiliac joints
    if RegExMatch(lc, "sacroiliac|\bsi\s+joint\b|sacroiliitis|si\s+joint\s+(fusion|sclerosis|erosion|widening)")
        return "Sacroiliac joints:"

    ; Pelvic ring
    if RegExMatch(lc, "pubis|pubic|ischium|ischial|ilium|\biliac\b|pelvic\s+ring|pelvic\s+fracture|pubic\s+symphysis|pubic\s+rami|pelvic\s+bone")
        return "Pelvic ring:"

    ; Soft tissues — catch-all (muscles, vessels, organs, lymph nodes)
    return "Soft tissues:"
}

FilterBullet_CSpineCT(raw) {
    s := Trim(raw)
    if (s = "")
        return ""
    s := RegExReplace(s, "^[\s\-•\*>]+\s*", "")
    low := StrLower(s)
    if RegExMatch(low, "recommend|suggest|follow[- ]?up|correlation")
        return ""
    return s
}

; ========================= CERVICAL SPINE CT: HEURISTIC ROUTING =========================
; Sections: Alignment: | Vertebral bodies: | Posterior elements: |
;           Intervertebral disc spaces: | Prevertebral soft tissues: | Spinal canal:
HeuristicRoutes_CSpineCT(line) {
    lc := StrLower(Trim(line))
    if (lc = "")
        return ""

    ; Spinal canal (check early — cord/thecal findings must not leak to vertebral bodies)
    if RegExMatch(lc, "spinal\s+canal|canal\s+stenosis|\bcord\b|spinal\s+cord|myelopathy|myelomalacia|thecal\s+sac|cord\s+compression|cord\s+signal|cord\s+contusion|central\s+stenosis|\bcsf\b")
        return "Spinal canal:"

    ; Alignment
    if RegExMatch(lc, "\balignment\b|scoliosis|kyphosis|lordosis|listhesis|spondylolisthesis|retrolisthesis|anterolisthesis|subluxation|curvature|\bopll\b|ossification.*posterior\s+longitudinal|posterior\s+longitudinal.*ossif")
        return "Alignment:"

    ; Intervertebral disc spaces
    if RegExMatch(lc, "\bdisc\b|\bdisk\b|osteophyte|uncovertebral|disc\s+space|disc\s+height|disc\s+desiccation|disc\s+degeneration|schmorl|annular|uncinate|spondylosis|disc\s+bulge|disc\s+protrusion|end.?plate\s+change")
        return "Intervertebral disc spaces:"

    ; Posterior elements
    if RegExMatch(lc, "posterior\s+element|spinous\s+process|\blamina\b|\bfacet\b|articular\s+process|\bpars\b|transverse\s+process|facet\s+joint|facet\s+arthrosis|facet\s+hypertrophy|posterior\s+arch")
        return "Posterior elements:"

    ; Prevertebral soft tissues
    if RegExMatch(lc, "prevertebral|retropharyngeal|paravertebral|paraspinal|soft\s+tissue|abscess|hematoma|edema|lymph\s+node|calcification.*soft|swelling")
        return "Prevertebral soft tissues:"

    ; Vertebral bodies — general bone findings (catch-all for bone pathology)
    if RegExMatch(lc, "vertebra|vertebral|fracture|compression|end.?plate|hemangioma|metastasis|metastas|marrow|height\s+loss|sclerotic|lytic|bone|burst|teardrop|dens|odontoid|atlas|axis|\bc1\b|\bc2\b|\bc3\b|\bc4\b|\bc5\b|\bc6\b|\bc7\b")
        return "Vertebral bodies:"

    return ""
}

FilterBullet_AbdomenCT(raw) {
    s := Trim(raw)
    if (s = "")
        return ""

    ; [v60_fix] Filter out technical notes (** motion artifact ** etc.)
    _preStrip := RegExReplace(s, "^[\s\-•>]+", "")
    _preStrip := Trim(_preStrip)
    if RegExMatch(_preStrip, "^\*\*\s+")
        return ""
    if RegExMatch(StrLower(_preStrip), "motion\s+artifact")
        return ""

    ; Strip leading bullet markers — including ">" used in Abdomen sub-bullets
    s := RegExReplace(s, "^[\s\-•\*>]+\s*", "")
    ; Strip trailing DDx / Suggest / Recommend clauses (keep imaging description)
    s := RegExReplace(s, "(?i)DDx:\s*.*$", "")
    s := RegExReplace(s, "(?i)(suggest|recommend|correlat(e|ion)|follow[- ]?up|further evaluation).*$", "")
    s := Trim(s, " .`t")
    if (s = "")
        return ""
    return s "."
}

; ========================= ABDOMEN CT: HEURISTIC ROUTING =========================
HeuristicRoutes_AbdomenCT(line) {
    lc := StrLower(Trim(line))
    if (lc = "")
        return ""

    ; ── Priority 0: compound-finding overrides (must be checked BEFORE organ-keyword rules) ──

    ; [v60_fix] Biliary duct structures → Biliary (not Liver)
    ;   "Dilated hepatic duct" / "Intrahepatic duct dilatation" / "Dilated IHDs"
    ;   contain "hepatic" which would match Liver at step 1. Override here.
    if RegExMatch(lc, "(hepatic|intrahepatic|intra.hepatic)\s+(bile\s+)?duct|\bihd\b|\bihds\b|common\s+hepatic\s+duct|biliary\s+dil|duct\s+dil")
        return "Biliary system:"

    ; [v60_fix] Mesenteric artery/vein → Vessels (not GI)
    ;   "SMA stenosis" / "Mesenteric artery thrombosis" / "SMV thrombosis"
    ;   contain "mesenteric" which would match GI at step 7. Override here.
    if RegExMatch(lc, "mesenteric\s+(arter|vein)|mesenteric.{0,20}(thrombo|stenosis|aneurysm|occlus|dissect|embol)|\bsma\b|\bsmv\b|\bima\b|\bimv\b")
        return "Vessels and lymph nodes:"

    ; 1) Liver / hepatic (check early — catches "S4/S6 of liver", "hepatic cyst", "dystrophic calcif.*liver")
    if RegExMatch(lc, "liver|hepatic|hepatomegal|cirrhosis|steatosis|fatty liver|hemangiom|hepatocellular|\bs[1-8]\b")
        return "Liver:"

    ; 2) Gallbladder and bile ducts
    if RegExMatch(lc, "gallbladder|gallstone|cholelith|cholecyst|choledoch|bile duct|biliary|hepatic duct|\bcbd\b|\bchd\b|pneumobilia")
        return "Biliary system:"

    ; 3) Pancreas
    if RegExMatch(lc, "pancrea")
        return "Pancreas:"

    ; 4) Spleen
    if RegExMatch(lc, "spleen|splenic|splenomegal")
        return "Spleen:"

    ; 5) Adrenal glands
    if RegExMatch(lc, "adrenal|suprarenal")
        return "Adrenal glands:"

    ; 6) Kidneys, ureters and bladder (merged)
    if RegExMatch(lc, "renal|kidney|ureter|nephrolithiasis|hydronephrosis|pyelocaliceal|angiomyolipoma|\bbladder\b|vesical|urothelial|cystitis|urinary bladder")
        return "Urinary system:"

    ; 7) GI tract (merged Stomach + Duodenum + Bowel)
    ;    "append" catches both "appendectomy" and "appendicitis"
    if RegExMatch(lc, "stomach|gastric|duodenum|duodenal|bowel|intestin|ileum|jejunum|colon|colonic|rectal|rectum|append|sigmoid|cecum|caecum|diverticul|terminal ileum|mesenteric|mesentery|foamy air|intussusception|volvulus|small bowel|large bowel|gastrostomy|ileostomy|colostomy")
        return "GI tract:"

    ; 9) Vessels and lymph nodes (atherosclerosis of aorta/iliacs, portal vein, lymph nodes)
    if RegExMatch(lc, "aorta|aortic|iliac|artery|arteries|vessel|vascular|atherosclerosis|atherosclerotic|lymph node|lymphaden|thromb|embol|stenosis|aneurysm|portal vein|hepatic vein|splenic vein|inferior vena cava|\bivc\b|celiac|mesenteric artery|venous")
        return "Vessels and lymph nodes:"

    ; 10) Peritoneum / ascites
    if RegExMatch(lc, "ascites|ascitic|peritoneum|peritoneal|omentum|omental|free fluid|free air|free gas|pneumoperitoneum|carcinomatosis")
        return "Peritoneum/ascites:"

    ; 11) Reproductive system (uterus, ovary, prostate, seminal vesicle, testis)
    if RegExMatch(lc, "uterus|uterine|endometri|myometri|cervix|cervical uteri|ovary|ovarian|fallopian|adnex|prostate|prostatic|seminal vesicle|testis|testicular|epididymis|vagina|vulva|parametri")
        return "Reproductive system:"

    ; 12) Osseous and soft tissues (spine, body wall, hernias)
    if RegExMatch(lc, "bone|osseous|spine|vertebra|vertebral|rib|fracture|scoliosis|kyphosis|spondylosis|degenerative|disc|lumbar|thoracic|sacral|sacrum|sacroiliac|abdominal wall|subcutaneous|hernia|umbilical|inguinal|hiatal|diaphragm|dystrophic|soft tissue")
        return "Osseous and soft tissues:"

    return "Others:"
}

; ========================= CORE MAPPING ENGINE =========================

GenerateFindings(bulletsText, examType, contrast)
{
    global CFG
    ; [v41] Join wrapped lines before processing
    bulletsText := JoinWrappedLines(bulletsText)
    
    ; [v50] Registry-driven: mapFile, sections, and default template from Registry
    mapFile := ""
    sections := []
    _defaultContent := ""

    if ExamRegistry.Has(examType) {
        _reg := ExamRegistry[examType]
        mapFile         := _reg["mapFile"]
        sections        := _reg["sections"]
        _defaultContent := _reg["defaultContent"]
    } else {
        ; Fallback for exam types not yet in Registry
        _reg            := ExamRegistry["Universal (All Regions)"]
        mapFile         := _reg["mapFile"]
        sections        := ["Findings:"]
        _defaultContent := ""
    }
    EnsureMapFromRegistry(mapFile, _defaultContent)
    
    ; Load section mapping
    secMap := LoadSectionMap(mapFile)
    

    ; [v50] Load synonym map from Registry (optional)
    synMap := Map()
    if ExamRegistry.Has(examType) {
        _synFile := ExamRegistry[examType]["synFile"]
        if (_synFile != "" && FileExist(_synFile))
            synMap := LoadSynonymMap(_synFile)
    }

    if (secMap.Count = 0) {
        return "ERROR: Failed to load mapping file:`n" . mapFile . "`n`nPlease check if the file exists and is in the correct format."
    }
    
    ; Initialize buckets for each section
    buckets := Map()
    for s in sections
        buckets[s] := []
    
    unmatched := []
    
    ; Process each bullet
    for raw in StrSplit(bulletsText, "`n") {
        raw := Trim(raw)
        if (raw = "")
            continue
        
        ; [v50] Apply exam-specific filter from Registry (no if/else needed)
        raw2 := raw
        if ExamRegistry.Has(examType) {
            _filterFn := ExamRegistry[examType]["filterFn"]
            if (_filterFn != "")
                raw2 := _filterFn(raw)
        }
        
        if (raw2 = "")
            continue
 ; Normalize the bullet for matching
key := NormalizeKey(raw2)

; Synonym → v3 key (e.g., "ggo" -> "ground_glass")
if (synMap.Count && synMap.Has(key))
    key := synMap[key]

if (secMap.Has(key))
{
    ; Matched - add to appropriate section
    item := secMap[key]
    sec  := item["sec"]

    ; [v53] Multi-section split (&&): distribute each part to its own bucket
    if (sec = "MULTI") {
        for part in item["parts"] {
            s := part[1]
            t := part[2]
            if buckets.Has(s)
                buckets[s].Push(t)
        }
    } else {
        ; Verify section exists in buckets
        if !buckets.Has(sec)
        {
            sec := AutoDetectSection(key, item["txt"])
            if !buckets.Has(sec)
                sec := sections[1]  ; Fallback to first section
        }
        buckets[sec].Push(item["txt"])
    }
}
else
{
    routedAny := 0

    ; [v50] Heuristic routing from Registry (no hard-coded "Brain CT" check)
    if ExamRegistry.Has(gExamType)
    {
        _heuristicFn := ExamRegistry[gExamType]["heuristicFn"]
        if (_heuristicFn != "")
        {
            sec2 := _heuristicFn(raw2)
            if (sec2 != "")
            {
                ; Normalise: bucket keys always end with ":"
                if (SubStr(sec2, -1) != ":")
                    sec2 .= ":"
                if !buckets.Has(sec2)
                    buckets[sec2] := []
                buckets[sec2].Push(raw2)
                routedAny := 1
            }
        }
    }

    ; Still not routed -> keep unmatched
    if (!routedAny)
        unmatched.Push(raw2)
}
}

; [v53] Brain CT bucket consolidation: suppress redundant ventricular dilatation
;       when a more specific hydrocephalus finding is already in the bucket.
if (Trim(gExamType) = "Brain CT")
    ConsolidateBuckets_BrainCT(buckets)

; Build output from buckets -- format matches Chest CT Router (* / >)
mainBullet := "* "
subPrefix  := "  > "   ; [v50] 2-space indent + "> " for hanging-indent alignment
out := "FINDINGS:`r`n"
for sec in sections {
    ; [v53_3] Leg CT: hide Vessels section on Non-enhanced studies
    if (examType = "Leg CT" && contrast = "Non-enhanced" && sec = "Vessels:")
        continue

    items := buckets[sec]
    if (items.Length > 0) {
        if (items.Length = 1) {
            out .= mainBullet . sec . " " . items[1] . "`n`n"
        } else {
            out .= mainBullet . sec . "`n"
            for item in items
                out .= subPrefix . item . "`n"
            out .= "`n"
        }
    } else {
        ; Empty section - use negative wording (single line)
        negText := GetNegativeWording(sec, gReportMode)
        out .= mainBullet . sec . " " . negText . "`n`n"
    }
}

; Append unmatched bullets if any
if (CFG["ShowUnmatched"] && unmatched.Length) {
    out .= "----------------------------------------`n"
    out .= "UNMATCHED BULLETS (add to dictionary):`n"
    out .= "----------------------------------------`n"
    for u in unmatched
        out .= "* " u "`n"
}

return Trim(out, "`n`t ")
}

; =========================================================================================
; [v53] ConsolidateBuckets_BrainCT(buckets)
;   Post-processing pass on Brain CT buckets.
;   Rule: if Ventricular system already contains a hydrocephalus finding,
;         remove redundant plain ventricular-dilatation entries from the same bucket.
; =========================================================================================
ConsolidateBuckets_BrainCT(buckets) {
    sec := "Ventricular system:"
    if !buckets.Has(sec)
        return

    vItems := buckets[sec]
    hasHydrocephalus := false
    for item in vItems {
        if RegExMatch(StrLower(item), "hydrocephalus")
            hasHydrocephalus := true
    }
    if !hasHydrocephalus
        return

    ; Remove entries that are purely a ventricular-dilatation statement
    dilatationRx := "i)^(mild\s+|moderate\s+|severe\s+)?ventricular\s+dilat"
    filtered := []
    for item in vItems {
        if !RegExMatch(item, dilatationRx)
            filtered.Push(item)
    }
    buckets[sec] := filtered
}

; =========================================================================================
; =========================================================================================
; [v34] P2 -- GetNegativeWording(section, mode)
;   Returns clinically appropriate negative template for empty sections.
;   mode: "General" | "Oncology"
;   Sections not listed here fall back to "Unremarkable."
; =========================================================================================

GetNegativeWording(section, mode, hasPrior := -1) {
    global gReportMode, gExamType, gHasPrior
    isOnco := (mode = "Oncology")
    ; [v59_4] Use gHasPrior if caller didn't pass hasPrior explicitly
    _hasPrior := (hasPrior = -1) ? gHasPrior : hasPrior

    if (section = "Lung parenchyma:")
        return isOnco
            ? (_hasPrior ? "No new or enlarging pulmonary lesion identified."
                         : "No imaging evidence of active pulmonary lesion.")
            : "No focal lung lesion identified."

    if (section = "Pleura:")
        return "No pleural effusion or pneumothorax."

    if (section = "Mediastinum and lymph nodes:")
        return "No enlarged mediastinal or hilar lymph nodes."

    if (section = "Osseous and soft tissues:")
        return isOnco ? (_hasPrior ? "No new destructive osseous lesion identified."
                                   : "No destructive osseous lesion identified.")
                      : "No destructive osseous lesion identified."
    ; --- Brain CT specific ---
    ; [v54] Use radiology-specific negatives for Brain CT sections.
    if (Trim(gExamType) = "Brain CT") {
        switch section {
            case "Brain parenchyma:":
                return "No focal parenchymal lesion, acute territorial infarction, or intracranial hemorrhage."
            case "Ventricular system:":
                return "Normal in size and configuration."
            case "Extra-axial spaces:":
                return "No abnormal extra-axial collection."
            case "Basal cisterns:":
                return "Patent."
            case "Cerebral vasculature:":
                return "No hyperdense vessel sign."
            case "Calvarium and skull base:":
                return "No acute fracture identified."
            case "Paranasal sinuses and mastoid air cells:":
                return "Clear."
            case "Ocular / Others:":
                return "Unremarkable."
        }
    }

    ; --- Leg CT (General) ---

    if (section = "Bones:")
        return "No acute fracture or destructive bony lesion."

    if (section = "Joints:")
        return "No significant joint effusion or malalignment."

    if (section = "Soft tissues:")
        return "No focal intramuscular hematoma or abnormal fluid collection. No organized abscess or subcutaneous emphysema."

    if (section = "Vessels:")
        return "No evidence of active contrast extravasation."

    ; --- Spine MRI specific ---
    if (section = "Alignment:")
        return "Normal spinal alignment."

    if (section = "Vertebral bodies:")
        return isOnco ? (_hasPrior ? "No new suspicious vertebral lesion."
                                   : "No suspicious vertebral lesion.")
                      : "Normal height and signal intensity of the vertebral bodies."

    if (section = "Intervertebral discs:")
        return "Normal disc height and signal intensity."

    if (section = "Spinal canal and cord:")
        return isOnco ? "No significant canal stenosis or cord signal abnormality."
                      : "No significant central canal stenosis or cord compression."

    if (section = "Neural foramina:")
        return "No significant foraminal stenosis."

    if (section = "Paraspinal soft tissues:")
        return "Unremarkable."

    ; --- Abdomen CT / MRI specific ---
    if (section = "Liver:")
        return isOnco ? (_hasPrior ? "No new hepatic lesion identified."
                                   : "No evident hepatic lesion identified.")
                      : "No focal hepatic lesion identified."

    if (section = "Biliary system:")
        return "No cholelithiasis or biliary dilatation."

    if (section = "Urinary system:")
        return "No hydronephrosis, obstructing stone, or focal bladder lesion."

    if (section = "Vessels and lymph nodes:")
        return isOnco ? "No significant vascular abnormality or lymphadenopathy."
                      : "No significant vascular abnormality or enlarged lymph nodes."

    if (section = "Peritoneum/ascites:")
        return "No ascites or free peritoneal air."

    if (section = "Reproductive system:")
        return "No significant pelvic organ abnormality."

    if (section = "Others:")
        return ""

    ; All other sections: conservative fallback
    return "Unremarkable."
}

; =========================================================================================
; [v34] P4 -- DetectOncologyContext(text)
;   Returns true if text contains follow-up / post-treatment / oncology keywords.
; =========================================================================================

DetectOncologyContext(text) {
    t := StrLower(text)
    return RegExMatch(t, "follow[\s\-]*up|post[\s\-]op|post[\s\-]treatment|post[\s\-]chemo|post[\s\-]radiation|post[\s\-]resection|chemotherapy|immunotherapy|targeted[\s\-]*therapy|malignancy|metasta|recurrence|remission|staging|restaging|surveillance|s/p|s\.p\.|known\s*(cancer|carcinoma|malignancy|tumor|tumour)")
}

; =========================================================================================
; [v34] P4 -- AutoSetModeFromContext(clinicalText, bulletsText)
;   Auto-switches gReportMode to "Oncology" if context detected.
;   Does NOT override if gModeManual = true (user changed manually).
;   Also syncs the GUI dropdown to reflect the change.
; =========================================================================================

AutoSetModeFromContext(clinicalText, bulletsText) {
    global gReportMode, gModeManual, gDdlMode

    if gModeManual
        return   ; user chose explicitly -- don't touch

    combined := clinicalText . " " . bulletsText
    if DetectOncologyContext(combined) {
        gReportMode := "Oncology"
        try gDdlMode.Choose(2)   ; sync dropdown; ignore if GUI not ready
    } else {
        gReportMode := "General"
        try gDdlMode.Choose(1)
    }
}

; =========================================================================================
; [v34] P5 -- PrependClinicalInfo(findingsText, clinicalText)
;   Inserts "Clinical Information: <text>" as first line of findings block.
;   Skipped if clinicalText is blank.
; =========================================================================================

PrependClinicalInfo(findingsText, clinicalText) {
    ct := Trim(clinicalText)
    if (ct = "")
        return findingsText
    ; [v60_fix] Flatten multi-line clinical text into single line
    ct := RegExReplace(ct, "\r?\n", "; ")
    ct := RegExReplace(ct, ";\s*;\s*", "; ")
    ct := Trim(Trim(ct), ";")
    ct := Trim(ct)
    prefix := "Clinical Information: " . ct . "`n`n"
    return prefix . findingsText
}

; =========================================================================================

; =========================
; [v57_7] Impression Summary renderer
; =========================
_IMP_IsNonFindingSentence(s) {
    s2 := StrLower(Trim(s))
    if RegExMatch(s2, "^(no\s+(significant\s+)?interval\s+change|stable\s+compared|unchanged\s+compared|decreased\s+compared|increased\s+compared)")
        return true
    ; [v60_fix] Added "please" — "Please correlate..." is a non-finding recommendation
    if RegExMatch(s2, "^(recommend|suggest|advise|please|follow[- ]?up|clinical\s+correlation|further\s+evaluation)\b")
        return true
    return false
}

_IMP_ExtractFirstSize(s) {
    ; Handle size ranges like "0.3-0.5cm" or "0.3-0.5 cm"
    if RegExMatch(s, "i)\b(\d+(?:\.\d+)?\s*-\s*\d+(?:\.\d+)?)\s*(cm|mm)\b", &mRange)
        return RegExReplace(mRange[1], "\s", "") " " mRange[2]
    if RegExMatch(s, "i)\b(\d+(?:\.\d+)?)\s*(cm|mm)\b", &m)
        return m[1] " " m[2]
    return ""
}

_IMP_StripSeImAndRefs(s) {
    s := RegExReplace(s, "i)\s*\(\s*[^)]*(se\s*/\s*im|se|im|series|image)[^)]*\)\s*", " ")
    s := RegExReplace(s, "i)\b(se\s*/\s*im|se|im)\s*:\s*\d+\s*/\s*\d+\b", "")
    return Trim(RegExReplace(s, "\s{2,}", " "))
}

_IMP_ExtractDDxClause(s, &coreFinding) {
    coreFinding := Trim(s)
    ddx := ""
    if RegExMatch(s, "i)\bDDx:\s*(.+)$", &m) {
        ddx := Trim(m[1], " .`t")
        ; [v60_fix] Keep trailing Suggest/Recommend with DDx content so impression stays merged
        ; (previously stripped; user wants "DDx: ... Suggest clinical correlation" as one unit)
        coreFinding := Trim(RegExReplace(s, "i)\bDDx:\s*.+$", ""), " .`t")
        return ddx
    }
    ; [v60_fix] "Suspect" is NOT extracted as a separate clause — it stays in-place
    ; so "Suspect X" remains "Suspect X" and does not get moved to the end.
    ; Only management/recommendation keywords are extracted and re-appended.
    if RegExMatch(s, "i)\b(Consider|Suggest|Recommend|Advise|Follow[- ]?up|Further evaluation|Clinical correlation)\b.*$", &m2) {
        ; [v60_fix] If the matched keyword is "Follow-up" preceded by "further/and/for",
        ;   it's part of a compound phrase ("further follow-up") — don't extract as DDx clause.
        ;   Extracting splits "...further follow-up" → core "...further." + ddx "follow-up."
        ;   causing malformed output like "further. follow-up."
        if RegExMatch(m2[1], "i)^Follow[- ]?up$") {
            _beforeKw := SubStr(s, 1, m2.Pos - 1)
            if RegExMatch(_beforeKw, "i)\b(further|and|for)\s*$") {
                coreFinding := Trim(s)
                return ""
            }
        }
        ddx := Trim(m2[0], " .`t")
        coreFinding := Trim(SubStr(s, 1, m2.Pos-1), " .`t")
        if (StrLen(coreFinding) < 6)
            coreFinding := ""
        return ddx
    }
    return ""
}

Impression_SummaryOnly(sentence, keepSize := true) {
    s := Trim(sentence)
    s := RegExReplace(s, "^[\s\-\x{2022}>\*]+\s*", "")
    if (s = "")
        return ""
    if _IMP_IsNonFindingSentence(s)
        return RTrim(s, ".") "."
    core := ""
    ddx := _IMP_ExtractDDxClause(s, &core)
    ; Extract size BEFORE stripping Se/Im (parenthetical like "(0.3cm, Se/Im: 5/75)" contains both)
    size := ""
    if keepSize
        size := _IMP_ExtractFirstSize(core)
    core := _IMP_StripSeImAndRefs(core)
    core := RegExReplace(core, "i)\s*\([^)]*\)\s*", " ")
    core := Trim(RegExReplace(core, "\s{2,}", " "), " .`t")
    out := core
    if (keepSize && size != "") {
        ; Match "2.9cm" or "2.9 cm" - normalize spaces in pattern
        _sizeRx := RegExReplace(size, "\s+", "\s*")
        if !RegExMatch(out, "i)" _sizeRx)
            out .= " (" size ")"
    }
    out := Trim(out, " .`t")
    if (out != "" && SubStr(out, -1) != ".")
        out .= "."
    if (ddx != "") {
        ddx := Trim(ddx, " .`t")
        if (ddx != "" && SubStr(ddx, -1) != ".")
            ddx .= "."
        ; [v59_1] If ddx starts with Suggest/Suspect/Consider, it already has its own label
        if RegExMatch(ddx, "i)^\s*(Suspect|Consider|Suggest|Recommend|Advise|Follow[- ]?up|Further evaluation|Clinical correlation)\b")
            out .= " " ddx
        else
            out .= " DDx: " ddx   ; [v59] restore "DDx: " prefix so label is not lost in impression
    }
    return Trim(out)
}

IsAlwaysNonImpressionFinding(text) {
    t := StrLower(Trim(text))
    if (t = "")
        return false

    ; Explicit benign assessment should never enter impression
    if RegExMatch(t, "i)\b(suspect\s+benign|benign\s+entit|benign\s+lesion|benign\s+nodule|likely\s+benign)\b")
        return true

    ; CKD/chronic renal disease is chronic background information
    if RegExMatch(t, "i)\b(ckd|chronic\s+kidney\s+disease|chronic\s+renal\s+(disease|insufficiency|failure))\b")
        return true

    ; Explicit stability sentence requested to stay out of impression
    if RegExMatch(t, "i)\bno\s+significant\s+(interval\s+)?change\s+(of|in|to)\b")
        return true

    ; Cholelithiasis alone is chronic/incidental unless active acute cholecystitis co-exists
    if RegExMatch(t, "i)\b(cholelithiasis|gallstones?)\b") {
        if RegExMatch(t, "i)\b(no|without)\s+(acute\s+)?cholecystitis\b")
            return true
        if !RegExMatch(t, "i)\b(acute\s+)?cholecystitis\b")
            return true
    }

    ; Fibrosis/pneumatocele alone should not enter impression.
    ; Keep sentence only when accompanied by strong acute/significant terms.
    if RegExMatch(t, "i)\b(fibrosis|fibrotic|pneumatocele)\b") {
        _acuteCoRx := "i)\b(mass|nodule|tumou?r|cancer|carcinoma|neoplasm|metasta|consolidation|pneumonia|pneumonitis|effusion|pneumothorax|embol|dissect|aneurysm|thrombos|obstruct|perforation|abscess|hemorrhag|hematoma|infarct|appendicitis|cholecystitis|new|increas|enlarg|worsen|progress)\b"
        if !RegExMatch(t, _acuteCoRx)
            return true
    }

    ; [v60_fix] Hepatic/renal/splenic/simple cyst — incidental unless concerning features
    ;   "Suspect hepatic cyst in the S2-3 and S6." → no acute features → excluded
    ;   "Hepatic cyst, enlarging" → \benlarg → kept in impression
    if RegExMatch(t, "i)\b(hepatic|liver|renal|kidney|splenic|simple)\s+cysts?\b") {
        if !RegExMatch(t, "i)\b(new|increas|enlarg|worsen|progress|complex|septate|solid|hemorrhag|ruptur|infect)\b")
            return true
    }

    ; [v60_fix] Adrenal nodule/adenoma — incidental unless concerning features
    ;   "Adrenal nodule, without interval change" → excluded
    ;   "Adrenal nodule, enlarging" → \benlarg → kept in impression
    if RegExMatch(t, "i)\badrenal\s+(nodule|adenoma|cyst|myelolipoma)") {
        if !RegExMatch(t, "i)\b(new|increas|enlarg|worsen|progress|suspic|malignan|metasta)\b")
            return true
    }

    return false
}

; [v60_fix] Cross-sentence check: compression fracture at a vertebral level
;   is treated (chronic) when another bullet mentions vertebroplasty/kyphoplasty
;   at the same level.
;   Example: "Suspect compression fracture at L1 vertebra."
;          + "Status post vertebroplasty at L1."
;          → fracture is treated → exclude from impression
_IsTreatedCompressionFracture(text, bulletsText) {
    _low := StrLower(Trim(text))
    _btLow := StrLower(bulletsText)

    ; Only applies to compression fracture sentences
    if !RegExMatch(_low, "compression\s+fracture")
        return false

    ; Quick check: any vertebroplasty/kyphoplasty in the entire bullets?
    if !RegExMatch(_btLow, "vertebroplast|kyphoplast")
        return false

    ; Collect text from vertebroplasty/kyphoplasty bullet lines
    _vpText := ""
    for _bLine in StrSplit(_btLow, "`n") {
        _bLine := Trim(_bLine)
        if RegExMatch(_bLine, "vertebroplast|kyphoplast")
            _vpText .= _bLine " "
    }
    if (_vpText = "")
        return false

    ; Extract vertebral levels from the fracture sentence (e.g. t12, l1, l2, c3, s1)
    ; and check if the same level appears in any vertebroplasty line
    _startPos := 1
    while RegExMatch(_low, "\b([tlsc]\d+)\b", &_lvlM, _startPos) {
        _lvl := _lvlM[1]
        if RegExMatch(_vpText, "\b" _lvl "\b")
            return true
        _startPos := _lvlM.Pos + StrLen(_lvl)
    }

    return false
}

BuildImpressionFromList(list, impressionBase := "", bulletsText := "") {
    ; Build a single IMPRESSION block:
    ; 1) numbered raw-sentence items from router (dedup)
    ; 2) filter out pure Recommend/Suggest lines when real findings are present
    ; 3) append the rule-based impression (without duplicate "IMPRESSION:" header) as the last item if present
    ; [v60_fix] Added "please" — "Please correlate..." is a pure recommendation
    ;   that should not be a standalone impression item.
    ;   Note: "suggest" is intentionally NOT included — "Suggest clinical correlation"
    ;   carries clinical intent and should be preserved in impression (see Fix #5).
    _pureRecommendRx := "i)^(recommend|advise|consider|please|follow[\-\s]?up)\b"
    _seen := Map()
    _allItems := []
    for s in list {
        t := Trim(s)
        if (t = "")
            continue
        k := StrLower(t)
        if (_seen.Has(k))
            continue
        _seen[k] := 1
        _allItems.Push(t)
    }
    ; Check if there are real findings (non-pure-recommend items)
    _hasRealFindings := false
    for t in _allItems {
        if !RegExMatch(t, _pureRecommendRx)
            _hasRealFindings := true
    }
    _items := []
    for t in _allItems {
        ; If real findings exist, suppress pure management-action lines
        if (_hasRealFindings && RegExMatch(t, _pureRecommendRx))
            continue
        ; [v60_fix] Keep "Suggest clinical correlation and follow-up" in impression
        ; (previously suppressed; user wants original impression recommendations preserved)
        ; Only suppress pure management actions (recommend/advise/consider)
        ; but keep Suggest lines as they carry clinical intent from original impression
        _items.Push(t)
    }

    base := Trim(impressionBase)
    if (base != "") {
        ; strip leading IMPRESSION header if present
        if InStr(base, "IMPRESSION:") = 1 {
            base := Trim(SubStr(base, StrLen("IMPRESSION:") + 1))
        }
        base := Trim(base, "`r`n`t ")
        ; [v59_fix] Split impressionBase into individual lines and add each separately
        ; (previously pushed entire block as one item → caused duplicate numbered items)
        for _baseLine in StrSplit(base, "`n") {
            _bl := Trim(_baseLine, " `t`r.")
            ; Strip leading numbered prefix "1. " "2. " etc.
            _bl := RegExReplace(_bl, "^\d+\.\s+", "")
            _bl := Trim(_bl)
            if (StrLen(_bl) < 8)
                continue
            k2 := StrLower(_bl)
            if (_seen.Has(k2))
                continue
            ; Also skip if any existing item contains or is contained by this line (substring dedup)
            _isDup := false
            for _existItem in _items {
                _ek := StrLower(Trim(_existItem))
                if (InStr(_ek, k2) || InStr(k2, _ek)) {
                    _isDup := true
                    break
                }
            }
            if (_isDup)
                continue
            _seen[k2] := 1
            if (SubStr(_bl, -1) != ".")
                _bl .= "."
            _items.Push(_bl)
        }
    }

    ; [v60_fix] When no prior study, remove pure stability/no-change items from impression
    ; (e.g. "No interval change compared with prior study." should not appear without prior)
    global gHasPrior
    if (!gHasPrior && _items.Length) {
        _ncRx := "i)^\s*(no\s+(significant\s+)?(interval\s+)?change|unchanged\s+compared|stable\s+compared|no\s+change\s+compared)"
        _ncFiltered := []
        for t in _items {
            if RegExMatch(t, _ncRx)
                continue
            _ncFiltered.Push(t)
        }
        _items := _ncFiltered
    }

    ; [v60_fix] Substring dedup within _items: if a shorter item is entirely
    ; contained in a longer item, suppress the shorter one
    ; (e.g. standalone "Suggest clinical correlation" already inside DDx sentence)
    if (_items.Length > 1) {
        _subDeduped := []
        for i, t in _items {
            tLow := StrLower(Trim(t))
            _isSubstr := false
            for j, other in _items {
                if (i = j)
                    continue
                oLow := StrLower(Trim(other))
                if (StrLen(oLow) > StrLen(tLow) && InStr(oLow, tLow)) {
                    _isSubstr := true
                    break
                }
            }
            if (!_isSubstr)
                _subDeduped.Push(t)
        }
        _items := _subDeduped
    }

    ; Shared exclusions: benign/CKD/stability-of/fibrosis-pneumatocele/cholelithiasis-only
    if (_items.Length) {
        _filteredItems := []
        for t in _items {
            if IsAlwaysNonImpressionFinding(t)
                continue
            ; [v60_fix] Cross-sentence: compression fracture at a vertebroplasty level → chronic
            if _IsTreatedCompressionFracture(t, bulletsText)
                continue
            _filteredItems.Push(t)
        }
        _items := _filteredItems
    }

    if (!_items.Length)
        return ""

    ; [v60_fix] Re-sort merged items by position in original bullets
    ; so impression follows the same order as the original report.
    ; Match each impression item against each bullet LINE by keyword overlap score.
    ; The bullet line with the highest keyword overlap determines the item's position.
    ; This is more robust than single-keyword matching which can cross-contaminate
    ; (e.g. "bilateral" in bullet 1 matching an impression item from bullet 3).
    global gClinicalText
    if (bulletsText != "" && _items.Length > 1) {
        ; Split bullets into lines with cumulative character positions
        _bulletLines := []
        _cumPos := 1
        for _bLine in StrSplit(bulletsText, "`n") {
            _bulletLines.Push({text: StrLower(Trim(_bLine)), pos: _cumPos})
            _cumPos += StrLen(_bLine) + 1
        }

        _posArr := []
        for idx, item in _items {
            _bestPos := 999999
            ; [v60_fix] Strip leading "Suspect(ed) " first so the finding noun remains
            _itemClean := RegExReplace(StrLower(item), "i)^\s*suspect(ed)?\s+", "")
            _itemClean := RegExReplace(_itemClean, "i)\b(ddx|suspect|suggest|recommend|advise|consider|follow[- ]?up|further evaluation|clinical correlation)\b.*$", "")
            _itemClean := RegExReplace(_itemClean, "\([^)]*\)", "")
            _itemClean := Trim(_itemClean, " .,`t")
            ; Extract key words (>4 chars)
            _words := []
            for _w in StrSplit(RegExReplace(_itemClean, "[^a-z0-9]+", " "), " ") {
                if (StrLen(_w) > 4)
                    _words.Push(_w)
            }
            ; Score each bullet line by how many key words it contains
            _bestScore := 0
            for _bl in _bulletLines {
                _score := 0
                for _w in _words {
                    if InStr(_bl.text, _w)
                        _score += 1
                }
                if (_score > _bestScore) {
                    _bestScore := _score
                    _bestPos := _bl.pos
                }
            }
            _posArr.Push({pos: _bestPos, idx: idx, item: item})
        }
        ; Bubble sort by position (stable: preserves order for equal positions)
        _n := _posArr.Length
        Loop _n - 1 {
            _i := A_Index
            _j := _i + 1
            while (_j <= _n) {
                if (_posArr[_j].pos < _posArr[_i].pos) {
                    _tmp := _posArr[_i]
                    _posArr[_i] := _posArr[_j]
                    _posArr[_j] := _tmp
                }
                _j += 1
            }
        }
        _items := []
        for _e in _posArr
            _items.Push(_e.item)
    }
    _sorted := _items
    out := "IMPRESSION:`n"
    i := 0
    _seenSum := Map()
    for it in _sorted {
        sum := Impression_SummaryOnly(it, true)
        if (sum = "")
            sum := it
        k := StrLower(Trim(sum))
        if _seenSum.Has(k)
            continue
        _seenSum[k] := 1
        i += 1
        out .= i ". " sum "`n"
    }
    return RTrim(out, "`n")
}

; [v41] AUTO-IMPRESSION GENERATOR
;   Rule-based: filters actionable findings from bullet input.
;   1. Strips chronic/incidental findings (atherosclerosis, spondylosis, etc.)
;   2. Strips recommendation/management sentences
;   3. Keeps: acute, significant, or clinical-question-related findings
;   4. If clinical info provided, boosts findings that keyword-match clinical question
;   Format: ≤2 items → prose; ≥3 items → numbered list
; =========================================================================================


; =========================
; [v53] No-prior Chest CT: collect Lung/Airways/Pleura raw sentences into Impression list
; - Keeps DDx / Suggest / Recommend tails (decision layer)
; [v60_fix] Added:
;   1. Chronic/incidental filter (bleb, bulla, cyst, etc. excluded)
;   2. Catch acute non-lung findings (e.g. metastatic lymphadenopathy in abdomen)
; =========================
GenerateImpression_LungNoPrior(bulletsText) {
    bulletsText := JoinWrappedLines(bulletsText)
    imp := []

    ; [v60_fix] Definitely chronic items to EXCLUDE from no-prior impression
    ; (mirrors definitelyChronicRx in GenerateImpression but scoped to common lung incidentals)
    _chronicExcludeRx := "i)\bbulla[e]?\b|\bbleb\b|simple cyst|calcified granuloma|calcif\w* nodule"
                      .  "|atheroscleros|spondylosis|degenerative|old.{0,20}fracture|healed.{0,20}fracture|fracture.{0,20}old|fracture.{0,20}healed"
                      .  "|hiatal hernia|diverticul|tortuous|cardiomegal"
                      .  "|suspect benign|benign entit|benign lesion|likely benign"
                      .  "|fatty liver|hepatic steatosis|steatosis"  ; [v60_fix] fatty liver → incidental
                      .  "|osteoporos|osteopenia"                    ; [v60_fix] osteoporosis/osteopenia → incidental
                      .  "|vertebroplasty|kyphoplasty"              ; [v60_fix] vertebroplasty/kyphoplasty → chronic
                      .  "|^subsegmental\s+atelectasis"  ; [v60_fix] subsegmental atelectasis at start → incidental
                      .  "|adrenal\s+(nodule|adenoma|cyst|myelolipoma)"  ; [v60_fix] adrenal nodule/adenoma → incidental

    ; [v60_fix] Acute keywords for non-lung findings that should still reach impression
    _acuteRx := "i)mass|tumou?r|cancer|carcinoma|neoplasm|metasta|abscess|hemorrhag|hematoma"
             .  "|obstruct|perforation|dissect|aneurysm|thrombos"

    for raw in StrSplit(bulletsText, "`n") {
        line := Trim(raw)
        if (line = "")
            continue
        ; Strip bullet markers only
        line := RegExReplace(line, "^[\s\-•\*>]+\s*", "")
        line := Trim(line)
        if (line = "")
            continue

        low := StrLower(line)

        ; Shared hard exclusions requested by workflow policy
        if IsAlwaysNonImpressionFinding(line)
            continue

        ; [v60_fix] Cross-sentence: compression fracture at a vertebroplasty level → chronic
        if _IsTreatedCompressionFracture(line, bulletsText)
            continue

        ; [v60_fix] Skip definitely chronic/incidental findings
        ; [v60_fix] BUT strong acute patterns override chronic (e.g. "new cardiomegaly", malignancy)
        if RegExMatch(low, _chronicExcludeRx) {
            _acuteOverrideRx2 := "\bnew\s|\bincreas|\benlarg|\bworsen|\bprogress|\bsuspic"
                              .  "|\bcanc|\bcarcinom|\bmalignan|\bneoplasm|\bmetasta"
                              .  "|cholecystitis|appendicitis"
                              .  "|\bacute\b"
            if !RegExMatch(low, _acuteOverrideRx2)
                continue
        }

        sec := InferSectionFromText(line)

        ; Primary: Lung / Airways / Pleura findings
        if (sec = "Lung parenchyma:" || sec = "Airways:" || sec = "Pleura:") {
            l := RTrim(line)
            if (SubStr(l, -1) != ".")
                l .= "."
            imp.Push(l)
            continue
        }

        ; [v60_fix] Secondary: non-lung acute findings (e.g. metastatic lymphadenopathy)
        ; These are significant even though not in lung/airway/pleura sections
        if RegExMatch(low, _acuteRx) {
            l := RTrim(line)
            if (SubStr(l, -1) != ".")
                l .= "."
            imp.Push(l)
        }
    }

    if (imp.Length = 0)
        return ""

    out := "IMPRESSION:`n"
    n := 0
    for item in imp {
        n += 1
        out .= n . ". " . item . "`n"
    }
    return RTrim(out, "`n")
}

; =========================
; [v53] No-prior Brain CT: detect communicating hydrocephalus → dedicated impression
; =========================
GenerateImpression_BrainCTNoPrior(bulletsText) {
    lc := StrLower(bulletsText)
    if !RegExMatch(lc, "communicating hydrocephalus")
        return ""

    ; Preserve "Suspect" prefix if present in original bullet
    suspect := RegExMatch(lc, "suspect.{0,15}communicating") ? "Suspect " : ""

    hasPeriventricular := RegExMatch(lc, "periventricular lucen")
    if (hasPeriventricular)
        return "IMPRESSION:`n" . suspect . "Communicating hydrocephalus with periventricular lucencies."
    else
        return "IMPRESSION:`n" . suspect . "Communicating hydrocephalus."
}

GenerateImpression(bulletsText, clinicalText, mode, hasPrior := 0) {
    ; [v41] Join wrapped lines before processing
    bulletsText := JoinWrappedLines(bulletsText)

    ; [v53] Prior-aware: when NO prior and Chest CT, use Lung/Airways/Pleura raw list
    global gExamType
    if (!hasPrior && Trim(gExamType) = "Chest CT") {
        lungImp := GenerateImpression_LungNoPrior(bulletsText)
        if (lungImp != "")
            return lungImp
    }

    ; [v53] Prior-aware: when NO prior and Brain CT, detect communicating hydrocephalus
    if (!hasPrior && Trim(gExamType) = "Brain CT") {
        brainImp := GenerateImpression_BrainCTNoPrior(bulletsText)
        if (brainImp != "")
            return brainImp
    }

    actionable          := []
    chronicForOncology  := []   ; [v50] chronic findings kept for Oncology-mode impression
    clinLow := StrLower(clinicalText)

    ; ── Definitely chronic/incidental: these ALWAYS override acuteRx ────────
    ;   (e.g. "calcified nodule" is never promoted despite "nodule" being acute)
    definitelyChronicRx
              := "atheroscleros|spondylosis|degenerative|old.{0,20}fracture|healed.{0,20}fracture|fracture.{0,20}old|fracture.{0,20}healed"
              .  "|calcified granuloma|calcif\w* nodule|hiatal hernia|diverticul|tortuous"
              .  "|visible lymph node|subcentimeter lymph|small lymph node"
              .  "|bulla[e]?\b|bleb|simple cyst|renal cyst|hepatic cyst|splenic cyst"
              .  "|cardiomegal|lymphangioma|pseudocyst"
              .  "|breast.{0,10}(nodule|calcif|cyst)|cystic lesion.{0,30}pancrea"
              .  "|cholelithiasis|gallstone"
              .  "|thyroid|goiter|goitre"                  ; [v50] thyroid/goiter → incidental
              .  "|leiomyoma|uterine fibroid|bone island"   ; [v50] other common incidentals
              .  "|osteoporos|osteopenia"                    ; [v60_fix] osteoporosis/osteopenia → incidental
              .  "|fatty liver|hepatic steatosis|steatosis"  ; [v60_fix] fatty liver → incidental
              .  "|vertebroplasty|kyphoplasty"              ; [v60_fix] vertebroplasty/kyphoplasty → chronic (treated fracture)
              .  "|suspect benign|benign entit|benign lesion|benign nodule|likely benign"  ; [v50] benign assessment → never actionable
              .  "|^subsegmental\s+atelectasis"  ; [v60_fix] subsegmental atelectasis at sentence start → incidental
              .  "|adrenal\s+(nodule|adenoma|cyst|myelolipoma)"  ; [v60_fix] adrenal nodule/adenoma → incidental (stable finding)

    ; ── Stability-only patterns: chronic ONLY when no acute finding is present ─
    ;   e.g. "Lung cancer... without interval change" → acute (cancer) takes precedence.
    ;        "Post-radiation change without interval change" → no acute → chronic.
    stabilityRx := "stationary|without.{0,15}(interval |)change|stable\b|unchanged"

    ; ── Negative / normal patterns to SKIP entirely ──────────────────────
    negativeRx := "unremarkable|no .{0,20}(identified|noted|seen|evidence)"
               .  "|within normal|no significant|no focal|no acute"
               .  "|no enlarged|no destructive|no pleural effusion|no pneumothorax"

    ; ── Actionable / acute patterns that ALWAYS make it to impression ────
    acuteRx := "mass|nodule|tumou?r|cancer|carcinoma|neoplasm|metasta"
            .  "|consolidation|pneumonia|pneumonitis|effusion|pneumothorax|embol"
            .  "|dissect|aneurysm|thrombos"
            .  "|obstruct|perforation|abscess|hemorrhag|hematoma"
            .  "|new |increas|enlarg|worsen|progress"
            .  "|cholelithiasis|cholecystitis|choledoch|\bchd\b|\bcbd\b|bile duct|pancreatitis|appendicitis"
            .  "|stenosis|occlus"
            .  "|infarct"
            .  "|atrophy|ventriculomegal|ventricular dilat|hydrocephal|encephalomalac"  ; [v60_fix] Brain CT significant findings → impression-worthy

    ; ── Recommendation tails to truncate ─────────────────────────────────
    tailRx := "i)\.\s*(suggest|recommend|advise|consider|please|clinical correlation|follow[- ]?up|further).*$"

    for raw in StrSplit(bulletsText, "`n") {
        raw := Trim(raw)
        if (raw = "")
            continue

        ; Strip bullet markers
        clean := RegExReplace(raw, "^[\s\-•\*>]+\s*", "")
        if (clean = "")
            continue

        low := StrLower(clean)

        ; Shared hard exclusions requested by workflow policy
        if IsAlwaysNonImpressionFinding(clean)
            continue

        ; Skip pure recommendations (entire line is a recommendation)
        if RegExMatch(low, "^(recommend|suggest|advise|consider|please|follow[- ]?up|further evaluation|clinical correlation)\b")
            continue

        ; Skip negative/normal findings UNLESS they are clinically significant rule-outs
        ; Rule-outs like "No dissection" or "No PE" directly answer clinical questions
        isRuleOut := RegExMatch(low, "dissect|embol|\bpe\b|\bpte\b|thromb|aneurysm|malignan|metasta|hemorrhag|pneumothorax")
        ; Fracture is rule-out only if NOT old/healed
        if (!isRuleOut && RegExMatch(low, "fracture") && !RegExMatch(low, "old.{0,20}fracture|healed.{0,20}fracture|fracture.{0,20}old|fracture.{0,20}healed"))
            isRuleOut := true
        if (!isRuleOut && RegExMatch(low, negativeRx))
            continue

        ; Truncate trailing recommendation sentences
        ;   "Consolidation at bilateral lower lobes. Suggest clinical correlation."
        ;   → "Consolidation at bilateral lower lobes."
        clean := RegExReplace(clean, tailRx, ".")

        ; Re-evaluate after truncation
        clean := Trim(clean)
        low := StrLower(clean)
        if (StrLen(clean) < 8)
            continue

        ; [v59_2] If finding has an explicit DDx clause, treat as clinically significant
        ; (radiologist explicitly provided differential → should always appear in impression)
        hasDDx := RegExMatch(low, "i)\bddx\s*:")

        ; [v50] Two-tier chronic check:
        ;   definitelyChronicRx → chronic (but can be overridden by acuteOverrideRx)
        ;   stabilityRx         → chronic ONLY when no acute finding also present
        ;   Rationale: "Lung cancer... without interval change" has acuteRx (cancer)
        ;   AND stabilityRx, but should go to impression as a STABLE CANCER finding.
        isDefinitelyChronic := RegExMatch(low, definitelyChronicRx)
        ; We need isAcute before isChronic can be computed; detect it here early
        _isAcutePeek := RegExMatch(low, acuteRx)

        ; [v60_fix] Acute override: strong acute indicators trump definitelyChronicRx.
        ;   "New cardiomegaly" → "new" overrides "cardiomegal" chronic
        ;   "Cholelithiasis with cholecystitis" → "cholecystitis" overrides "cholelithiasis" chronic
        ;   "Breast nodule, suspect malignancy" → "malignan" overrides "breast nodule" chronic
        ;   Weak acute patterns (e.g. "nodule" alone) still lose to chronic (e.g. "calcified nodule").
        if (isDefinitelyChronic && _isAcutePeek) {
            _acuteOverrideRx := "\bnew\s|\bincreas|\benlarg|\bworsen|\bprogress|\bsuspic"
                             .  "|\bcanc|\bcarcinom|\bmalignan|\bneoplasm|\bmetasta"
                             .  "|cholecystitis|appendicitis"
                             .  "|\bacute\b"
            if RegExMatch(low, _acuteOverrideRx)
                isDefinitelyChronic := false
        }

        isStabilityOnly := !isDefinitelyChronic && RegExMatch(low, stabilityRx) && !_isAcutePeek
        isChronic := isDefinitelyChronic || isStabilityOnly

        ; [v60_fix] Cross-sentence: compression fracture at a vertebroplasty level → chronic
        ;   "Suspect compression fracture at L1" + "Status post vertebroplasty at L1" → chronic
        if (!isChronic && _IsTreatedCompressionFracture(clean, bulletsText))
            isChronic := true

        ; Check if finding matches clinical question keywords
        matchesClinical := false
        if (clinLow != "") {
            clinWords := StrSplit(RegExReplace(clinLow, "[^a-z]+", " "), " ")
            for w in clinWords {
                if (StrLen(w) > 3 && InStr(low, w)) {
                    matchesClinical := true
                    break
                }
            }
        }

        ; Check if acute/significant (reuse the peek computed above for acuteRx)
        isAcute := _isAcutePeek
        ; Fracture is acute only if NOT old/healed
        if (!isAcute && RegExMatch(low, "fracture") && !RegExMatch(low, "old.{0,20}fracture|healed.{0,20}fracture|fracture.{0,20}(old|healed)"))
            isAcute := true

        ; Decision logic:
        ; 1. Chronic findings are ALWAYS excluded from primary impression
        ;    (unless they match the clinical question).
        ;    chronicRx patterns override generic acuteRx matches (e.g. "nodule").
        ; 2. In Oncology mode, chronic/incidental findings are SAVED and appended
        ;    LAST in the impression (so the primary tumour findings come first).
        ; 3. Rule-outs are always included.
        ; 4. Acute non-chronic findings are included.
        ; 5. Everything else is excluded.
        if (isChronic && !matchesClinical && !hasDDx) {
            ; [v50] Oncology: only STABILITY-pattern findings (e.g. "post-treatment change
            ; without interval change") are deferred to the end of the impression.
            ; TRUE background incidentals (atherosclerosis, cysts, spondylosis, thyroid, etc.)
            ; are ALWAYS excluded from the impression — even in Oncology mode.
            if (mode = "Oncology" && isStabilityOnly)
                chronicForOncology.Push(RTrim(Trim(clean), "."))  ; RTrim bypasses later clean-up step
            continue
        }

        if (!isChronic && !isAcute && !matchesClinical && !isRuleOut && !hasDDx)
            continue

        ; Clean up for impression
        clean := RTrim(Trim(clean), ".")

        ; Handle leading "Consider/Suggest(ed)" → rephrase (keep Suspect as-is)
        if RegExMatch(clean, "i)^consider\s+(.+)$", &mCon)
            clean := mCon[1]
        else if RegExMatch(clean, "i)^suggest(ed)?\s+(.+)$", &mSug)
            clean := mSug[1]

        if (clean != "")
            actionable.Push(clean)
    }

    ; [v50] Oncology mode: append incidental/chronic findings AFTER primary findings
    if (mode = "Oncology") {
        for item in chronicForOncology
            actionable.Push(item)
    }

    ; [v60_fix] Brain CT: soft tissue swelling / hematoma → two-point impression
    ; When Brain CT has only extracranial scalp findings (no intracranial pathology),
    ; prepend "No definite evidence of intracranial hemorrhage." then list the scalp finding.
    if (Trim(gExamType) = "Brain CT") {
        _stRx := "i)\bsoft\s+tissue\s+(swelling|edema|thickening|hematoma)\b|\bsubgaleal\b|\bscalp\s+(hematoma|swelling|contusion|laceration)\b|\bcephalohematoma\b"

        ; Separate existing actionable items into scalp-only vs intracranial
        _softItems := []
        _otherItems := []
        for item in actionable {
            if RegExMatch(StrLower(item), _stRx)
                _softItems.Push(item)
            else
                _otherItems.Push(item)
        }

        ; If no actionable items at all, scan raw bullets for soft tissue/hematoma
        if (actionable.Length = 0) {
            for _stRaw in StrSplit(bulletsText, "`n") {
                _stRaw := Trim(_stRaw)
                if (_stRaw = "")
                    continue
                _stClean := RegExReplace(_stRaw, "^[\s\-•\*>]+\s*", "")
                _stClean := Trim(_stClean)
                if (_stClean = "" || StrLen(_stClean) < 8)
                    continue
                if RegExMatch(StrLower(_stClean), _stRx)
                    _softItems.Push(RTrim(Trim(_stClean), "."))
            }
        }

        ; Only scalp findings, no intracranial findings → two-point impression
        if (_otherItems.Length = 0 && _softItems.Length > 0) {
            actionable := ["No definite evidence of intracranial hemorrhage"]
            for _stItem in _softItems
                actionable.Push(RTrim(Trim(_stItem), "."))
        }
    }

    if (actionable.Length = 0) {
        ; [v41] All findings are chronic/incidental → provide appropriate fallback
        if (hasPrior)
            return "IMPRESSION:`nNo significant interval change compared with previous study."
        else {
            ; [v58] Registry-controlled negative impression fallback (prevents cross-modality leakage)
            global gExamType, ExamRegistry
            et := Trim(gExamType)

            if (ExamRegistry.Has(et)) {
                cfg := ExamRegistry[et]
                if (cfg.Has("enableAutoImpression") && cfg["enableAutoImpression"]
                    && cfg.Has("defaultNegativeImpression") && Trim(cfg["defaultNegativeImpression"]) != "")
                    return "IMPRESSION:`n" . cfg["defaultNegativeImpression"]
            }

            ; Legacy fallback (should rarely be hit)
            if (et = "Brain CT")
                return "IMPRESSION:`nNo definite evidence of intracranial lesion."
            if (et = "Chest CT")
                return "IMPRESSION:`nNo acute cardiopulmonary finding."

            return ""  ; no auto-impression for other exams
        }
    }

    ; [v60_fix] Preserve original bullet order — do NOT re-sort by clinical relevance.
    ; Previous v59 code re-ordered clinical-matching items first, but user wants
    ; impression to follow the same order as the original report.

    ; ── Format output ─────────────────────────────────────────────────────────
    out := "IMPRESSION:`n"

    if (actionable.Length = 1) {
        out .= actionable[1] . "."
    } else {
        ; Numbered list for 2+ items
        num := 0
        for item in actionable {
            num += 1
            out .= num . ". " . item . ".`n"
        }
        out := RTrim(out, "`n")
    }

    return out
}

; =========================================================================================
; [v7_sync] NEW ROUTING PIPELINE FUNCTIONS
; Ported from router_test.py golden review v7 logic
; =========================================================================================

; ── ExpandConcatenatedBullets: split ") -Finding" into separate items ─────
ExpandConcatenatedBullets(text) {
    lines := StrSplit(text, "`n")
    expanded := []
    for line in lines {
        ; Split on ") -" followed by uppercase letter
        parts := []
        _rest := line
        Loop {
            _pos := RegExMatch(_rest, "\)\s*-(?=[A-Z])", &_m)
            if (!_pos)
                break
            _before := SubStr(_rest, 1, _pos)  ; includes the ")"
            parts.Push(_before)
            _rest := SubStr(_rest, _pos + _m.Len)
        }
        if (parts.Length > 0) {
            if (_rest != "" && Trim(_rest) != "")
                parts.Push(_rest)
            for p in parts {
                p := Trim(p)
                if (p != "")
                    expanded.Push(p)
            }
        } else {
            expanded.Push(line)
        }
    }
    result := ""
    for line in expanded
        result .= line . "`n"
    return RTrim(result, "`n")
}

; ── SplitSentences_ChestCT: split multi-sentence findings on period boundaries ─────
; Does NOT split at:
;   - ". (" (parenthetical annotation)
;   - Decimal points (digit.digit)
;   - Period followed by qualifier starters (DDx, Suspect, Superimposed, etc.)
SplitSentences_ChestCT(text) {
    if (text = "" || !InStr(text, "."))
        return [text]

    parts := []
    current := ""
    i := 1
    _len := StrLen(text)

    while (i <= _len) {
        ch := SubStr(text, i, 1)
        if (ch = ".") {
            ; Check if decimal point (digit.digit)
            if (i > 1 && i < _len) {
                _before := SubStr(text, i - 1, 1)
                _after := SubStr(text, i + 1, 1)
                if (IsDigit(_before) && IsDigit(_after)) {
                    current .= ch
                    i += 1
                    continue
                }
            }
            ; Check what follows the period
            _rest := SubStr(text, i + 1)
            _restStripped := LTrim(_rest)
            if (_restStripped = "") {
                ; Period at end → include it and finish
                current .= ch
                i += 1
                continue
            }
            ; ". (" → parenthetical annotation belongs to current sentence
            if (SubStr(_restStripped, 1, 1) = "(") {
                current .= ch
                i += 1
                continue
            }
            ; Period + qualifier starters → attach to current sentence
            if RegExMatch(_restStripped, "i)^(DDx|Suspect|Superimposed|Possibly|Probably|Likely|May\s+represent|Could\s+represent|Compatible|Consistent|Suggestive|Concerning|Recommend|Suggest|Consider|Advise|Please|Follow|Further|Clinical|Metastatic\s+lymph|Can'?t?\s+(totally\s+)?be\s+excluded)") {
                current .= ch
                i += 1
                continue
            }
            ; This period ends a sentence → split here
            piece := Trim(current)
            if (piece != "" && StrLen(piece) >= 6)
                parts.Push(piece)
            current := ""
            i += 1
            continue
        }
        current .= ch
        i += 1
    }
    ; Last piece
    piece := Trim(current)
    if (piece != "" && StrLen(piece) >= 6)
        parts.Push(piece)
    return (parts.Length > 0) ? parts : [text]
}

; ── SplitAndConjunction_ChestCT: split "A and B" when cross-section ─────
; Targeted: pneumo(hemo)thorax / hemothorax + another finding.
SplitAndConjunction_ChestCT(text) {
    ; [v60_fix] Pleural effusion + pericardial effusion compound split
    ;   "Bilateral pleural effusion and pericardial effusion" → two separate findings
    ;   "Pericardial effusion and bilateral pleural effusion" → two separate findings
    ;   Without this, Priority 0 \bpleural\s+effusion captures the entire sentence → Pleura,
    ;   losing the pericardial component which should route to Heart and vessels.
    if RegExMatch(text, "i)^(.*\bpleural\s+effusion\b[^,]*?)\s*(?:,\s*and|,\s*|\s+and)\s+(.*\bpericardial\s+effusion\b.*)$", &mPP)
        return [RTrim(Trim(mPP[1]), "."), Trim(mPP[2])]
    if RegExMatch(text, "i)^(.*\bpericardial\s+effusion\b[^,]*?)\s*(?:,\s*and|,\s*|\s+and)\s+(.*\bpleural\s+effusion\b.*)$", &mPP)
        return [RTrim(Trim(mPP[1]), "."), Trim(mPP[2])]

    ; Pattern: pleural finding + and + other finding
    if RegExMatch(text, "i)^((?:(?:right|left|bilateral)\s+)?(?:pneumo\w*thorax|hemothorax|hydropneumothorax))\s+and\s+(.+)$", &m)
        return [RTrim(Trim(m[1]), "."), Trim(m[2])]
    ; Reverse: other finding + and + pleural finding
    if RegExMatch(text, "i)^(.+?)\s+and\s+((?:(?:right|left|bilateral)\s+)?(?:pneumo\w*thorax|hemothorax|hydropneumothorax)(?:\s*[.(].*)?)\s*$", &m)
        return [RTrim(Trim(m[1]), "."), Trim(m[2])]
    return [text]
}

; ── SplitWithMetastasis_ChestCT: split "with X metastasis/metastases" ─────
; Returns array of [main, split_piece] pairs. split_piece="" means no split.
SplitWithMetastasis_ChestCT(text) {
    ; [v7_sync] Pattern 1: "with metastatic lymphadenopathy [at location...]"
    if RegExMatch(text, "i)\bwith\s+(metastatic\s+lymphadenopathy\b.*)", &m1) {
        main := Trim(SubStr(text, 1, m1.Pos - 1))
        main := RTrim(main, ", ")
        if (main != "" && StrLen(main) >= 6) {
            _splitPiece := Trim(m1[1])
            _splitPiece := Format("{:U}", SubStr(_splitPiece, 1, 1)) . SubStr(_splitPiece, 2)
            return [[main, _splitPiece]]
        }
    }

    ; [v7_sync] Pattern 2: compound "and [adj] metastases" where adj routes to different section
    if RegExMatch(text, "i)\band\s+(pleural|hepatic|liver|bony|bone|osseous|brain|cerebral|adrenal|peritoneal)\s+(metastas\w+)", &m2) {
        _adj := m2[1]
        _metaWord := m2[2]
        _splitPiece := _adj . " " . _metaWord
        _splitPiece := Format("{:U}", SubStr(_splitPiece, 1, 1)) . SubStr(_splitPiece, 2)
        ; Reconstruct main: remove "and [adj]" but keep metastases + trailing text
        main := SubStr(text, 1, m2.Pos - 1)
        main := RTrim(main) . " " . _metaWord . SubStr(text, m2.Pos + m2.Len)
        main := RTrim(Trim(main), ".")
        if (main != "" && StrLen(main) >= 6)
            return [[main, _splitPiece]]
    }

    ; [v7_sync] Pattern 3: "X with (optional adj) metastasis/metastases"
    if RegExMatch(text, "i)\bwith\s+((?:bony|bone|osseous|skeletal|pleural|hepatic|liver|lung|pulmonary|peritoneal|brain|cerebral|adrenal|nodal|lymph\s+node|distant|diffuse|widespread|multiple|extensive|osteoblastic|osteolytic|lytic|sclerotic)\s+)?(metastas\w+)", &m3) {
        ; Check what follows — only split if nothing substantive follows
        _afterMeta := SubStr(text, m3.Pos + m3.Len)
        _afterClean := RegExReplace(_afterMeta, "^[,.\s]+", "")
        if (_afterClean != "" && !RegExMatch(_afterClean, "i)^(stationary|stable|unchanged|without)\b"))
            return [[text, ""]]  ; no split — substantive text follows

        main := Trim(SubStr(text, 1, m3.Pos - 1))
        main := RTrim(main, ", ")
        _adj := (m3[1] != "") ? Trim(m3[1]) : ""
        _metaWord := m3[2]
        _splitPiece := Trim(_adj . " " . _metaWord)
        _splitPiece := Format("{:U}", SubStr(_splitPiece, 1, 1)) . SubStr(_splitPiece, 2)

        ; Append trailing ", stationary" etc. to split piece
        if (_afterClean != "" && RegExMatch(_afterClean, "i)^(stationary|stable|unchanged|without)")) {
            if RegExMatch(_afterMeta, "^[,.]?\s*(\S+(?:\s+\S+)*)", &_mTail)
                _splitPiece .= ", " . RTrim(Trim(_mTail[1]), "., ")
        }
        return [[main, _splitPiece]]
    }

    return [[text, ""]]
}

; ── DedupBuckets: remove short metastasis mentions when detailed version exists ─────
DedupBuckets(buckets) {
    ; Collect all items across all sections
    _allItems := []
    for sec, items in buckets {
        for idx, item in items
            _allItems.Push({sec: sec, idx: idx, item: item})
    }

    _toRemove := Map()
    for , a in _allItems {
        _coreA := _ExtractMetaCore(a.item)
        if (_coreA = "")
            continue
        _key_a := a.sec . "|" . a.idx
        if (_toRemove.Has(_key_a))
            continue
        for , b in _allItems {
            if (a.sec = b.sec && a.idx = b.idx)
                continue
            _coreB := _ExtractMetaCore(b.item)
            if (_coreB = "")
                continue
            ; Same core concept — only dedup short "bare" items (≤40 chars)
            if (_coreA = _coreB && StrLen(a.item) < StrLen(b.item) && StrLen(a.item) <= 40) {
                _toRemove[_key_a] := true
                break
            }
        }
    }

    if (_toRemove.Count = 0)
        return buckets

    _newBuckets := Map()
    for sec, items in buckets {
        _newItems := []
        for idx, item in items {
            _key := sec . "|" . idx
            if (!_toRemove.Has(_key))
                _newItems.Push(item)
        }
        _newBuckets[sec] := _newItems
    }
    return _newBuckets
}

; Helper: extract core metastasis concept for dedup matching
_ExtractMetaCore(text) {
    t := StrLower(Trim(text))
    ; Strip leading qualifiers
    t := RegExReplace(t, "^(suspect(ed)?|no\s+(significant\s+)?(interval\s+)?change\s+of)\s+", "")
    if RegExMatch(t, "((?:bony|bone|osseous|skeletal|pleural|hepatic|liver|lung|pulmonary|peritoneal|brain|cerebral|adrenal|osteoblastic|osteolytic)\s+)?metastas\w*", &m) {
        _adj := (m[1] != "") ? Trim(m[1]) : ""
        return Trim(_adj . " metastas")
    }
    return ""
}

; [v53_13] ROUTER MODE -- GenerateFindings_Router (router-only backend)
GenerateFindings_Router(bulletsText, examType, contrast) {
    global gCapturedImpList  ; [v55_8] write captured impression list to global
    gCapturedImpList := []  ; reset per run
    global CFG, gReportMode, ExamRegistry, gHasPrior

    ; [v53_11] Router-only, registry-driven sections/routing.
    ;          No dictionary engine, no goto/labels (AHK v2-safe).

    bulletsText := JoinWrappedLines(bulletsText)

    ; [v7_sync] Split concatenated bullets: ") -Finding" → separate items
    if (examType = "Chest CT")
        bulletsText := ExpandConcatenatedBullets(bulletsText)

    ; --- Registry lookup ---
    if (ExamRegistry.Has(examType))
        _reg := ExamRegistry[examType]
    else
        _reg := ExamRegistry["Universal (All Regions)"]

    sections := _reg["sections"]

    ; --- Leg CT: hide Vessels on Non-enhanced ---
    if (examType = "Leg CT" && contrast = "Non-enhanced") {
        _tmp := []
        for s in sections {
            if (s = "Vessels:")
                continue
            _tmp.Push(s)
        }
        sections := _tmp
    }

    buckets := Map()
    impList := []
    for s in sections
        buckets[s] := []

    ; --- Routing ---
    _filter := _reg["filterFn"]
    _heur   := _reg["heuristicFn"]

    if (Trim(bulletsText) != "") {
        for raw in StrSplit(bulletsText, "`n") {
            raw := Trim(raw)
            rawSentence := RegExReplace(raw, "^(?:[-•>\s]+)", "")
            if (raw = "")
                continue

            clean := ""

            ; Router mode: always call filterFn with stripLeadSuspect=false
            ; (keeps full sentence text including "Suspect X" endings and Se/Im annotations)
            if (_filter != "") {
                try clean := _filter(raw, false)
                catch {
                    try clean := _filter(raw)
                    catch
                        clean := raw
                }
            } else {
                clean := raw
            }

            clean := Trim(clean)

            ; [v60_fix] Impression capture: MUST happen BEFORE clean="" check
            ; so that pure "Suggest clinical correlation and follow-up." lines
            ; (which are filtered to clean="" by FilterBullet) are still captured for IMPRESSION.
            if (examType = "Chest CT") {
                if RegExMatch(StrLower(rawSentence), "(?<!\w)(ddx|suspect|suggest|recommend|correlat|follow[- ]?up|further\s+evaluation)(?!\w)") {
                    ; [v7_sync] Thyroid skip
                    _lowRaw := StrLower(rawSentence)
                    _isThyroid := RegExMatch(_lowRaw, "thyroid|goiter|goitre")
                    _hasCancer := RegExMatch(_lowRaw, "cancer|carcinom|malignan|neoplasm")
                    _skipImp := false
                    if (_isThyroid && !_hasCancer) {
                        global gClinicalText
                        _clinHasThyroid := (gClinicalText != "") ? RegExMatch(StrLower(gClinicalText), "thyroid|goiter|goitre") : false
                        if (!_clinHasThyroid)
                            _skipImp := true
                    }

                    ; [v60_fix] "Please correlate..." / "Please compare..." are pure recommendations
                    ;   — not standalone findings and not standalone impression items.
                    ;   Skip both impression push AND findings bucket.
                    if RegExMatch(rawSentence, "i)^\s*please\b") {
                        continue
                    }

                    _hasDDx := RegExMatch(rawSentence, "i)\bDDx:\s*", &_mDdx)
                    if (_hasDDx) {
                        ; [v60_fix] Keep trailing Suggest/Recommend with DDx sentence as one unit
                        ; (user wants "DDx: ... Suggest clinical correlation" to stay merged)
                        _ddxFull := Trim(rawSentence, " .`t")
                        if (_ddxFull != "" && !_skipImp) {
                            if (SubStr(_ddxFull, -1) != ".")
                                _ddxFull .= "."
                            impList.Push(_ddxFull)
                        }
                    } else {
                        _sugMatch := ""
                        _preSug := rawSentence
                        if RegExMatch(rawSentence, "i)\b(Suspect|Suggest|Recommend|Advise|Consider|Follow[- ]?up|Further evaluation|Clinical correlation)\b.*$", &_mSugPos) {
                            _sugMatch := Trim(_mSugPos[0], " .")
                            _preSug := Trim(SubStr(rawSentence, 1, _mSugPos.Pos - 1), " .")
                        }
                        _isPureSuggest := (_preSug = "" || StrLen(_preSug) < 8)
                        _isSuspectLead := RegExMatch(rawSentence, "i)^\s*suspect\b")

                        if (!_isPureSuggest && !_isSuspectLead && _sugMatch != "" && !_skipImp) {
                            imp := Trim(rawSentence, " .")
                            if (SubStr(imp, -1) != ".")
                                imp .= "."
                            impList.Push(imp)
                        } else if (_isPureSuggest && !_isSuspectLead && _sugMatch != "" && !_skipImp) {
                            imp := _sugMatch
                            if (SubStr(imp, -1) != ".")
                                imp .= "."
                            impList.Push(imp)
                        }

                        ; [v60_fix] Suspect-lead sentences ARE findings, not pure recommendations
                        ;   "Suspect chronic pancreatitis" → _isPureSuggest=true but _isSuspectLead=true
                        ;   → should go to findings bucket (and impression for actionability)
                        if (_isPureSuggest && !_isSuspectLead)
                            continue   ; pure recommendation → skip findings bucket entirely

                        ; [v60_fix] Suspect-lead: push to impression (finding with diagnostic uncertainty)
                        if (_isSuspectLead && _sugMatch != "" && !_skipImp) {
                            imp := Trim(rawSentence, " .")
                            if (SubStr(imp, -1) != ".")
                                imp .= "."
                            impList.Push(imp)
                        }
                    }
                }
            }

            if (clean = "")
                continue

            ; [v59_fix] Chest CT compound negative splitting:
            ; "No definite evidence of pulmonary metastases or mediastinal metastatic lymphadenopathy"
            ; → Lung parenchyma: No pulmonary metastases
            ; → Mediastinum and lymph nodes: No mediastinal metastatic lymphadenopathy
            if (examType = "Chest CT") {
                _splitParts := SplitNegativeSentence_ChestCT(clean)
                if (_splitParts.Length >= 2) {
                    ; Multiple sections — route each part individually
                    for _sp in _splitParts {
                        _spClean := Trim(_sp)
                        if (_spClean = "")
                            continue
                        _spSec := HeuristicRoutes_ChestCT(_spClean)
                        if (!IsSet(_allowed)) {
                            _allowed := Map()
                            for s2 in sections
                                _allowed[s2] := true
                        }
                        if (_spSec = "" || !_allowed.Has(_spSec)) {
                            _spSec := _allowed.Has("Lung parenchyma:") ? "Lung parenchyma:" : sections[1]
                        }
                        buckets[_spSec].Push(_spClean)
                    }
                    continue
                }

                ; [v7_sync] Enhanced pipeline: sentence split → and-conjunction → with-metastasis
                _sentences := SplitSentences_ChestCT(clean)
                _routed := false

                for _sent in _sentences {
                    _sent := Trim(_sent)
                    if (_sent = "" || StrLen(_sent) < 6)
                        continue

                    ; [v7_sync] "and" conjunction split for cross-section findings
                    _andParts := SplitAndConjunction_ChestCT(_sent)
                    if (_andParts.Length > 1) {
                        if (!IsSet(_allowed)) {
                            _allowed := Map()
                            for s2 in sections
                                _allowed[s2] := true
                        }
                        for _ap in _andParts {
                            _ap := Trim(_ap)
                            if (_ap = "" || StrLen(_ap) < 6)
                                continue
                            _apSec := HeuristicRoutes_ChestCT(_ap)
                            if (_apSec = "" || !_allowed.Has(_apSec))
                                _apSec := _allowed.Has("Lung parenchyma:") ? "Lung parenchyma:" : sections[1]
                            buckets[_apSec].Push(_ap)
                        }
                        _routed := true
                        continue
                    }

                    ; [v7_sync] "with X metastases" splitting
                    _metaParts := SplitWithMetastasis_ChestCT(_sent)
                    _piecesToRoute := []
                    for _mp in _metaParts {
                        _mainP := _mp[1]
                        _splitP := _mp[2]
                        if (_mainP != "" && StrLen(_mainP) >= 6)
                            _piecesToRoute.Push(_mainP)
                        if (_splitP != "" && StrLen(_splitP) >= 4)
                            _piecesToRoute.Push(_splitP)
                    }

                    if (!IsSet(_allowed)) {
                        _allowed := Map()
                        for s2 in sections
                            _allowed[s2] := true
                    }
                    for _piece in _piecesToRoute {
                        _pSec := HeuristicRoutes_ChestCT(_piece)
                        if (_pSec = "" || !_allowed.Has(_pSec))
                            _pSec := _allowed.Has("Lung parenchyma:") ? "Lung parenchyma:" : sections[1]
                        buckets[_pSec].Push(_piece)
                    }
                    _routed := true
                }
                if (_routed)
                    continue
            }
            ; [v7_sync] Initialize sec to avoid uninitialized variable when _heur is empty
            sec := ""
            if (_heur != "")
                sec := _heur(clean)
            else if (examType = "Leg CT")
                sec := HeuristicRoutes_LegCT(clean)
            ; [v55] STRICT SECTION LOCK: prevent cross-exam section pollution
            ; Build allowed-section set (once per call)
            if (!IsSet(_allowed)) {
                _allowed := Map()
                for s2 in sections
                    _allowed[s2] := true
            }
            ; [v56_1] Per-section fragment payload:
            ; If heuristic returns "§Section:§Text§Section2:§Text2...", route fragments directly and skip normal routing.
            if (InStr(sec, "§")) {
                parts := StrSplit(sec, "§")
                ; parts may start with "" if sec begins with "§"
                p := 1
                while (p <= parts.Length) {
                    _sName := Trim(parts[p])
                    if (_sName = "") {
                        p += 1
                        continue
                    }
                    if (p + 1 > parts.Length)
                        break
                    _txt := Trim(parts[p + 1])
                    p += 2
                    if (_txt = "")
                        continue

                    ; Validate section for this exam; fallback safely
                    _dest := _sName
                    if (!_allowed.Has(_dest)) {
                        if (_allowed.Has("Others:"))
                            _dest := "Others:"
                        else
                            _dest := sections[sections.Length]
                    }
                    buckets[_dest].Push(_txt)
                }
                continue
            }



            ; [v56] multi-section routing: sec may be "Sec1:|Sec2:|Sec3:" (pipe-delimited)
            ; Validate each candidate section against the allowed set for this exam.
            _secParts := InStr(sec, "|") ? StrSplit(sec, "|") : [sec]
            _validSecs := []
            for _sp in _secParts {
                _sp := Trim(_sp)
                if (_sp != "" && _allowed.Has(_sp))
                    _validSecs.Push(_sp)
            }
            ; fallback section: only allow sections registered for this exam
            if (_validSecs.Length = 0) {
                if (_allowed.Has("Others:"))
                    _validSecs := ["Others:"]
                else
                    _validSecs := [sections[sections.Length]]
            }

            ; [v55_6] Impression capture: keep original sentence (DDx/Suggest/Recommend) for IMPRESSION
            ; [v7_sync] For Chest CT, this is handled ABOVE (before enhanced pipeline).
            ;          Only execute for non-Chest-CT exams here.
            if (examType != "Chest CT" && RegExMatch(StrLower(rawSentence), "(?<!\w)(ddx|suspect|suggest|recommend|correlat|follow[- ]?up|further\s+evaluation)(?!\w)")) {
                ; [v7_sync] Thyroid skip: don't add thyroid findings to impression
                ; unless clinical context mentions thyroid OR finding has cancer/malignancy
                _lowRaw := StrLower(rawSentence)
                _isThyroid := RegExMatch(_lowRaw, "thyroid|goiter|goitre")
                _hasCancer := RegExMatch(_lowRaw, "cancer|carcinom|malignan|neoplasm")
                _skipImp := false
                if (_isThyroid && !_hasCancer) {
                    global gClinicalText
                    _clinHasThyroid := (gClinicalText != "") ? RegExMatch(StrLower(gClinicalText), "thyroid|goiter|goitre") : false
                    if (!_clinHasThyroid)
                        _skipImp := true
                }

                ; [v60_fix] "Please correlate..." / "Please compare..." are pure recommendations
                ;   — not standalone findings and not standalone impression items.
                if RegExMatch(rawSentence, "i)^\s*please\b") {
                    continue
                }

                _hasDDx := RegExMatch(rawSentence, "i)\bDDx:\s*", &_mDdx)
                if (_hasDDx) {
                    ; [v60_fix] Keep trailing Suggest/Recommend with DDx sentence as one unit
                    ; (user wants "DDx: ... Suggest clinical correlation" to stay merged)
                    _ddxFull := Trim(rawSentence, " .`t")
                    if (_ddxFull != "" && !_skipImp) {
                        if (SubStr(_ddxFull, -1) != ".")
                            _ddxFull .= "."
                        impList.Push(_ddxFull)
                    }
                    ; Finding part (before DDx) handled by clean — falls through to bucket below
                } else {
                    ; No DDx — determine if sentence has a "finding. Suspect X." structure
                    _sugMatch := ""
                    _preSug := rawSentence
                    if RegExMatch(rawSentence, "i)\b(Suspect|Suggest|Recommend|Advise|Consider|Follow[- ]?up|Further evaluation|Clinical correlation)\b.*$", &_mSugPos) {
                        _sugMatch := Trim(_mSugPos[0], " .")
                        _preSug := Trim(SubStr(rawSentence, 1, _mSugPos.Pos - 1), " .")
                    }
                    _isPureSuggest := (_preSug = "" || StrLen(_preSug) < 8)
                    _isSuspectLead := RegExMatch(rawSentence, "i)^\s*suspect\b")

                    if (!_isPureSuggest && !_isSuspectLead && _sugMatch != "" && !_skipImp) {
                        ; Mixed: has a real finding BEFORE Suspect/Suggest → push WHOLE sentence to Impression
                        imp := Trim(rawSentence, " .")
                        if (SubStr(imp, -1) != ".")
                            imp .= "."
                        impList.Push(imp)
                    } else if (_isPureSuggest && !_isSuspectLead && _sugMatch != "" && !_skipImp) {
                        ; Pure suggest (no real finding before it), not Suspect-lead → push suggest clause only
                        imp := _sugMatch
                        if (SubStr(imp, -1) != ".")
                            imp .= "."
                        impList.Push(imp)
                    }
                    ; [v60_fix] Suspect-lead sentences ARE findings, not pure recommendations
                    ;   "Suspect chronic pancreatitis" → _isPureSuggest=true but _isSuspectLead=true
                    ;   → should go to findings bucket (and impression for actionability)
                    if (_isPureSuggest && !_isSuspectLead)
                        continue   ; pure recommendation → skip findings bucket

                    ; [v60_fix] Suspect-lead: push to impression (finding with diagnostic uncertainty)
                    if (_isSuspectLead && _sugMatch != "" && !_skipImp) {
                        imp := Trim(rawSentence, " .")
                        if (SubStr(imp, -1) != ".")
                            imp .= "."
                        impList.Push(imp)
                    }
                }
            }

            ; [v57_3] Interval/progression/regression capture (Solution B):
            ; - Whole original sentence → IMPRESSION (impList)
            ; - Strip interval-change wording → stripped core finding → FINDINGS bucket
            ; [v57_3] Interval detection: require "interval" keyword OR sentence-initial progression/regression
            ; Avoids false triggers on clinical descriptions like "with progression of local recurrence"
            _intervalRx := "i)\b(interval\s+(development|increase|decrease|progression|regression|enlargement|reduction|improvement|worsening|change)|without\s+interval\s+change|no\s+significant\s+(interval\s+)?change\s*(of|in|to)?|no\s+interval\s+change\s*(of|in|to)?|unchanged\s+compared\s+(with|to)|stable\s+compared\s+(with|to)|increased\s+compared\s+(with|to)|decreased\s+compared\s+(with|to)|worsened\s+compared\s+(with|to)|improved\s+compared\s+(with|to)|shows?\s+interval\s+(increase|decrease|enlarg|reduc|progress|regress|improv|worsen|change)|with\s+progression|with\s+regression|stationary\b|without\s+(significant\s+)?change)\b|^(progression|regression|development)\s+of\b"
            if RegExMatch(rawSentence, _intervalRx) {
                ; [v60_fix] When no prior study, suppress stability/no-change sentences
                ; from impression. Progression/regression findings still go to impression.
                _rawLow2 := StrLower(rawSentence)
                _isStabilityType := RegExMatch(_rawLow2, "\b(no\s+(significant\s+)?(interval\s+)?change|without\s+(significant\s+)?(interval\s+)?change|unchanged\s+compared|stable\s+compared|stationary)\b")
                _isProgressType := RegExMatch(_rawLow2, "\b(interval\s+(increase|decrease|progression|regression|enlargement|reduction|improvement|worsening)|increased?\s+compared|decreased?\s+compared|worsened?\s+compared|improved?\s+compared|with\s+(progression|regression)|shows?\s+interval\s+(increase|decrease|enlarg|reduc|progress|regress|improv|worsen))\b")
                _skipImpNoPrior := (!gHasPrior && _isStabilityType && !_isProgressType)

                if (!_skipImpNoPrior) {
                    ; 1) Send full original sentence to Impression
                    ;    Strip parenthetical Se/Im annotation and Suspect/DDx tail for cleaner impression
                    imp := Trim(rawSentence, " .`t")
                    imp := RegExReplace(imp, "i)\s*\(\s*(?:\d[^)]*(?:se|im|series|image)[^)]*|[^)]*(?:se|im|series|image)[^)]*)\)\s*", " ")
                    imp := Trim(RegExReplace(imp, "i)\s*\.?\s*(DDx|Suspect)\b.*$", ""), " .")
                    imp := Trim(imp, " .,`t")
                    if (imp != "" && SubStr(imp, -1) != ".")
                        imp .= "."
                    impList.Push(imp)

                    ; [v57_7] If sentence has trailing Suspect or DDx, push to Impression
                    ; For DDx: append to the finding item (not separate item)
                    ; For Suspect: push as separate item
                    ; DDx may be followed by other phrases (e.g., "Suggest clinical correlation"),
                    ; so capture DDx content up to the next period/newline instead of requiring end-of-line.
                    if RegExMatch(rawSentence, "i)\bDDx:\s*([^\.\r\n]+)", &_mDdxTail) {
                        _ddxCore := Trim(_mDdxTail[1], " .")
                        _ddxClause := (_ddxCore != "") ? "DDx: " _ddxCore : ""
                        if (_ddxClause != "") {
                            impWithDdx := RTrim(imp, ".") . " " . _ddxClause
                            if (SubStr(impWithDdx, -1) != ".")
                                impWithDdx .= "."
                            ; Replace the previously pushed imp with imp+DDx
                            if (impList.Length > 0 && impList[impList.Length] = imp)
                                impList[impList.Length] := impWithDdx
                            else
                                impList.Push(impWithDdx)
                        }
                    } else if RegExMatch(rawSentence, "i)\bSuspect\b\s*(.+?)\s*\.?\s*$", &_mSuspTail) {
                        _suspItem := Trim(_mSuspTail[0], " .")
                        if (_suspItem != "" && SubStr(_suspItem, -1) != ".")
                            _suspItem .= "."
                        if (_suspItem != imp)
                            impList.Push(_suspItem)
                    }
                }

                ; 2) Strip interval-change prefix/suffix patterns to get core finding
                _core := rawSentence
                ; Pattern A: "Interval <change> of [the] <finding>" → "<Finding>"
                _core := RegExReplace(_core, "i)^\s*interval\s+(development|increase|decrease|progression|regression|enlargement|reduction|improvement|worsening|change)\s+(of\s+)?(the\s+|a\s+|an\s+)?", "")
                ; Pattern B: "Progression/Regression of [the] <finding>" → "<Finding>"
                _core := RegExReplace(_core, "i)^\s*(progression|regression|development)\s+of\s+(the\s+|a\s+|an\s+)?", "")
                ; Pattern C: "No significant interval change of/in <finding>" → "<Finding>"
                _core := RegExReplace(_core, "i)^\s*no\s+significant\s+(interval\s+)?change\s+(of|in|to)\s+(the\s+|a\s+|an\s+)?", "")
                ; Pattern D: "No interval change of/in <finding>" → "<Finding>"
                _core := RegExReplace(_core, "i)^\s*no\s+interval\s+change\s+(of|in|to)\s+(the\s+|a\s+|an\s+)?", "")
                ; Pattern E: trailing "shows interval <change> [in size/number...]" → strip tail
                _core := RegExReplace(_core, "i)\s+shows?\s+interval\s+\w+(\s+in\s+\w+)?\s*\.?$", "")
                ; Pattern F: trailing "with interval <change>" → strip tail
                _core := RegExReplace(_core, "i)\s+with\s+(interval|progressive)\s+\w+(\s+\w+)?\s*\.?$", "")
                ; Pattern G: trailing "compared with ..." → strip
                _core := RegExReplace(_core, "i)\s*,?\s*(unchanged|stable|increased|decreased|worsened|improved)\s+compared\s+(with|to)\s+.*$", "")
                ; Pattern H: trailing "without interval change" → strip
                _core := RegExReplace(_core, "i)\s+without\s+interval\s+change\.?\s*$", "")
                ; Pattern H: trailing "without interval change" → strip
                _core := RegExReplace(_core, "i)\s+without\s+interval\s+change\.?\s*$", "")
                _core := Trim(_core, " .,`t")
                ; Strip Se/Im parenthetical and Suspect/DDx tail from core finding
                _core := RegExReplace(_core, "i)\s*\(\s*(?:\d[^)]*(?:se|im|series|image)[^)]*|[^)]*(?:se|im|series|image)[^)]*)\)\s*", " ")
                _core := RegExReplace(_core, "i)\s*\.?\s*\b(Suspect|DDx)\b.*$", "")
                ; Strip Se/Im parenthetical and Suspect/DDx tail from core finding
                _core := RegExReplace(_core, "i)\s*\(\s*(?:\d[^)]*(?:se|im|series|image)[^)]*|[^)]*(?:se|im|series|image)[^)]*)\)\s*", " ")
                _core := RegExReplace(_core, "i)\s*\.?\s*\b(Suspect|DDx)\b.*$", "")
                _core := Trim(_core, " .,`t")
                ; Capitalise first letter
                if (_core != "")
                    _core := Format("{:U}", SubStr(_core, 1, 1)) . SubStr(_core, 2)
                if (_core != "" && SubStr(_core, -1) != ".")
                    _core .= "."

                ; 3) Route to findings buckets: use clean (preserves Se/Im annotation)
                ;    _core is only used for Impression (cleaner without parentheticals)
                for _sp in _validSecs
                    buckets[_sp].Push(clean)
                continue
            }

            for _sp in _validSecs
                buckets[_sp].Push(clean)
        }
    }

    ; [v7_sync] Dedup: remove short metastasis mentions when detailed version exists
    if (examType = "Chest CT")
        buckets := DedupBuckets(buckets)

    ; --- Build output (2-space indent + "> " for hanging-indent alignment) ---
    out := ""
    mainBullet := "* "
    subPrefix  := "  > "

    for s in sections {
        secTitle := Trim(s)
        if (SubStr(secTitle, -1) = ":")
            secTitle := SubStr(secTitle, 1, -1)

        ; Deduplicate, preserve insertion order
        uniq := []
        seen := Map()
        for t in buckets[s] {
            key := StrLower(Trim(t))
            if !seen.Has(key) {
                uniq.Push(t)
                seen[key] := 1
            }
        }

        if (uniq.Length = 0) {
            ; Skip standalone "Others:" when empty — no negative wording needed
            ; But "Ocular / Others:" is a standard Brain CT section → show Unremarkable
            if (s = "Others:")
                continue
            out .= mainBullet . secTitle . ": " . GetNegativeWording(s, gReportMode) . "`n"
        } else if (uniq.Length = 1) {
            out .= mainBullet . secTitle . ": " . RTrim(uniq[1], ".") . ".`n"
        } else {
            out .= mainBullet . secTitle . ":`n"
            for t in uniq
                out .= subPrefix . RTrim(t, ".") . "`n"
        }

        out .= "`n"
    }

    ; [v55_7] Capture raw-sentence impression candidates (DDx/Suggest/Recommend) for outer impression builder
    gCapturedImpList := impList


    return Trim(out, "`n`t ")
}
; would otherwise be stolen by a later broad-keyword block.
InferSectionFromText(txt) {
    t := StrLower(txt)

    ; ── Priority 0: compound-finding overrides ────────────────────────────────────────
    ; [v60_fix] Pleural effusion → Pleura (even when sentence mentions lung lobe)
    if RegExMatch(t, "\bpleural\s+effusion")
        return "Pleura:"
    ; [v60_fix] Abdominal/retroperitoneal lymphadenopathy → Others (not Mediastinum/Liver)
    if RegExMatch(t, "(hepatic\s+hil|retroperitoneal|mesenteric|para-?aortic|celiac|porta\s+hepatis).{0,30}(lymph|adenopathy)")
        return "Others:"
    if RegExMatch(t, "(lymph|adenopathy).{0,30}(hepatic\s+hil|retroperitoneal|mesenteric|para-?aortic|celiac|porta\s+hepatis)")
        return "Others:"
    ; [v60_fix] Lung parenchymal finding near hilum → Lung (not Mediastinum)
    if RegExMatch(t, "ground.?glass|\bgg[on]\b|opaci|consolidat|atelectas|infiltrat|pneumoni|fibrosis|fibrot") && RegExMatch(t, "\bhil(ar|um)\b") && !RegExMatch(t, "lymph|adenopathy")
        return "Lung parenchyma:"
    ; [v60_fix] Biliary duct structures → Biliary (not Liver)
    ;   "hepatic duct" contains "hepatic" which matches Liver override below. Must catch here first.
    if RegExMatch(t, "(hepatic|intrahepatic|intra.hepatic)\s+(bile\s+)?duct|\bihd\b|\bihds\b|common\s+hepatic\s+duct|biliary\s+dil|duct\s+dil")
        return "Biliary system and pancreas:"

    ; ── Special overrides FIRST ───────────────────────────────────────────────────────
    ; Peripheral LN / breast / chest wall → Osseous
    if RegExMatch(t, "axillar|axilla|intramammar|mammary|breast|chest wall")
        return "Osseous and soft tissues:"

    ; Adrenal: beats "nodule|mass" in Lung block
    if RegExMatch(t, "adrenal")
        return "Adrenal glands:"

    ; Paratracheal: beats "trachea" substring match in Airways block
    if RegExMatch(t, "paratracheal")
        return "Mediastinum and lymph nodes:"

    ; Pericardial: beats "effusion" in Pleura block
    if RegExMatch(t, "pericardial")
        return "Heart and vessels:"

    ; [v41] Pulmonary embolism/PE: beats "pulmonary" in Lung block
    if RegExMatch(t, "pulmonary embol|pulmonary thrombo|\bpte\b|\bpe\b")
        return "Heart and vessels:"

    ; [v41] Organ-specific overrides: beat generic "lesion|cyst|mass|nodule" in Lung block
    ; [v60_fix] Portal venous gas → Liver
    if RegExMatch(t, "portal\s+(venous|veinous|vein)\s+(gas|air)|portal\s+gas")
        return "Liver:"
    ; Kidney/renal: "renal cyst", "renal mass", "renal lesion" → Kidneys
    ; [v60_fix] Added perinephric|perirenal — word boundary \bnephr misses "perinephric"
    if RegExMatch(t, "renal|kidney|perinephric|perirenal")
        return "Kidneys:"
    ; Liver/hepatic: "hepatic cyst", "liver lesion" → Liver
    if RegExMatch(t, "liver|hepatic")
        return "Liver:"
    ; Spleen: "splenic cyst", "splenic lesion" → Spleen
    if RegExMatch(t, "spleen|splenic")
        return "Spleen:"
    ; Thyroid: "thyroid nodule", "thyroid mass" → Thyroid
    if RegExMatch(t, "thyroid|goiter")
        return "Thyroid gland:"
    ; [v60_fix] Esophagus → Mediastinum (esophagus runs through mediastinum in Chest CT)
    ;   InferSectionFromText is only called from Chest CT contexts
    ;   (GenerateImpression_LungNoPrior, _SectionHitCount_FromParts)
    ;   Must be consistent with ExtractLocation_ChestCT which routes esophag → "mediastinum"
    if RegExMatch(t, "esophag|oesophag")
        return "Mediastinum and lymph nodes:"
    ; Stomach/GI: "gastric mass", "bowel finding" → Others
    if RegExMatch(t, "stomach|gastric|bowel|intestin|colon|rectal")
        return "Others:"
    ; Gallbladder/pancreas: "pancreatic cyst", "gallbladder mass" → Gallbladder
    if RegExMatch(t, "gallbladder|gallstone|cholelith|cholecyst|choledoch|\bchd\b|\bcbd\b|bile duct|biliary|pancrea|pneumobilia")
        return "Biliary system and pancreas:"

    ; [v60_fix] Bone / soft tissue / breast / chest wall → Osseous (before Lung generic terms)
    ;   Generic lesion terms (nodule, mass, lesion, cyst) in the Lung block below
    ;   would capture findings with bone/soft tissue anatomical location.
    ;   Lesion+location principle: route by anatomical location, not lesion type.
    if RegExMatch(t, "\bbreast\b|\baxillar|\baxilla\b|\bintramammar|\bmammary\b|\bchest\s*wall|\bbone\b|\bosseous\b|\bspine\b|\bvertebra|\brib\b|\bribs\b|\bfracture|\bscoliosis|\bkyphosis|\bspondyl|\bdegenerative|\bsoft\s*tissue|\bvertebroplas|\bkyphoplas|\bsubcutan")
        return "Osseous and soft tissues:"

    ; ── Lung parenchyma ───────────────────────────────────────────────────────────────
    if RegExMatch(t, "nodule|mass|lesion|tumou?r|cancer|carcinoma|neoplasm|consolidation|opacit|infiltrat|emphysema|centrilobular|fibrosis|bronchiectasis|atelectasis|collapse|ggo|ground[\s\-]*glass|air[\s\-]*trapping|reticular|septal|bulla[e]?|bleb|cyst|cavit(y|ar)|pneumatocele|granuloma|upper lobe|middle lobe|lower lobe|lingula|\b(rul|rml|rll|lul|lll)\b|lung field|pulmonary")
        return "Lung parenchyma:"

    ; ── Airways ───────────────────────────────────────────────────────────────────────
    if RegExMatch(t, "airway|bronchus|bronchi|trachea|mucus")
        return "Airways:"

    ; ── Pleura ────────────────────────────────────────────────────────────────────────
    if RegExMatch(t, "pleura|effusion|pneumothorax|hemothorax|pleural")
        return "Pleura:"

    ; ── Mediastinum & central lymph nodes ────────────────────────────────────────────
    if RegExMatch(t, "mediastin|hilar|subcarinal|prevascular|aortopulmonary|lymph node|thymus")
        return "Mediastinum and lymph nodes:"

    ; ── Heart and vessels ─────────────────────────────────────────────────────────────
    if RegExMatch(t, "cardiomegal|heart|cardiac|aort|coronary|vessel|artery|vein|atherosclerosis|calcif|dissect|embol|\bpe\b|\bpte\b|thromb")
        return "Heart and vessels:"

    ; ── Upper abdomen (safety net — most caught by overrides above Lung) ──────────────
    if RegExMatch(t, "cirrhosis")
        return "Liver:"
    if RegExMatch(t, "splenomegal")
        return "Spleen:"
    if RegExMatch(t, "adrenal")
        return "Adrenal glands:"

    ; ── Others (GI / esophagus / miscellaneous) ──────────────────────────────────────
    if RegExMatch(t, "hiatal|hernia|diverticul|appendic")
        return "Others:"

    ; ── Osseous & soft tissue ─────────────────────────────────────────────────────────
    if RegExMatch(t, "bone|osseous|spine|vertebra|rib|fracture|scoliosis|kyphosis|spondylosis|degenerative|soft tissue|old.{0,20}(rib|ribs)|rib.{0,30}fracture|fracture.{0,30}rib|vertebroplasty|kyphoplasty")
        return "Osseous and soft tissues:"

    ; ── Default fallback ──────────────────────────────────────────────────────────────
    return "Others:"
}
; =========================================================================================
; =========================================================================================
; [v41] NEGATIVE SENTENCE SPLITTER: SplitNegativeSentence_ChestCT(line)
;   Splits "No evidence of A or B/C" into separate negative findings for each organ.
;   Each segment gets prefixed with "No" so it reads as a complete negative statement.
;
;   Example:
;     "No definite evidence of pulmonary metastases or mediastinal/axillary
;      metastatic lymphadenopathy"
;     → ["No pulmonary metastases"
;       ,"No mediastinal metastatic lymphadenopathy"
;       ,"No axillary metastatic lymphadenopathy"]
;
;   If only 1 section hit after splitting → return as single item (no split needed).
; =========================================================================================

SplitNegativeSentence_ChestCT(line) {
    s := Trim(line)
    if (s = "")
        return []

    low := StrLower(s)

    ; [v41] Stability/change sentences should never be split — they describe one finding
    if RegExMatch(low, "change|stable|stationary|unchanged|decrease|increase|interval|compared|progression|regression")
        return [s]

    ; Step 1: Strip the negative preamble to get the "content" part
    ;   "No definite evidence of X" → "X"
    ;   "No X" → "X"
    ;   "Without X" → "X"
    ;   "Absence of X" → "X"
    content := s
    _foundNegative := false
    if RegExMatch(low, "^no\s+definite\s+evidence\s+of\s+", &m) {
        content := SubStr(s, m.Len + 1)
        _foundNegative := true
    } else if RegExMatch(low, "^no\s+evidence\s+of\s+", &m) {
        content := SubStr(s, m.Len + 1)
        _foundNegative := true
    } else if RegExMatch(low, "^no\s+", &m) {
        content := SubStr(s, m.Len + 1)
        _foundNegative := true
    } else if RegExMatch(low, "^without\s+", &m) {
        content := SubStr(s, m.Len + 1)
        _foundNegative := true
    } else if RegExMatch(low, "^absence\s+of\s+", &m) {
        content := SubStr(s, m.Len + 1)
        _foundNegative := true
    } else if RegExMatch(low, "^negative\s+for\s+", &m) {
        content := SubStr(s, m.Len + 1)
        _foundNegative := true
    }

    ; [v7_sync] Only split when negative prefix was found; positive sentences stay intact
    if (!_foundNegative)
        return [s]

    content := Trim(content, ". `t")
    if (content = "")
        return [s]

    ; Step 2: Expand "X/Y noun_phrase" → "X noun_phrase or Y noun_phrase"
    ;   e.g. "mediastinal/axillary metastatic lymphadenopathy"
    ;     → "mediastinal metastatic lymphadenopathy or axillary metastatic lymphadenopathy"
    ;   Skip technical notation like "series/image", "s/p", numbers
    if InStr(content, "/") {
        ; Only expand if both sides are alphabetic words (not numbers, not technical)
        if RegExMatch(content, "([a-zA-Z]{3,})/([a-zA-Z]{3,})\s+(.*)", &mSlash) {
            w1 := mSlash[1], w2 := mSlash[2]
            ; Skip known non-anatomical slashes
            if !(RegExMatch(StrLower(w1), "^(series|image|pre|post|with|without|s|and|or)$")) {
                before := ""
                slashPos := InStr(content, w1 . "/" . w2)
                if (slashPos > 1)
                    before := SubStr(content, 1, slashPos - 1)
                trailing := mSlash[3]
                content := before . w1 . " " . trailing . " or " . w2 . " " . trailing
            }
        }
    }

    content := Trim(content, ". `t")

    parts := []
    ; Split on " or " first, then "," within each part
    for chunk in StrSplit(content, " or ") {
        for sub in StrSplit(chunk, ",") {
            sub := Trim(sub)
            ; Strip leading "and "
            sub := RegExReplace(sub, "i)^and\s+", "")
            sub := Trim(sub)
            if (sub != "" && StrLen(sub) > 2)
                parts.Push(sub)
        }
    }

    if (parts.Length <= 1)
        return [s]  ; nothing to split

    ; Step 3: Check if splitting yields multiple sections
    if (_SectionHitCount_FromParts(parts) < 2)
        return [s]  ; all parts go to same section, keep original

    ; Step 4: Prefix each part with "No " to make complete negative statements
    out := []
    for p in parts {
        p := Trim(p)
        neg := "No " . p
        ; Clean up: ensure it reads well
        neg := RegExReplace(neg, "\s+", " ")
        neg := RTrim(neg, ".")
        out.Push(neg)
    }

    return out
}

; Helper: count distinct sections from a list of text parts
_SectionHitCount_FromParts(parts) {
    seen := Map()
    for p in parts {
        sec := InferSectionFromText(p)
        if (sec != "")
            seen[sec] := 1
    }
    return seen.Count
}

; [v34] MULTI-SECTION AUTO-SPLITTER: SplitMultiSection_ChestCT(line)
;   Iteratively splits a bullet when any clause contains >=2 section-hits.
;   Handles "A with B and C" -> [A, B, C] in up to 3 passes.
;   Deterministic, no LLM.
; =========================================================================================

SplitMultiSection_ChestCT(line) {
    s := Trim(line)
    if (s = "")
        return []

    seps := [" with ", " and ", ";", ",", "\u3001"]

    parts := [s]

    ; iterate up to 3 times to allow "A with B and C" -> A / B / C
    Loop 3 {
        changed := false
        newParts := []

        for p in parts {
            p := Trim(p)
            if (p = "") {
                continue
            }

            ; [v50] Strip parenthetical size/series annotations before section counting
            ; so commas inside "(0.1cm, Se/Im: 6/87)" never trigger spurious splits
            pForCount := RegExReplace(p, "\([^)]*\)", "")

            ; only split if this clause spans >=2 sections (counted on stripped text)
            if (_SectionHitCount_ChestCT(pForCount) >= 2) {
                splitDone := false
                for sep in seps {
                    ; For comma: only split on commas that appear OUTSIDE parentheses
                    pToSearch := (sep = ",") ? pForCount : p
                    if InStr(pToSearch, sep) {
                        tmp := StrSplit(p, sep)
                        for t in tmp {
                            t2 := Trim(RegExReplace(t, "^\b(with|and)\b\s*", ""))
                            if (t2 != "")
                                newParts.Push(t2)
                        }
                        splitDone := true
                        changed := true
                        break
                    }
                }
                if !splitDone
                    newParts.Push(p)
            } else {
                newParts.Push(p)
            }
        }

        parts := newParts
        if !changed
            break
    }

    ; final cleanup: drop empty / junk segments (<=2 chars)
    out := []
    for p in parts {
        p := Trim(p)
        if (p = "" || StrLen(p) <= 2)
            continue
        out.Push(p)
    }
    return out
}

; Count how many distinct section groups a text snippet hits (Chest CT)
_SectionHitCount_ChestCT(txt) {
    t := StrLower(txt)

    ; [v60_fix] Removed bare generic terms (nodule|mass|lesion|cyst|tumour|cancer|carcinoma|neoplasm)
    ;   from lungHit — they match ANY organ finding, violating lesion+location principle.
    ;   Added \blung\b and bronchiectasis as lung-specific terms instead.
    lungHit := RegExMatch(t, "\blung\b|pulmonary|ggn|ggo|ground[\s\-]*glass|consolidation|opacit|atelectasis|collapse|fibrosis|emphysema|centrilobular|infiltrat|tree[\s\-]*in[\s\-]*bud|bulla[e]?|bleb|cavit(y|ar)|pneumatocele|granuloma|bronchiectasis|upper lobe|middle lobe|lower lobe|lingula|\b(rul|rml|rll|lul|lll)\b|lung field")
    lnHit   := RegExMatch(t, "mediastin|hilar|subcarinal|paratracheal|prevascular|aortopulmonary|lymph\s*node|\bln\b")
    pleHit  := RegExMatch(t, "pleura|pleural|effusion|pneumothorax|hydropneumothorax|hemothorax")
    hvHit   := RegExMatch(t, "heart|cardiac|aort|coronar|vessel|artery|vein|atheroscler|pericard|dissect|embol|\bpe\b|\bpte\b|thromb")
    boneHit := RegExMatch(t, "bone|osseous|spine|vertebra|rib|fracture|spondyl|degenerative|soft\s*tissue|chest\s*wall|subcutaneous|breast|mammary|axilla|axillar|intramammar|vertebroplasty|kyphoplasty")

    cnt := 0
    cnt += lungHit ? 1 : 0
    cnt += lnHit   ? 1 : 0
    cnt += pleHit  ? 1 : 0
    cnt += hvHit   ? 1 : 0
    cnt += boneHit ? 1 : 0
    return cnt
}

; ---------- Silent CSV log for unrouted lines (research use) ----------
LogRouterUnmatched(sentence, examType, sec) {
    try {
        now    := A_Now
        logDir := "C:\RIS_Workflow"
        logPath := logDir . "\router_unmatched_" . FormatTime(now, "yyyyMM") . ".csv"

        if !DirExist(logDir)
            DirCreate(logDir)

        if !FileExist(logPath)
            FileAppend("timestamp,examType,fallback_section,text`n", logPath, "UTF-8")

        ts       := FormatTime(now, "yyyy-MM-dd HH:mm:ss")
        safeTxt  := StrReplace(sentence, Chr(34), Chr(39))
        FileAppend(ts . "," . examType . "," . sec . "," . Chr(34) . safeTxt . Chr(34) . "`n", logPath, "UTF-8")
    } catch {
        ; Clinical mode: swallow all errors silently -- never interrupt report workflow
    }
}

; ========================= MAPPING FILE LOADER =========================
LoadSectionMap(file) {
    m := Map()

    if !FileExist(file) {
        MsgBox("Warning: Mapping file not found: " file "`n`nPlease create the mapping file or place it in the same folder as this script.", "Missing Mapping File", "Icon!")
        return m
    }

    content := FileRead(file)

    ; Strip UTF-8 BOM if present (U+FEFF)
    if (SubStr(content, 1, 1) = Chr(0xFEFF))
        content := SubStr(content, 2)

    ; Normalize newlines
    content := StrReplace(content, "`r`n", "`n")
    content := StrReplace(content, "`r", "`n")

    pendingKey := ""   ; supports 2-line format:
                      ; <key>
                      ; => <Section> | <Finding sentence>

    for line in StrSplit(content, "`n") {
        line := Trim(line)

        ; Skip empty lines and comments
        if (line = "" || SubStr(line, 1, 1) = "#") {
            pendingKey := ""   ; reset on blank/comment to avoid accidental pairing
            continue
        }

        
        ; ---------- Format V3: pipe-delimited ----------
        ; key|section|pure_phrase|risk_tag
        ; risk_tag is optional for mapping; ignored here.
        if (!InStr(line, "=>") && InStr(line, "|")) {
            cols := StrSplit(line, "|")
            if (cols.Length >= 3) {
                kRaw := Trim(cols[1])
                sec  := Trim(cols[2])
                txt  := Trim(cols[3])
                if (kRaw != "" && sec != "" && txt != "") {
                    if (SubStr(sec, -1) != ":")
                        sec .= ":"
                    key := StrLower(Trim(kRaw))   ; v3 key is expected to be snake_case already
                    m[key] := Map("sec", sec, "txt", txt)
                    pendingKey := ""
                    continue
                }
            }
        }

; ---------- Format A: single-line ----------
        ; <key> => <Section> | <Text>
        ; Also supports multi-section: key => S1: | T1. && S2: | T2.
        if InStr(line, "=>") {
            parts := StrSplit(line, "=>", , 2)
            if (parts.Length < 2)
                continue

            kRaw := Trim(parts[1])
            rhs  := Trim(parts[2])

            ; If key is empty (e.g. line starts with "=>"), use pendingKey (Format B)
            if (kRaw = "") {
                if (pendingKey = "")
                    continue
                kRaw := pendingKey
            }

            key := NormalizeKey(kRaw)
            if (key = "")
                continue

            ; [v53] Multi-section split: key => S1: | T1. && S2: | T2.
            if InStr(rhs, "&&") {
                splitParts := StrSplit(rhs, "&&")
                multiItems := []
                for sp in splitParts {
                    sp := Trim(sp)
                    if !InStr(sp, "|")
                        continue
                    pp := StrSplit(sp, "|", , 2)
                    s := Trim(pp[1])
                    t := Trim(pp[2])
                    if (s = "" || t = "")
                        continue
                    if (SubStr(s, -1) != ":")
                        s .= ":"
                    multiItems.Push([s, t])
                }
                if (multiItems.Length > 0) {
                    m[key] := Map("sec", "MULTI", "parts", multiItems)
                    pendingKey := ""
                    continue
                }
            }

            ; Check if rhs contains section separator "|"
            if InStr(rhs, "|") {
                ; Format: key => Section | Text
                rhsParts := StrSplit(rhs, "|", , 2)
                if (rhsParts.Length < 2)
                    continue

                sec := Trim(rhsParts[1])
                txt := Trim(rhsParts[2])
            } else {
                ; Format: key => Text (no section - use default/auto-detect)
                sec := AutoDetectSection(kRaw, rhs)
                txt := rhs
            }

            if (sec = "" || txt = "")
                continue

            ; Ensure section ends with colon
            if (SubStr(sec, -1) != ":")
                sec .= ":"

            m[key] := Map("sec", sec, "txt", txt)
            pendingKey := ""
            continue
        }

        ; ---------- Format B: two-line ----------
        ; <key>
        ; => <Section> | <Text>
        pendingKey := line
    }

    return m
}

; Auto-detect section based on keywords in key or text
AutoDetectSection(keyText, valueText) {
    combined := StrLower(keyText . " " . valueText)

    ; [v55_3] Brain parenchyma (defensive): explicit brain terms OR brain-specific pathology
    if RegExMatch(combined, "(?<!\w)(brain|parenchyma|cerebr\w*|cortical|subcortical|white\s+matter|gray\s+matter|basal\s+ganglia|thalamus|lobe|frontal|temporal|parietal|occipital|infarct|encephalomalacia|edema)(?!\w)")
        return "Brain parenchyma:"

    ; [v55_3] Brain parenchyma (generic lesion term + must co-occur with brain location)
    if RegExMatch(combined, "(?<!\w)(lesion|hypodens\w*|hyperdens\w*|mass|tumou?r|cyst|nodule)(?!\w)")
       && RegExMatch(combined, "(?<!\w)(brain|parenchyma|cerebr\w*|cortical|subcortical|white\s+matter|gray\s+matter|basal\s+ganglia|thalamus|lobe|frontal|temporal|parietal|occipital|hemisphere)(?!\w)")
        return "Brain parenchyma:"

    
    ; Lung parenchyma keywords
    if (RegExMatch(combined, "nodule|mass|consolidation|opacity|infiltrat|emphysema|centrilobular|fibrosis|bronchiectasis|atelectasis|collapse"))
        return "Lung parenchyma:"
    
    ; Airways
    if (RegExMatch(combined, "airway|bronchus|bronchi|trachea"))
        return "Airways:"
    
    ; Pleura
    if (RegExMatch(combined, "pleura|effusion|pneumothorax|hemothorax"))
        return "Pleura:"
    
    ; Mediastinum and lymph nodes
    if (RegExMatch(combined, "mediastin|lymph node|thymus|subcarinal|paratracheal|prevascular|aortopulmonary|hilar lymph"))
        return "Mediastinum and lymph nodes:"
    
    ; Heart and vessels
    if (RegExMatch(combined, "heart|cardiac|aort|coronary|vessel|artery|vein|atherosclerosis|calcif"))
        return "Heart and vessels:"
    
    ; Thyroid
    if (RegExMatch(combined, "thyroid|goiter"))
        return "Thyroid gland:"
    
    ; Liver
    if (RegExMatch(combined, "liver|hepatic|cirrhosis"))
        return "Liver:"
    
    ; Biliary system and pancreas
    if (RegExMatch(combined, "gallbladder|cholecyst|pancrea|pneumobilia"))
        return "Biliary system and pancreas:"
    
    ; Spleen
    if (RegExMatch(combined, "spleen|splenic"))
        return "Spleen:"
    
    ; Adrenal
    if (RegExMatch(combined, "adrenal"))
        return "Adrenal glands:"
    
    ; Kidneys
    if (RegExMatch(combined, "kidney|renal"))
        return "Kidneys:"
    
    ; Osseous and soft tissues
    if (RegExMatch(combined, "bone|osseous|spine|vertebra|rib|fracture|scoliosis|kyphosis|spondylosis|degenerative|vertebroplasty|kyphoplasty"))
        return "Osseous and soft tissues:"

    ; Default fallback
    return "Osseous and soft tissues:"
}

; ========================= TEXT NORMALIZATION =========================

NormalizeKey(line) {
    clean := Trim(line)
    
    ; Remove leading bullet markers (-, •, *, etc.) with or without space
    clean := RegExReplace(clean, "^[\s\-•\*>]+\s*", "")
    
    ; Remove trailing period
    clean := RegExReplace(clean, "\.\s*$", "")
    
    ; Collapse multiple spaces into one
    clean := RegExReplace(clean, "\s{2,}", " ")
    
    ; Convert to lowercase for case-insensitive matching
    return StrLower(clean)
}

; ========================= SYNONYM FILE LOADER =========================
; Format (UTF-8):
;   legacy_input=key
; Example:
;   ggo=ground_glass
LoadSynonymMap(file) {
    m := Map()
    if !FileExist(file)
        return m

    content := FileRead(file)

    ; Strip UTF-8 BOM if present (U+FEFF)
    if (SubStr(content, 1, 1) = Chr(0xFEFF))
        content := SubStr(content, 2)

    ; Normalize newlines
    content := StrReplace(content, "`r`n", "`n")
    content := StrReplace(content, "`r", "`n")

    for line in StrSplit(content, "`n") {
        line := Trim(line)
        if (line = "" || SubStr(line, 1, 1) = "#")
            continue
        if !InStr(line, "=")
            continue

        parts := StrSplit(line, "=", , 2)
        if (parts.Length < 2)
            continue

        legacy := NormalizeKey(parts[1])
        key    := StrLower(Trim(parts[2]))
        if (legacy != "" && key != "")
            m[legacy] := key
    }
    return m
}


; ========================= TITLE PARSING (Modality) =========================
; Extracts modality from PACS window title.
; Expected title patterns: "CT-Chest-...", "MR-Brain-...", "XR-Chest-...",
;   or free-text containing "CT", "MR", "MRI", "X-Ray", "CR", "DX", etc.
; Returns: "CT", "MR", "XR", or "" if unknown.
DetectModality(title) {
    t := StrLower(title)

    ; Pattern 1: leading "CT-" / "MR-" / "XR-" (structured PACS title)
    if RegExMatch(title, "^([A-Za-z]+)-", &m) {
        mod := StrUpper(m[1])
        if (mod = "CT" || mod = "CTA")
            return "CT"
        if (mod = "MR" || mod = "MRI")
            return "MR"
        if (mod = "XR" || mod = "CR" || mod = "DX")
            return "XR"
    }

    ; Pattern 2: keyword anywhere in title
    if RegExMatch(t, "\b(cta|ct)\b")
        return "CT"
    if RegExMatch(t, "\b(mri|mr)\b")
        return "MR"
    if RegExMatch(t, "\b(x-ray|xray|cr|dx)\b")
        return "XR"

    return ""
}

; ========================= TITLE PARSING (Body Part) =========================
DetectBodyPartFromTitle(title) {
    t := StrLower(title)

    ; Pattern: "CT-Chest-..." or "MR-Brain-..."
    if RegExMatch(title, "^[A-Za-z]+-([A-Za-z]+)", &m) {
        bp := m[1]
        ; normalize common forms
        if (StrLower(bp) = "lung")
            return "Chest"
        return bp
    }

    ; Pattern: "CT of Lung ..." / "MR of Brain ..."
    if RegExMatch(t, "\b(of)\s+([a-z]+)\b", &m2) {
        bp2 := m2[2]
        if (bp2 = "lung")
            return "Chest"
        return StrUpper(SubStr(bp2,1,1)) . SubStr(bp2,2)
    }

    ; Keyword fallback
    if RegExMatch(t, "\b(chest|thorax|lung|pulmonary)\b")
        return "Chest"
    if RegExMatch(t, "\b(brain|head|intracranial)\b")
        return "Brain"
    if RegExMatch(t, "\b(abdomen|abdominal)\b")
        return "Abdomen"
    if RegExMatch(t, "\b(pelvis)\b")
        return "Pelvis"

if RegExMatch(t, "\b(hip)\b")
    return "Hip"
if RegExMatch(t, "\b(femur|thigh)\b")
    return "Thigh"
if RegExMatch(t, "\b(calf)\b")
    return "Calf"
if RegExMatch(t, "\b(leg|lower\s*extremity|extremity)\b")
    return "Leg"
    ; [v56] Specific spine levels — must precede generic neck/cervical and spine/thoracic/lumbar
    if RegExMatch(t, "\bcervical[\s\-]*spine\b|\bc[\-]?spine\b")
        return "C-spine"
    if RegExMatch(t, "\bthoracic[\s\-]*spine\b|\bt[\-]?spine\b")
        return "T-spine"
    if RegExMatch(t, "\blumbar[\s\-]*spine\b|\blumbo[\s\-]*sacral\b|\bl[\-]?spine\b")
        return "L-spine"
    if RegExMatch(t, "\b(neck|cervical)\b")
        return "Neck"
    if RegExMatch(t, "\b(spine|thoracic|lumbar)\b")
        return "Spine"

    ; If title explicitly says Others
    if RegExMatch(t, "\bothers\b")
        return "Others"

    return "Unknown"
}

; ========================= LAUNCHER =========================

; Map detected modality + body part → GUI exam type dropdown string
MapToExamType(modality, bodyPart) {
    global ExamRegistry
    bp  := StrLower(bodyPart)
    mod := StrUpper(modality)

    ; [v50] Search Registry by modality + canonical bodyPart + aliases.
    ; Insertion order in BuildExamRegistry() determines priority when multiple
    ; entries share an alias (e.g. "head" → Brain CT before Brain MRI).
    for name, reg in ExamRegistry {
        if (StrUpper(reg["modality"]) != mod)
            continue
        ; Exact canonical match
        if (StrLower(reg["bodyPart"]) = bp)
            return name
        ; Alias match
        for alias in reg["aliases"] {
            if (alias = bp)
                return name
        }
    }
    return ""  ; no match → GUI will keep default
}

LaunchFindingAssistantFromActiveWindow(capturedTitle := "") {
    global gAutoBodyPart, gAutoContrast, gDoseTags, gAutoExamType

    ; Use captured title if provided, otherwise get current window
    if (capturedTitle = "") {
        try {
            title := WinGetTitle("A")
        } catch {
            return false
        }
    } else {
        title := capturedTitle
    }

    ; Determine modality; if not CT/MR, don't launch (keeps X-ray out)
    mod := DetectModality(title)
    if (mod = "" || mod = "XR") {
        x := 0, y := 0
        MouseGetPos(&x, &y)
        ToolTip("⚠️ 視窗不含 CT/MR，無法啟動 Finding Assistant", x + 20, y + 20)
        SetTimer(() => ToolTip(), -2000)
        return false
    }

    ; Set auto fields for GUI
    gAutoBodyPart := DetectBodyPartFromTitle(title)
    gAutoContrast := DetectContrastFromTitle(title)
    gDoseTags := DetectDoseTagsFromTitle(title)

    ; CTA-specific exam types (check title directly)
    t := StrLower(title)
    if (mod = "CT" && RegExMatch(t, "\b(cta)\b")) {
        if RegExMatch(t, "\b(aort|great\s*vessel)\b")
            gAutoExamType := "CTA Aorta / Great Vessels"
        else if RegExMatch(t, "\b(head|neck|carotid|vertebral)\b")
            gAutoExamType := "CTA Head & Neck"
        else
            gAutoExamType := MapToExamType(mod, gAutoBodyPart)
    } else {
        gAutoExamType := MapToExamType(mod, gAutoBodyPart)
    }

    ; [v38] PACS Snapshot log -- record before GUI opens
    PacsSnapshot_Log(title, mod, gAutoBodyPart)

    ; Show GUI (CreateMainGUI uses gAutoBodyPart/gAutoExamType/gAutoContrast)
    CreateMainGUI()
    return true
}

; ========================= [v38] PACS SNAPSHOT + PRIVACY HASH =========================
;
; PacsSnapshot_Log() is called from LaunchFindingAssistantFromActiveWindow()
; (XButton1 / Alt+A) every time a CT/MR study is opened in PACS.
;
; Log file:  C:\RIS_Workflow\pacs_snapshot.csv
; Columns:   ts | event | session_id | mrn_hash | accession_hash | modality | body_part | pacs_title_raw
;
; Linkage with RIS events log:
;   Primary key  → session_id   (exact 1-to-1 when CapsLock follows XButton1)
;   Verify layer → mrn_hash     (same daily salt → same patient same day)
;   Fallback     → mrn_hash + date window join (±120 s) when session_id differs
;
; Privacy design:
;   hash = SHA256[:16]( raw_value + yyyyMMdd_salt )
;   Salt rotates daily → cross-day linkage is impossible even if CSV is leaked.
;   Raw MRN / Accession are NEVER written to any log file.
; ======================================================================================

global gPacsLogPath := "C:\RIS_Workflow\pacs_snapshot.csv"

; ── Main entry point ──────────────────────────────────────────────────────────────────
PacsSnapshot_Log(pacsTitle, modality, bodyPart) {
    global gPacsLogPath, S, ENC

    try {
        ; [v39] Store for F9 session summary -- non-PHI, safe to keep in memory
        S["lastModality"] := modality
        S["lastBodyPart"] := bodyPart
        ; Extract identifiers from PACS title
        ; Format: "04987680 張○○  存取編號:E850040BG003  ...  CT-Brain..."
        mrn       := ""
        accession := ""

        ; MRN: 7-9 digit number at start of title
        if RegExMatch(pacsTitle, "^\s*(\d{7,9})\b", &mMrn)
            mrn := mMrn[1]

        ; Accession: after 存取編號: or 存取編號：
        if RegExMatch(pacsTitle, "存取編號[:：]\s*([A-Z0-9]+)", &mAcc)
            accession := mAcc[1]

        ; Hash both (empty string hashes to consistent token, still non-reversible)
        mrnHash := HashPHI(mrn)
        accHash := HashPHI(accession)

        ; Resolve session_id (may be empty if CapsLock not yet pressed)
        sid := ""
        try sid := S["sessionId"]

        ; Ensure log directory + header
        logDir := RegExReplace(gPacsLogPath, "\\[^\\]+$", "")
        if (logDir != "" && !DirExist(logDir))
            DirCreate(logDir)
        if !FileExist(gPacsLogPath)
            FileAppend("ts,event,session_id,mrn_hash,accession_hash,modality,body_part,pacs_title_raw`n", gPacsLogPath, "UTF-8")

        ; Build row
        ts  := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
        row := PacsLog_CsvEsc(ts)                    . ","
             . PacsLog_CsvEsc("XBTN_PACS_OPEN")      . ","
             . PacsLog_CsvEsc(sid)                   . ","
             . PacsLog_CsvEsc(mrnHash)               . ","
             . PacsLog_CsvEsc(accHash)               . ","
             . PacsLog_CsvEsc(modality)              . ","
             . PacsLog_CsvEsc(bodyPart)              . ","
             . PacsLog_CsvEsc(pacsTitle)             . "`n"

        FileAppend(row, gPacsLogPath, "UTF-8")

    } catch {
        ; Swallow all errors -- never interrupt clinical workflow
    }
}

; ── SHA256 daily-salted hash (first 16 hex chars = 64-bit) ────────────────────────────
; Salt = today's date (yyyyMMdd), computed at runtime, never stored.
; Same patient on same day → same hash → joinable within the day.
; Different day → different hash → cross-day tracking impossible.
; Pure Windows API (bcrypt.dll) — no PowerShell, no console flicker.
HashPHI(rawValue) {
    if (rawValue = "")
        return ""

    salt  := FormatTime(A_Now, "yyyyMMdd")
    input := rawValue . salt
    full  := SHA256Hex_UTF8(input)
    return SubStr(full, 1, 16)  ; 16 hex chars = 64-bit collision space
}

SHA256Hex_UTF8(s) {
    ; 取得含 Null 結尾的完整 UTF-8 長度
    reqSize := StrPut(s, "UTF-8")
    buf := Buffer(reqSize, 0)
    StrPut(s, buf, reqSize, "UTF-8")
    ; 實際要 Hash 的資料長度（扣除 Null 結尾）
    dataSize := reqSize - 1

    hAlg := 0
    hHash := 0

    ; Open SHA256 provider
    if (DllCall("bcrypt\BCryptOpenAlgorithmProvider"
        , "Ptr*", &hAlg
        , "WStr", "SHA256"
        , "Ptr", 0
        , "UInt", 0) != 0)
        throw Error("BCryptOpenAlgorithmProvider failed")

    ; Get hash object length
    cbObj := 0
    cbRes := 0
    if (DllCall("bcrypt\BCryptGetProperty"
        , "Ptr", hAlg
        , "WStr", "ObjectLength"
        , "Ptr*", &cbObj
        , "UInt", 4
        , "UInt*", &cbRes
        , "UInt", 0) != 0)
        throw Error("BCryptGetProperty(ObjectLength) failed")

    hashObj := Buffer(cbObj, 0)
    hashVal := Buffer(32, 0) ; SHA256 = 32 bytes

    ; Create hash
    if (DllCall("bcrypt\BCryptCreateHash"
        , "Ptr", hAlg
        , "Ptr*", &hHash
        , "Ptr", hashObj
        , "UInt", hashObj.Size
        , "Ptr", 0
        , "UInt", 0
        , "UInt", 0) != 0)
        throw Error("BCryptCreateHash failed")

    ; Hash data (使用修正後的 dataSize，不含 Null 結尾)
    if (DllCall("bcrypt\BCryptHashData"
        , "Ptr", hHash
        , "Ptr", buf
        , "UInt", dataSize
        , "UInt", 0) != 0)
        throw Error("BCryptHashData failed")

    ; Finish
    if (DllCall("bcrypt\BCryptFinishHash"
        , "Ptr", hHash
        , "Ptr", hashVal
        , "UInt", hashVal.Size
        , "UInt", 0) != 0)
        throw Error("BCryptFinishHash failed")

    ; Cleanup
    if (hHash)
        DllCall("bcrypt\BCryptDestroyHash", "Ptr", hHash)
    if (hAlg)
        DllCall("bcrypt\BCryptCloseAlgorithmProvider", "Ptr", hAlg, "UInt", 0)

    ; Bytes -> hex
    out := ""
    loop hashVal.Size {
        b := NumGet(hashVal, A_Index - 1, "UChar")
        out .= Format("{:02x}", b)
    }
    return out
}

; ── RFC 4180 CSV escape ───────────────────────────────────────────────────────────────
; ========================= STARTUP =========================
; (startup disabled when included)

; ===== Core self-test (only when run directly) =====
if (A_ScriptFullPath = A_LineFile) {
    MsgBox("Core loaded OK: " gCoreVersion)
    ExitApp
}


