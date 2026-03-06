#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, Off
SetTitleMatchMode "2"

; ======================================================
; FindingAssistant Launcher (stable)
; - Auto-picks latest FindingAssistant_Core_vXX[_Y].ahk in the same folder
; - Prefers "FindingAssistant Hotkeys_stable.ahk" if present, else falls back
; - Generates FA_runner.ahk and runs it via the same AHK v2 binary
; ======================================================

; -------------------------
; 0) Resolve hotkeys file
; -------------------------
hot := ""
cands := [
    A_ScriptDir "\FindingAssistant Hotkeys_stable.ahk",
    A_ScriptDir "\FindingAssistant%20Hotkeys_stable.ahk", ; if downloaded with URL-encoding
    A_ScriptDir "\FindingAssistant Hotkeys.ahk",
    A_ScriptDir "\FindingAssistant_Hotkeys.ahk"
]
for p in cands {
    if FileExist(p) {
        hot := p
        break
    }
}
if (hot = "") {
    MsgBox "❌ Missing Hotkeys file in:`n" A_ScriptDir "`n`nNeed one of:`n- FindingAssistant Hotkeys_stable.ahk`n- FindingAssistant Hotkeys.ahk`n- FindingAssistant_Hotkeys.ahk"
    ExitApp
}

; -------------------------
; 1) Scan Core versions
; -------------------------
cores := []  ; array of objects: {path,name,maj,mn}

Loop Files, A_ScriptDir "\FindingAssistant_Core_v*.ahk" {
    fp := A_LoopFileFullPath
    fn := A_LoopFileName

    maj := 0
    mn := 0

    ; robust version parse (avoid Integer() for older v2 builds)
    if RegExMatch(fn, "i)v(\d+)(?:_(\d+))?\.ahk$", &m) {
        try maj := (m[1] + 0)
        catch
            maj := 0

        try {
            if (m.Count >= 2 && m[2] != "")
                mn := (m[2] + 0)
        } catch {
            mn := 0
        }
    }

    cores.Push({path: fp, name: fn, maj: maj, mn: mn})
}

if (cores.Length = 0) {
    MsgBox "❌ No Core found in:`n" A_ScriptDir "`n`nNeed files like:`nFindingAssistant_Core_v57_7.ahk"
    ExitApp
}

; -------------------------
; 2) Sort by version desc (bubble sort, AHK v2-safe)
; -------------------------
swapped := true
while swapped {
    swapped := false
    limit := cores.Length - 1
    if (limit < 1)
        break

    Loop limit {
        i := A_Index
        a := cores[i]
        b := cores[i+1]
        if (b.maj > a.maj) || (b.maj = a.maj && b.mn > a.mn) {
            cores[i] := b
            cores[i+1] := a
            swapped := true
        }
    }
}

; -------------------------
; 3) Start latest Core
; -------------------------
StartRunner(cores[1].path, hot)

; -------------------------
; 4) StartRunner impl
; -------------------------
StartRunner(corePath, hotPath) {
    ; runner written next to launcher (avoid temp restrictions)
    runner := A_ScriptDir "\FA_runner.ahk"
    try FileDelete runner

    SplitPath corePath, &coreFile
    lbl := RegExReplace(coreFile, "\.ahk$", "")

    txt := '#Requires AutoHotkey v2.0' . "`r`n"
    txt .= '#SingleInstance Force' . "`r`n"
    txt .= '#Warn All, Off' . "`r`n"
    txt .= 'Persistent()' . "`r`n"
    txt .= 'SetTitleMatchMode "2"' . "`r`n"
    txt .= 'global gCoreFileLabel := "' lbl '"' . "`r`n"
    txt .= '#Include "' hotPath '"' . "`r`n"
    txt .= '#Include "' corePath '"' . "`r`n"
    try {
        FileAppend txt, runner, "UTF-8"
    } catch as e {
        MsgBox "❌ Failed to write runner:`n" runner "`n`n" e.Message
        return
    }


    ; Prefer AHK v2 explicitly, fallback to A_AhkPath
    ahkV2 := "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
    ahkExe := FileExist(ahkV2) ? ahkV2 : A_AhkPath
    try {
        Run('"' ahkExe '" "' runner '"', A_ScriptDir)
    } catch as e {
        MsgBox "❌ Run runner failed.`n`n"
            . "AHK: " ahkExe "`n"
            . "Runner: " runner "`n"
            . "Dir: " A_ScriptDir "`n`n"
            . "Error: " e.Message
        return
    }

    Sleep 800   ; wait for runner to initialize before Launcher exits
    ExitApp
}
