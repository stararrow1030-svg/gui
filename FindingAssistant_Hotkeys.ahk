
; ======================================================
; FindingAssistant_Hotkeys.ahk
; Contains: hotkey actions, GUI helpers, session logging
; Requires: FindingAssistant_Core_vXX.ahk (loaded first by runner)
; ======================================================

; === 固定 DPI 行為（避免縮放造成座標錯亂）===
#Warn All, Off
DllCall("SetThreadDpiAwarenessContext", "ptr", -4)

#Hotstring NoAutoReplace
#Hotstring EndChars -()[]{}:;"/\,.?!`n `t


; ======================================================
; === CFG Path Injection ===
; Must run BEFORE Core is loaded (FA_runner #Include order:
;   1. FindingAssistant_Hotkeys.ahk  ← this file sets CFG paths
;   2. FindingAssistant_Core_vXX.ahk ← reads CFG paths)
;
; A_LineFile always points to THIS file's own folder,
; regardless of where FA_runner.ahk lives.
; ======================================================
global CFG
if !IsSet(CFG)
    CFG := Map()

_CORE_DIR := SubStr(A_LineFile, 1, InStr(A_LineFile, "\",, -1) - 1)
CFG["MapDir"]             := _CORE_DIR
CFG["ChestMapFile"]       := _CORE_DIR "\map_chest_v3.txt"
CFG["ChestSynFile"]       := _CORE_DIR "\synonym_map_v3.txt"
CFG["CTAAortaMapFile"]    := _CORE_DIR "\finding_map_cta_aorta_current.txt"
CFG["BrainMapFile"]       := _CORE_DIR "\finding_map_brain_ct_current.txt"
CFG["CTAHeadNeckMapFile"] := _CORE_DIR "\finding_map_cta_headneck_current.txt"
CFG["FacialCTMapFile"]    := _CORE_DIR "\finding_map_facial_ct_current.txt"
CFG["BrainMRIMapFile"]    := _CORE_DIR "\finding_map_brain_mri_current.txt"
CFG["AbdomenMapFile"]     := _CORE_DIR "\finding_map_abdomen_ct_current.txt"
CFG["AbdomenMRIMapFile"]  := _CORE_DIR "\finding_map_abdomen_mri_current.txt"
CFG["PelvisCTMapFile"]    := _CORE_DIR "\finding_map_pelvis_ct_current.txt"
CFG["CSpineCTMapFile"]    := _CORE_DIR "\finding_map_cspine_ct_current.txt"
CFG["SpineMRIMapFile"]    := _CORE_DIR "\finding_map_spine_mri_current.txt"
CFG["ExtremityMRIMapFile"]:= _CORE_DIR "\finding_map_extremity_mri_current.txt"
CFG["LegCTMapFile"]       := _CORE_DIR "\finding_map_leg_ct_current.txt"
CFG["UniversalMapFile"]   := _CORE_DIR "\finding_map_universal.txt"
; ======================================================

; === Auto-launch phrase.ahk with AutoHotkey v1 ===
; phrase.ahk uses v1 hotstring syntax; must run under AHK v1 interpreter.
; Tries common v1 install paths. Only launches if not already running.
PHRASE_SCRIPT := "C:\Users\Abape\OneDrive\桌面\Text tool\phrase.ahk"
AHKv1_PATHS := [
    "C:\Program Files\AutoHotkey\v1.1\AutoHotkeyU64.exe",
    "C:\Program Files\AutoHotkey\v1.1\AutoHotkeyU32.exe",
    "C:\Program Files\AutoHotkey\AutoHotkeyU64.exe",
    "C:\Program Files\AutoHotkey\AutoHotkeyU32.exe",
    "C:\Program Files\AutoHotkey\AutoHotkey.exe",
    "C:\Program Files (x86)\AutoHotkey\AutoHotkeyU64.exe",
    "C:\Program Files (x86)\AutoHotkey\AutoHotkeyU32.exe",
    "C:\Program Files (x86)\AutoHotkey\AutoHotkey.exe"
]
try {
if FileExist(PHRASE_SCRIPT) {
    ; Check if phrase.ahk is already running (avoid duplicate)
    phraseAlreadyRunning := false
    for proc in ComObjGet("winmgmts:").ExecQuery("SELECT CommandLine FROM Win32_Process WHERE Name LIKE '%AutoHotkey%'") {
        try {
            if InStr(proc.CommandLine, "phrase.ahk") {
                phraseAlreadyRunning := true
                break
            }
        }
    }
    if !phraseAlreadyRunning {
        ahkv1Found := ""
        for p in AHKv1_PATHS {
            if FileExist(p) {
                ahkv1Found := p
                break
            }
        }
        if (ahkv1Found != "") {
            try {
                Run('"' . ahkv1Found . '" "' . PHRASE_SCRIPT . '"')
            }
        }
    }
}
} catch as _phraseErr {
    ; WMI unavailable or error — skip phrase.ahk launch silently
}

; --- Finding Assistant module (CT/MR GUI) ---
; (Pause:: → FindingAssistant_Hotkeys.ahk)

; === 共用報告視窗切換函式(merged_all版本)===
執行叫出報告視窗() {
    activeTitle := WinGetTitle("A")
    re := "\b\d{7,9}\b"
    if RegExMatch(activeTitle, re, &match)
    {
        patientID := match[0]
        targetTitle := "報告編輯 " . patientID
        if WinExist(targetTitle)
        {
            WinActivate(targetTitle)
            return
        }
    }

    winList := WinGetList()
    for thisID in winList
    {
        title := WinGetTitle(thisID)
        if InStr(title, "報告編輯")
        {
            WinActivate("ahk_id " . thisID)
            return
        }
    }

    x := 0, y := 0
    MouseGetPos(&x, &y)
    ToolTip("❌ 找不到報告編輯視窗", x + 20, y + 20)
    SetTimer(() => ToolTip(), -2000)
}

; (^+x:: ^+z:: → FindingAssistant_Hotkeys.ahk)

; ======================================================
; === 座標設定系統（依電腦名稱自動載入）===
; 新增電腦時：在 _LoadCoords() 加一個 else if 區塊即可
; ======================================================
_LoadCoords() {
    pc := A_ComputerName
    c := Map()

    if (pc = "ASUSBAPE") {
        ; ── 台南筆電 (8F1) ──
        ; -- F1 設定選單流程 --
        c["設定選單"]     := [175, 50]
        c["系統設定"]     := [200, 190]
        c["ReportList"]   := [160, 150]
        c["點是"]         := [255, 220]
        c["存檔"]         := [1830, 110]
        c["回報告清單"]   := [40, 70]
        c["第一筆病人"]   := [800, 250]
        c["查詢"]         := [910, 165]
        c["來源"]         := [905, 215]
        ; -- F2 完成報告流程 --
        c["F2.狀態"]      := [900, 210]
        c["F2.完成"]      := [915, 350]
        c["F2.查詢"]      := [1135, 205]
        c["F2.第一筆"]    := [925, 325]
        ; -- F5 查詢重排流程 --
        c["F5.查詢"]      := [1145, 205]
        c["F5.來源"]      := [1255, 270]
        ; -- F3 V5med 貼病歷號 --
        c["F3.輸入欄"]    := [150, 370]
        c["F3.第一個病人"] := [450, 520]
        ; -- 彈窗處理 --
        c["popup.不在院內1"] := [50, 140]
        c["popup.不在院內2"] := [880, 350]

    } else if (pc = "TODO_嘉義桌機") {
        ; ── 嘉義桌機 ──
        ; TODO: 1. 用 MsgBox(A_ComputerName) 取得名稱後替換上面的 "TODO_嘉義桌機"
        ;       2. 從嘉義版 merged_all.ahk 填入正確座標
        ; -- F1 設定選單流程 --
        c["設定選單"]     := [0, 0]   ; TODO
        c["系統設定"]     := [0, 0]   ; TODO
        c["ReportList"]   := [0, 0]   ; TODO
        c["點是"]         := [0, 0]   ; TODO
        c["存檔"]         := [0, 0]   ; TODO
        c["回報告清單"]   := [0, 0]   ; TODO
        c["第一筆病人"]   := [0, 0]   ; TODO
        c["查詢"]         := [0, 0]   ; TODO
        c["來源"]         := [0, 0]   ; TODO
        ; -- F2 完成報告流程 --
        c["F2.狀態"]      := [0, 0]   ; TODO
        c["F2.完成"]      := [0, 0]   ; TODO
        c["F2.查詢"]      := [0, 0]   ; TODO
        c["F2.第一筆"]    := [0, 0]   ; TODO
        ; -- F5 查詢重排流程 --
        c["F5.查詢"]      := [0, 0]   ; TODO
        c["F5.來源"]      := [0, 0]   ; TODO
        ; -- F3 V5med 貼病歷號 --
        c["F3.輸入欄"]    := [0, 0]   ; TODO
        c["F3.第一個病人"] := [0, 0]   ; TODO
        ; -- 彈窗處理 --
        c["popup.不在院內1"] := [0, 0]   ; TODO
        c["popup.不在院內2"] := [0, 0]   ; TODO

    } else {
        ; ── 醫院電腦 (default / fallback) ──
        ; TODO: 確認醫院電腦的 A_ComputerName 後可改成 else if
        ; -- F1 設定選單流程 --
        c["設定選單"]     := [175, 50]
        c["系統設定"]     := [200, 190]
        c["ReportList"]   := [145, 150]
        c["點是"]         := [255, 220]
        c["存檔"]         := [1830, 110]
        c["回報告清單"]   := [35, 75]
        c["第一筆病人"]   := [700, 250]
        c["查詢"]         := [910, 165]
        c["來源"]         := [905, 215]
        ; -- F2 完成報告流程 --
        c["F2.狀態"]      := [900, 210]
        c["F2.完成"]      := [915, 350]
        c["F2.查詢"]      := [1135, 205]
        c["F2.第一筆"]    := [925, 325]
        ; -- F5 查詢重排流程 --
        c["F5.查詢"]      := [1145, 205]
        c["F5.來源"]      := [1255, 270]
        ; -- F3 V5med 貼病歷號 --
        c["F3.輸入欄"]    := [150, 370]
        c["F3.第一個病人"] := [450, 520]
        ; -- 彈窗處理 --
        c["popup.不在院內1"] := [50, 140]
        c["popup.不在院內2"] := [880, 350]
    }
    return c
}
global COORDS := _LoadCoords()

; === 共用動作倉庫（座標從 COORDS 讀取）===
切換到放射科報告系統() {
    WinActivate("放射科報告系統")
    if !WinWaitActive("放射科報告系統",,5) {
        x := 0, y := 0
        MouseGetPos(&x, &y)
        ToolTip("❌ 未找到放射科報告系統視窗", x + 20, y + 20)
        SetTimer(() => ToolTip(), -4000)
        Sleep 4000
        Exit
    }
}

點擊設定選單() {
    global COORDS
    Click COORDS["設定選單"][1], COORDS["設定選單"][2]
    Sleep 600
}

點擊系統設定() {
    global COORDS
    Click COORDS["系統設定"][1], COORDS["系統設定"][2]
    Sleep 600
}

點擊ReportList() {
    global COORDS
    Click COORDS["ReportList"][1], COORDS["ReportList"][2]
    Sleep 500
}

點擊存檔() {
    global COORDS
    Click COORDS["存檔"][1], COORDS["存檔"][2]
    Sleep 800
}

回到報告清單() {
    global COORDS
    Click COORDS["回報告清單"][1], COORDS["回報告清單"][2]
    Sleep 300
}

點擊第一筆病人() {
    global COORDS
    Click COORDS["第一筆病人"][1], COORDS["第一筆病人"][2]
    Sleep 300
}

點擊查詢() {
    global COORDS
    Click COORDS["查詢"][1], COORDS["查詢"][2]
    Sleep 300
}

點擊來源() {
    global COORDS
    Click COORDS["來源"][1], COORDS["來源"][2]
    Sleep 300
}

; === 三合一統一動作函式 ===
; 1. 叫出報告編輯視窗（同步，確保切窗完成）
; 2. 存 log（非同步，背景執行）
;    - 若無 MRN/PACS → 記一筆 CAPSLOCK_NO_EXAM，不污染主資料
; 3. 若 PACS title 是 CT/MR → 呼叫 Finding Assistant GUI（非同步，背景執行）
執行三合一動作() {
    ; ── Step 0: 立即擷取目前視窗 title（在任何切窗前）──
    capturedTitle := ""
    try {
        capturedTitle := WinGetTitle("A")
    }

    ; ── Step 1: 叫出報告編輯視窗（同步）──
    ; 必須同步完成，確保鍵盤焦點立刻到位
    執行叫出報告視窗()

    ; ── Step 2 + 3: 全部交給背景執行，不阻擋鍵盤輸入 ──
    global g_AsyncTitle
    g_AsyncTitle := capturedTitle
    SetTimer(_AsyncLogAndGUI, -150)
}

; 取得目前 PACS 視窗的 exam 資訊
; 回傳 { ok, reason, title, mrn }
_GetActiveExamContext(title) {
    reMRN := "\d{7,9}"
    if !RegExMatch(title, reMRN, &m)
        return { ok: false, reason: "NO_MRN_IN_ACTIVE_TITLE", title: title, mrn: "" }
    return { ok: true, reason: "", title: title, mrn: m[0] }
}

; 記一筆輕量的空觸發 log（寫入 pacs_snapshot.csv，event 欄標記 reason）
_LogNoPacsEvent(reason, activeTitle) {
    global gPacsLogPath, ENC
    try {
        EnsureDir()
        ts := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
        safeTitle := PacsLog_CsvEsc(activeTitle)
        line := ts . ",CAPSLOCK_NO_EXAM," . reason . ",,," . safeTitle . "`n"
        FileAppend(line, gPacsLogPath, ENC)
    } catch {
        ; 忽略 log 失敗，不影響主流程
    }
}

; Step 2+3 非同步執行函式（由 SetTimer 呼叫）
_AsyncLogAndGUI() {
    global S, g_AsyncTitle

    try {
        ; ── Step 2: 檢查孤兒 session ──
        ; 若 S["active"]=true 但報告視窗已關（上次沒按 F9）→ 強制結束舊 session 再開新的
        try {
            if (S["active"] && !_ReportWindowExists()) {
                LogEvent("END_ORPHAN")
                AppendSessionSummary()
                ResetSession()
                x := 0, y := 0
                MouseGetPos(&x, &y)
                ToolTip("⚠️ 前次 session 異常結束，已自動清除", x + 20, y + 20)
                SetTimer(() => ToolTip(), -2500)
            }
        } catch Error as e1 {
            x := 0, y := 0
            MouseGetPos(&x, &y)
            ToolTip("⚠️ 清除孤兒 session 失敗: " . e1.Message, x + 20, y + 20)
            SetTimer(() => ToolTip(), -2500)
            ; 強制 reset 確保不卡住
            ResetSession()
        }

        ; ── Step 2: 啟動新 session（使用統一入口）──
        ; Session_Start 內建 guard：若已 active 會直接 return false
        if (_ReportWindowExists() && Session_Start("AUTO")) {
            x := 0, y := 0
            MouseGetPos(&x, &y)
            ToolTip("▶️ Session started", x + 20, y + 20)
            SetTimer(() => ToolTip(), -2000)
        }

        ; ── 判斷是否有有效的 PACS exam (決定要不要開 GUI) ──
        ctx := _GetActiveExamContext(g_AsyncTitle)

        if (!ctx.ok) {
            ; 沒有影像/MRN → 記空觸發 log，不開 GUI (但不影響上方已啟動的 Session)
            _LogNoPacsEvent(ctx.reason, ctx.title)
            return
        }

        ; ── Step 3: PACS title 是 CT/MR → 呼叫 GUI ──
        try {
            mod := DetectModality(g_AsyncTitle)
            if (mod != "" && mod != "XR")
                LaunchFindingAssistantFromActiveWindow(g_AsyncTitle)
        } catch {
            ; 非 PACS 視窗或無法偵測 modality，忽略
        }

    } catch Error as e {
        ; 最外層保護：任何未預期錯誤都顯示，不悶死
        x := 0, y := 0
        MouseGetPos(&x, &y)
        ToolTip("❌ _AsyncLogAndGUI 錯誤: " . e.Message, x + 20, y + 20)
        SetTimer(() => ToolTip(), -3000)
    }
}

; 檢查是否有任何「報告編輯」視窗存在（不管是否在前景）
_ReportWindowExists() {
    try {
        winList := WinGetList()
        for id in winList {
            try {
                if InStr(WinGetTitle(id), "報告編輯")
                    return true
            } catch {
                continue
            }
        }
    } catch {
    }
    return false
}

; (!a:: → FindingAssistant_Hotkeys.ahk)

; === 共用函式:檢查並處理異動報告視窗(merged_new版本 - 使用Enter鍵)===
檢查並處理異動報告視窗() {
    found := false
    
    try {
        winList := WinGetList()
        
        ; 檢查異動報告視窗
        for thisID in winList {
            try {
                title := WinGetTitle(thisID)
                if InStr(title, "異動報告") {
                    try {
                        ; 先確保視窗在前景並可見
                        WinActivate("ahk_id " . thisID)
                        WinSetAlwaysOnTop true, "ahk_id " . thisID
                        
                        ; 等待視窗完全顯示並穩定(延長至10秒)
                        if !WinWaitActive("ahk_id " . thisID, , 10) {
                            continue
                        }
                        
                        ; 額外延遲確保視窗完全載入(增加至1.5秒)
                        Sleep 1500
                        
                        ; 使用Enter鍵關閉異動報告(這會觸發放棄功能)
                        Send("{Enter}")
                        
                        ; 顯示提示
                        x := 0, y := 0
                        MouseGetPos(&x, &y)
                        ToolTip("🚫 已用Enter鍵處理異動報告", x + 20, y + 20)
                        SetTimer(() => ToolTip(), -2000)
                        found := true
                    } catch {
                        ; 如果找不到視窗或發生錯誤
                        x := 0, y := 0
                        MouseGetPos(&x, &y)
                        ToolTip("⚠️ 無法處理異動報告", x + 20, y + 20)
                        SetTimer(() => ToolTip(), -2000)
                    }
                    break
                }
            } catch {
                ; 跳過無法獲取標題的視窗
                continue
            }
        }
        
        ; 如果沒找到異動報告,檢查其他提示視窗
        if !found {
            ; 檢查常見的提示視窗標題
            alertKeywords := ["提示", "警告", "錯誤", "確認", "訊息", "Message", "Alert", "Warning", "Error", "Confirm"]
            
            for thisID in winList {
                try {
                    title := WinGetTitle(thisID)
                    for keyword in alertKeywords {
                        if InStr(title, keyword) {
                            try {
                                WinActivate("ahk_id " . thisID)
                                WinSetAlwaysOnTop true, "ahk_id " . thisID
                                ; 等待視窗啟動並穩定(延長至10秒)
                                if !WinWaitActive("ahk_id " . thisID, , 10) {
                                    continue
                                }
                                ; 額外延遲確保視窗完全載入(增加至800ms)
                                Sleep 800
                                ; 使用Enter鍵關閉
                                Send("{Enter}")
                                ; 顯示提示
                                x := 0, y := 0
                                MouseGetPos(&x, &y)
                                ToolTip("✅ 已用Enter鍵處理提示視窗: " . title, x + 20, y + 20)
                                SetTimer(() => ToolTip(), -2000)
                                found := true
                                break
                            } catch {
                                ; 跳過無法處理的視窗
                                continue
                            }
                        }
                    }
                    if found
                        break
                } catch {
                    ; 跳過無法獲取標題的視窗
                    continue
                }
            }
        }
    } catch {
        ; 整體錯誤處理
        x := 0, y := 0
        MouseGetPos(&x, &y)
        ToolTip("⚠️ 檢查異動報告時發生錯誤", x + 20, y + 20)
        SetTimer(() => ToolTip(), -2000)
    }
    
    return found
}

; (F11:: → FindingAssistant_Hotkeys.ahk)

; (#HotIf Enter:: blocks → FindingAssistant_Hotkeys.ahk)

; === 自訂快捷鍵倉庫(merged_new版本)===

; F1 → 執行 Ctrl+Shift+X (啟用自動開啟下一筆)


; F3 → 從報告編輯視窗複製病歷號碼並貼到網頁版 v5med client (功能在檔案末尾定義)

; === F5 點擊查詢、來源並回到第一筆病人 ===
F5::
{
    global COORDS
    try {
        ; 1. 先切換到放射科報告系統
        WinActivate('放射科報告系統')
        if !WinWaitActive("放射科報告系統", , 3) {
            x := 0, y := 0
            MouseGetPos(&x, &y)
            ToolTip("❌ 找不到放射科報告系統視窗", x + 20, y + 20)
            SetTimer(() => ToolTip(), -3000)
            return
        }
        Sleep 300

        ; 2. 點擊查詢按鈕
        Click COORDS["F5.查詢"][1], COORDS["F5.查詢"][2]
        Sleep 500  ; 等待查詢完成

        ; 3. 點擊來源
        Click COORDS["F5.來源"][1], COORDS["F5.來源"][2]
        Sleep 300

        ; 4. 點擊第一筆病人
        點擊第一筆病人()
        
        ; 顯示完成提示
        x := 0, y := 0
        MouseGetPos(&x, &y)
        ToolTip("✅ 已點擊查詢、來源並回到第一筆病人 (F5)", x + 20, y + 20)
        SetTimer(() => ToolTip(), -2000)
        
    } catch Error as e {
        ; 錯誤處理
        x := 0, y := 0
        MouseGetPos(&x, &y)
        ToolTip("❌ 執行失敗: " . e.Message, x + 20, y + 20)
        SetTimer(() => ToolTip(), -2000)
    }
}

; === Pop-up handler: 「該病人不在院內」(原 F8 功能) ===
HandleNotInHospitalPopup() {
        global COORDS
        try {
            found := false
            winList := WinGetList()
            
            ; 遍歷所有視窗尋找包含「該病人不在院內」的視窗
            for thisID in winList {
                try {
                    title := WinGetTitle(thisID)
                    if InStr(title, "該病人不在院內") {
                        ; 找到視窗,先啟動它
                        WinActivate("ahk_id " . thisID)
                        WinSetAlwaysOnTop true, "ahk_id " . thisID
                        
                        ; 等待視窗完全啟動
                        if !WinWaitActive("ahk_id " . thisID, , 3) {
                            continue
                        }
                        
                        ; 延遲確保視窗穩定
                        Sleep 300
                        
                        ; 第一次點擊
                        Click COORDS["popup.不在院內1"][1], COORDS["popup.不在院內1"][2]
                        Sleep 200

                        ; 第二次點擊
                        Click COORDS["popup.不在院內2"][1], COORDS["popup.不在院內2"][2]
                        
                        ; 顯示成功提示
                        x := 0, y := 0
                        MouseGetPos(&x, &y)
                        ToolTip("✅ 已處理「該病人不在院內」視窗`n第1次點擊: (50, 140)`n第2次點擊: (880, 350)", x + 20, y + 20)
                        SetTimer(() => ToolTip(), -2500)
                        
                        found := true
                        break
                    }
                } catch {
                    ; 跳過無法獲取標題的視窗
                    continue
                }
            }
            
            ; 如果沒找到視窗（靜默回傳，讓 F11 fallback 到異動報告處理）
            
        } catch Error as e {
            found := false
        }
    return found
}



; === CapsLock：三合一動作（叫出報告編輯 + 存log + CT/MR呼叫GUI）===

; --- Unified session start: single entry point for all callers ---
; Returns true if a NEW session was started, false if already running.
Session_Start(reason := "AUTO") {
    global S
    if S["active"]
        return false
    try {
        S["active"] := true
        S["paused"] := false
        S["sessionId"] := GuidLike()
        S["startNow"] := A_Now
        S["startTick"] := A_TickCount
        S["lastResumeTick"] := A_TickCount
        S["activeMs"] := 0
        S["interruptionCount"] := 0
        LogEvent("START_" . reason)
    } catch Error as e {
        S["active"] := false
        return false
    }
    return true
}



; === F3 從報告編輯視窗複製病歷號碼並貼到網頁版 v5med client ===
; ============================================================
;  RIS Workflow Logger (已整合，移除重複的 #Requires/#SingleInstance)
;   - F2: START session (取消原本F2功能：不送出F2)
;   - F6: PAUSE/RESUME (原本無功能：不送出F6)
;   - F9: SUBMIT + LOG + 送出原本F9（一定要送出報告）
;  Privacy: NO MRN / NO PHI, timestamp + session metrics only
; ============================================================

; ---- Safety tuning (optional but helpful) ----
A_MaxHotkeysPerInterval := 200
A_HotkeyInterval := 200
#MaxThreadsPerHotkey 1

; ----------------------------
; User settings
; ----------------------------
LOG_DIR := "C:\RIS_Workflow"
REPORT_TITLE_KW := "報告編輯"
ENC := "UTF-8"

; ----------------------------
; Session state (consolidated into Map S)
; ----------------------------
global gLastResult      := ""   ; [v45] 儲存最後一次 Generate 的原始文字，供 Insert/Copy 使用
global gCapturedImpList := []  ; [v55_7] captured raw-sentence impression list from router
global gCandidatesText  := ""   ; [v51] Extract (>) 後的候選句，非空時 Generate 優先讀這裡
global gPacsLogPath   := "C:\\RIS_Workflow\\pacs_snapshot.csv"  ; default, overridden by Core

; --- Session state Map: single source of truth ---
_DefaultSession() {
    m := Map()
    m["active"] := false
    m["paused"] := false
    m["sessionId"] := ""
    m["startNow"] := ""
    m["startTick"] := 0
    m["lastResumeTick"] := 0
    m["activeMs"] := 0
    m["interruptionCount"] := 0
    m["lastModality"] := ""
    m["lastBodyPart"] := ""
    return m
}
global S := _DefaultSession()

; ----------------------------
; Helpers
; ----------------------------
InReportWindow() {
    global REPORT_TITLE_KW
    try {
        title := WinGetTitle("A")
        return InStr(title, REPORT_TITLE_KW, false) > 0
    } catch {
        return false
    }
}

EnsureDir() {
    global LOG_DIR
    if !DirExist(LOG_DIR)
        DirCreate(LOG_DIR)
}

MonthKey(now) => FormatTime(now, "yyyyMM")
Ts(now) => FormatTime(now, "yyyy-MM-dd HH:mm:ss")

GuidLike() {
    now := A_Now
    r := Random(100000, 999999)
    return FormatTime(now, "yyyyMMddHHmmss") "-" r
}

EventsPath(now) {
    global LOG_DIR
    return LOG_DIR "\events_" MonthKey(now) ".csv"
}

SessionsPath(now) {
    global LOG_DIR
    return LOG_DIR "\sessions_" MonthKey(now) ".csv"
}

EnsureHeaders(now) {
    global ENC
    ep := EventsPath(now)
    sp := SessionsPath(now)
    if !FileExist(ep)
        FileAppend("timestamp,session_id,event,active_ms,interruption_count,paused_flag,session_total_ms,mrn_hash`n", ep, ENC)
    if !FileExist(sp)
        FileAppend("start_time,end_time,session_id,active_ms,interruption_count,session_total_ms,last_modality,last_body_part`n", sp, ENC)
}

AccumulateActiveUpToNow() {
    global S
    if (!S["paused"] && S["lastResumeTick"] > 0) {
        S["activeMs"] += (A_TickCount - S["lastResumeTick"])
        S["lastResumeTick"] := A_TickCount
    }
}

LogEvent(eventName, now := "") {
    global S, ENC

    if (now = "")
        now := A_Now

    EnsureDir()
    EnsureHeaders(now)

    totalMs := 0
    if (S["active"] && S["startTick"] > 0)
        totalMs := A_TickCount - S["startTick"]

    ; [v38] Extract MRN from RIS report-edit window title → daily hash
    ; RIS title format: "報告編輯 04987680" (8-digit MRN after space)
    mrnHash := ""
    try {
        risTitle := WinGetTitle("A")
        if RegExMatch(risTitle, "\b(\d{7,9})\b", &mMrn)
            mrnHash := HashPHI(mMrn[1])
    }

    line := Ts(now) "," S["sessionId"] "," eventName "," S["activeMs"] "," S["interruptionCount"] "," (S["paused"] ? 1 : 0) "," totalMs "," mrnHash "`n"
    FileAppend(line, EventsPath(now), ENC)
}

AppendSessionSummary(endNow := "") {
    global S, ENC

    if (endNow = "")
        endNow := A_Now

    EnsureDir()
    EnsureHeaders(endNow)

    totalMs := (S["startTick"] > 0) ? (A_TickCount - S["startTick"]) : 0
    ; [v39] append last_modality + last_body_part (set by PacsSnapshot_Log at XButton1 time)
    line := Ts(S["startNow"]) "," Ts(endNow) "," S["sessionId"] "," S["activeMs"] "," S["interruptionCount"] "," totalMs "," S["lastModality"] "," S["lastBodyPart"] "`n"
    FileAppend(line, SessionsPath(endNow), ENC)
}

ResetSession() {
    global S
    S := _DefaultSession()
}

; ============================================================
; RIS Logger Hotkeys (with ToolTip feedback)
; ============================================================

; F2 = START (在報告編輯內取消原功能：不送出F2)
; F6 = PAUSE/RESUME（原本無功能：不送出F6）
; F9 = SUBMIT + LOG + 送出原本F9（避免遞迴：用 $F9）
BackupDailyWorkflowCSVs(now) {
    ; Copies the current month sessions/events CSV into a daily backup folder.
    ; Backup file name: yyyy-MM-dd_sessions_YYYY-MM.csv (and events...)
    try {
        backupDir := "C:\RIS_Workflow\daily_backup"
        DirCreate(backupDir)

        dateTag := FormatTime(now, "yyyy-MM-dd")
        sp := SessionsPath(now)
        ep := EventsPath(now)

        if FileExist(sp) {
            SplitPath(sp, &name)
            FileCopy(sp, backupDir . "\" . dateTag . "_" . name, 1)
        }
        if FileExist(ep) {
            SplitPath(ep, &name2)
            FileCopy(ep, backupDir . "\" . dateTag . "_" . name2, 1)
        }
        return true
    } catch Error as e {
        return false
    }
}

_DeidLine_Generic(line) {
    ; Replace likely identifiers (7-12 digits), but avoid pure date strings like 20260220...
    try {
        out := ""
        pos := 1
        while RegExMatch(line, "\b(?!20\d{5,})\d{7,12}\b", &m, pos) {
            hitPos := m.Pos[0]
            hitLen := m.Len[0]
            out .= SubStr(line, pos, hitPos - pos) . HashPHI(m[0])
            pos := hitPos + hitLen
        }
        out .= SubStr(line, pos)
        return out
    } catch Error as e {
        return line
    }
}

FindRISLogDayDir(dateTag) {
    ; Attempts to locate vendor RIS native log folder:
    ; e.g. C:\CychApp\CychPeriReport001\CychPeriReport-CI_xxxxx\Logs\yyyy-MM-dd\
    bases := [
        "C:\CychApp\CychPeriReport001",
        "C:\CychApp"
    ]

    for base in bases {
        if !DirExist(base)
            continue

        ; Search for ...\Logs\<dateTag>\
        try {
            Loop Files (base . "\**\Logs\" . dateTag), "D R" {
                return A_LoopFileFullPath
            }
        } catch Error as e {
            ; ignore
        }
    }
    return ""
}

BuildDeidMergedRISLog(now) {
    ; Build a de-identified merged CSV from RIS native log files (best-effort).
    try {
        EnsureDir()
        dateTag := FormatTime(now, "yyyy-MM-dd")
        dayDir := FindRISLogDayDir(dateTag)
        if (dayDir = "")
            return false

        outPath := LOG_DIR "\deid_merged_" dateTag ".csv"
        if !FileExist(outPath)
            FileAppend("date,source_file,line_deid`n", outPath, ENC)

        Loop Files dayDir "\*", "F" {
            src := A_LoopFileFullPath
            SplitPath(src, &fname)

            content := ""
            try content := FileRead(src, ENC)
            catch Error as eRead {
                try content := FileRead(src)  ; fallback
            }

            ; Normalize line endings then process line-by-line
            content := StrReplace(content, "`r`n", "`n")
            content := StrReplace(content, "`r", "`n")

            for , line in StrSplit(content, "`n") {
                if (Trim(line) = "")
                    continue
                safe := _DeidLine_Generic(line)
                ; Quote-escape for CSV
                safe := StrReplace(safe, Chr(34), "'")  ; replace double-quotes for CSV safety
                row  := dateTag . "," . Chr(34) . fname . Chr(34) . "," . Chr(34) . safe . Chr(34) . "`n"
                FileAppend(row, outPath, ENC)
            }
        }
        return true
    } catch Error as e {
        return false
    }
}



; === F8: Launch Finding Assistant (auto-parse PACS title) ===
; F8 reserved (no action)

; === F8 phrase.ahk 管理（Run / Edit）===
; 第一次按 F8：用 AHK v1 啟動 phrase.ahk（若已在跑則 reload）
; Shift+F8：用記事本開啟 phrase.ahk 編輯
; ===============================
; Phrase.ahk quick edit & hot-reload (AHK v1)
; F8: first press = edit in Notepad, then auto-reload when Notepad closes
;     (if you press F8 again while Notepad is open, it will reload immediately)
; ===============================
global gPhraseEditMode := false
global gPhraseEditorPID := 0
CheckPhraseNotepadClosed()
{
    global gPhraseEditorPID

    ; still open
    if (gPhraseEditorPID && ProcessExist(gPhraseEditorPID))
        return

    ; closed -> stop timer, reload phrase only, reset state
    SetTimer(CheckPhraseNotepadClosed, 0)
    RestartPhraseV1()
    ResetPhraseEditState()

    ToolTip("✅ phrase.ahk 已套用")
    SetTimer(() => ToolTip(), -1200)
}

ResetPhraseEditState()
{
    global gPhraseEditMode, gPhraseEditorPID
    gPhraseEditMode := false
    gPhraseEditorPID := 0
}

RestartPhraseV1()
{
    ; 只重啟 phrase.ahk（不 reload 主程式）
    global PHRASE_SCRIPT, AHKv1_PATHS

    if !FileExist(PHRASE_SCRIPT)
        return false

    ; Find AHK v1 executable
    ahkv1 := ""
    for p in AHKv1_PATHS {
        if FileExist(p) {
            ahkv1 := p
            break
        }
    }
    if (ahkv1 = "")
        return false

    ; Close any running phrase.ahk instances (AutoHotkey v1/v2) by command line match
    try {
        wmi := ComObjGet("winmgmts:")
        for proc in wmi.ExecQuery("SELECT ProcessId, Name, CommandLine FROM Win32_Process WHERE Name LIKE '%AutoHotkey%'") {
            try {
                if (proc.CommandLine && InStr(proc.CommandLine, "phrase.ahk")) {
                    try ProcessClose(proc.ProcessId)
                }
            }
        }
    }

    Sleep 120
    Run('"' . ahkv1 . '" "' . PHRASE_SCRIPT . '"')
    return true
}


; ============================================================
; === HOTKEY 觸發區 ===
; 所有函式定義完畢後才宣告，確保呼叫時函式已存在
; ============================================================

; ----------------------------------------------------------
; CapsLock / Pause / XButton1 → 三合一動作
; ----------------------------------------------------------
CapsLock:: {
    if Session_Start("CAPSLOCK") {
        x := 0, y := 0
        MouseGetPos(&x, &y)
        ToolTip("✅ Session started (CapsLock)", x + 20, y + 20)
        SetTimer(() => ToolTip(), -1200)
    }
    執行三合一動作()
}

Pause:: {
    if Session_Start("PAUSE") {
        x := 0, y := 0
        MouseGetPos(&x, &y)
        ToolTip("✅ Session started (Pause)", x + 20, y + 20)
        SetTimer(() => ToolTip(), -1200)
    }
    執行三合一動作()
}

XButton1:: {
    if Session_Start("XBUTTON1") {
        x := 0, y := 0
        MouseGetPos(&x, &y)
        ToolTip("✅ Session started (XButton1)", x + 20, y + 20)
        SetTimer(() => ToolTip(), -1200)
    }
    執行三合一動作()
}

; ----------------------------------------------------------
; Ctrl+Shift+X / Z → 叫出報告視窗
; ----------------------------------------------------------
^+x::執行叫出報告視窗()
^+z::執行叫出報告視窗()

; ----------------------------------------------------------
; !a → 從當前視窗手動啟動 Finding Assistant GUI（穩定版）
; - 先用原本 title 嘗試（符合 CT/MR 才啟動）
; - 若偵測不到 modality（某些 PACS 標題不含 CT/MR），再「強制」補上 CT 重新嘗試
; ----------------------------------------------------------
!a:: {
    title := ""
    try title := WinGetTitle("A")

    ok := false
    try ok := LaunchFindingAssistantFromActiveWindow(title)

    if (!ok) {
        ; Force fallback: append a modality hint so DetectModality() can pass
        forcedTitle := (title != "" ? title . " CT" : "CT")
        try ok := LaunchFindingAssistantFromActiveWindow(forcedTitle)
    }

    if (!ok) {
        x := 0, y := 0
        MouseGetPos(&x, &y)
        ToolTip("⚠️ Alt+A 未能啟動 GUI（視窗標題可能無法辨識）。`n可改用在 PACS 內按一次後再試，或回報我 title。", x+20, y+20)
        SetTimer(() => ToolTip(), -2500)
    }
}

; ----------------------------------------------------------
; F11 → 合併處理：異動報告視窗 + 「該病人不在院內」彈窗
; 先嘗試「異動報告」，找不到再嘗試「該病人不在院內」
; ----------------------------------------------------------
F11:: {
    handled := 檢查並處理異動報告視窗()
    if !handled
        HandleNotInHospitalPopup()
}

; ----------------------------------------------------------
; F6 → PAUSE / RESUME session
; ----------------------------------------------------------
F6:: {
    global S
    if !S["active"] {
        x := 0, y := 0
        MouseGetPos(&x, &y)
        ToolTip("⚠️ 無進行中 session", x + 20, y + 20)
        SetTimer(() => ToolTip(), -1500)
        return
    }
    if !S["paused"] {
        AccumulateActiveUpToNow()
        S["paused"] := true
        S["interruptionCount"] += 1
        LogEvent("PAUSE")
        x := 0, y := 0
        MouseGetPos(&x, &y)
        ToolTip("⏸️ Session paused", x + 20, y + 20)
        SetTimer(() => ToolTip(), -1500)
    } else {
        S["paused"] := false
        S["lastResumeTick"] := A_TickCount
        LogEvent("RESUME")
        x := 0, y := 0
        MouseGetPos(&x, &y)
        ToolTip("▶️ Session resumed", x + 20, y + 20)
        SetTimer(() => ToolTip(), -1500)
    }
}

; ----------------------------------------------------------
; $F9 → SUBMIT + LOG + 送出原本 F9（$ 前綴避免遞迴）
; ----------------------------------------------------------
$F9:: {
    global S
    if (S["active"]) {
        _activeText := ""
        try {
            AccumulateActiveUpToNow()

            ; Human-readable active time (min/sec)
            _totalSec := Floor(S["activeMs"] / 1000)
            _min := Floor(_totalSec / 60)
            _sec := Mod(_totalSec, 60)
            if (_min > 0)
                _activeText := _min " min " _sec " sec"
            else
                _activeText := _sec " sec"

            LogEvent("SUBMIT")
            AppendSessionSummary()
            BackupDailyWorkflowCSVs(A_Now)
            BuildDeidMergedRISLog(A_Now)
        } finally {
            ResetSession()
        }

        x := 0, y := 0
        MouseGetPos(&x, &y)
        ToolTip("✅ 報告送出，session 已結束`nActive time: " _activeText, x + 20, y + 20)
        SetTimer(() => ToolTip(), -3000)
    }
    Send("{F9}")
}

; ----------------------------------------------------------
; F8 → phrase.ahk 編輯 / Hot-reload
; ----------------------------------------------------------
F8:: {
    global gPhraseEditMode, gPhraseEditorPID, PHRASE_SCRIPT

    ; 若記事本已開啟中，再按 F8 = 強制立即 reload
    if (gPhraseEditMode && ProcessExist(gPhraseEditorPID)) {
        RestartPhraseV1()
        ResetPhraseEditState()
        ToolTip("🔄 phrase.ahk 強制 reload")
        SetTimer(() => ToolTip(), -1200)
        return
    }

    if !FileExist(PHRASE_SCRIPT) {
        x := 0, y := 0
        MouseGetPos(&x, &y)
        ToolTip("❌ 找不到 phrase.ahk: " . PHRASE_SCRIPT, x + 20, y + 20)
        SetTimer(() => ToolTip(), -2500)
        return
    }

    ; 開啟記事本編輯，關閉後自動 reload
    pid := 0
    try pid := Run('notepad.exe "' . PHRASE_SCRIPT . '"')
    gPhraseEditMode := true
    gPhraseEditorPID := pid
    SetTimer(CheckPhraseNotepadClosed, 1000)

    x := 0, y := 0
    MouseGetPos(&x, &y)
    ToolTip("📝 phrase.ahk 編輯中…關閉記事本後自動套用", x + 20, y + 20)
    SetTimer(() => ToolTip(), -2000)
}

; ----------------------------------------------------------
; F1 → 啟用「自動開啟下一筆」
;   切到放射科報告系統 → 設定選單 → 系統設定 → ReportList
;   → 點「是」 → 存檔 → 回報告清單 → 第一筆病人
; ----------------------------------------------------------
F1:: {
    global COORDS
    try {
        切換到放射科報告系統()
        Sleep 300
        點擊設定選單()
        點擊系統設定()
        點擊ReportList()
        Click COORDS["點是"][1], COORDS["點是"][2]
        Sleep 300
        點擊存檔()
        回到報告清單()
        點擊第一筆病人()

        x := 0, y := 0
        MouseGetPos(&x, &y)
        ToolTip("✅ 自動開啟下一筆報告功能已啟用 (F1)", x + 20, y + 20)
        SetTimer(() => ToolTip(), -5000)
    } catch Error as e {
        x := 0, y := 0
        MouseGetPos(&x, &y)
        ToolTip("❌ F1 執行失敗: " . e.Message, x + 20, y + 20)
        SetTimer(() => ToolTip(), -3000)
    }
}

; ----------------------------------------------------------
; F2 → 關掉原本報告，點完成報告的第一筆修改報告
;   1. Esc 離開報告編輯
;   2. 處理異動報告彈窗
;   3. 切到放射科報告系統
;   4. 點狀態→完成→查詢→第一筆
; ----------------------------------------------------------
F2:: {
    global COORDS
    ; 1. 按 Esc 離開報告編輯畫面
    Send("{Esc}")
    Sleep 500

    ; 2. 檢查是否有異動報告或其他提示視窗跳出
    檢查並處理異動報告視窗()

    ; 3. 啟動放射科報告系統視窗
    try {
        WinActivate('放射科報告系統')
        if !WinWaitActive("放射科報告系統", , 3) {
            x := 0, y := 0
            MouseGetPos(&x, &y)
            ToolTip("❌ 找不到放射科報告系統視窗", x + 20, y + 20)
            SetTimer(() => ToolTip(), -3000)
            return
        }
        Sleep 300
    } catch {
        x := 0, y := 0
        MouseGetPos(&x, &y)
        ToolTip("❌ 無法切換到放射科報告系統", x + 20, y + 20)
        SetTimer(() => ToolTip(), -3000)
        return
    }

    ; 4. 點擊「狀態」欄位
    Click COORDS["F2.狀態"][1], COORDS["F2.狀態"][2]
    Sleep 300

    ; 5. 選擇「完成」項目
    Click COORDS["F2.完成"][1], COORDS["F2.完成"][2]
    Sleep 300

    ; 6. 點擊「查詢」按鈕
    Click COORDS["F2.查詢"][1], COORDS["F2.查詢"][2]
    Sleep 500

    ; 7. 回到第一筆資料
    Click COORDS["F2.第一筆"][1], COORDS["F2.第一筆"][2]

    ; 顯示完成提示
    x := 0, y := 0
    MouseGetPos(&x, &y)
    ToolTip("✅ 回到已完成第一筆報告 (F2)", x + 20, y + 20)
    SetTimer(() => ToolTip(), -2000)
}

; ----------------------------------------------------------
; F3 → 從報告編輯視窗複製病歷號碼並貼到網頁版 v5med client
; ----------------------------------------------------------
F3:: {
    global COORDS
    try {
        ; 1. 尋找報告編輯視窗
        found := false
        patientID := ""
        reportWindowID := 0

        winList := WinGetList()
        for thisID in winList {
            try {
                title := WinGetTitle(thisID)
                if InStr(title, "報告編輯") {
                    re := "\b\d{7,9}\b"
                    if RegExMatch(title, re, &match) {
                        patientID := match[0]
                        reportWindowID := thisID
                        found := true
                        break
                    }
                }
            } catch {
                continue
            }
        }

        ; 找不到報告編輯視窗或病歷號碼
        if !found || patientID == "" {
            x := 0, y := 0
            MouseGetPos(&x, &y)
            ToolTip("❌ 找不到報告編輯視窗或無法提取病歷號碼", x + 20, y + 20)
            SetTimer(() => ToolTip(), -3000)
            return
        }

        ; 2. 將病歷號碼複製到剪貼簿
        A_Clipboard := patientID
        Sleep 100

        ; 3. 縮小報告編輯視窗
        WinMinimize("ahk_id " . reportWindowID)
        Sleep 300

        ; 4. 切換到網頁版 v5med client
        v5medFound := false
        for thisID in winList {
            try {
                title := WinGetTitle(thisID)
                if (InStr(title, "v5med") || InStr(title, "client") || InStr(title, "V5MED") || InStr(title, "Client")) {
                    WinActivate("ahk_id " . thisID)
                    if WinWaitActive("ahk_id " . thisID, , 2) {
                        v5medFound := true
                        break
                    }
                }
            } catch {
                continue
            }
        }

        ; 找不到特定視窗 → fallback 到瀏覽器
        if !v5medFound {
            browserTitles := ["Chrome", "Edge", "Firefox", "Opera", "Brave"]
            for browser in browserTitles {
                if WinExist("ahk_exe " . browser . ".exe") {
                    WinActivate("ahk_exe " . browser . ".exe")
                    if WinWaitActive("ahk_exe " . browser . ".exe", , 2) {
                        v5medFound := true
                        break
                    }
                }
            }
        }

        Sleep 500

        ; 5. 點擊輸入欄，清空後貼上病歷號碼
        Click COORDS["F3.輸入欄"][1], COORDS["F3.輸入欄"][2]
        Sleep 200
        Send("^a")
        Sleep 100
        Send("{Delete}")
        Sleep 100
        Send("^v")
        Sleep 300

        ; 6. 點擊選擇第一個病人
        Click COORDS["F3.第一個病人"][1], COORDS["F3.第一個病人"][2]
        Sleep 200

        x := 0, y := 0
        MouseGetPos(&x, &y)
        ToolTip("✅ 已將病歷號碼 " . patientID . " 貼到 v5med client`n並選擇第一個病人 (F3)", x + 20, y + 20)
        SetTimer(() => ToolTip(), -3000)

    } catch Error as e {
        x := 0, y := 0
        MouseGetPos(&x, &y)
        ToolTip("❌ F3 執行失敗: " . e.Message, x + 20, y + 20)
        SetTimer(() => ToolTip(), -3000)
    }
}
; =========================================================================================
; Helper: CSV Escape for PACS Logging
; 防止標題中的逗號或引號破壞 CSV 格式
; =========================================================================================
PacsLog_CsvEsc(str) {
    if (str = "")
        return ""
    ; 1. 先把單個雙引號 " 變成兩個雙引號 ""
    str := StrReplace(str, '"', '""')
    ; 2. 如果字串包含逗號、換行或引號，則整個用雙引號包起來
    if (InStr(str, ",") || InStr(str, "`n") || InStr(str, "`r") || InStr(str, '""'))
        return '"' . str . '"'
    return str
}
; ============================================================
; === END OF HOTKEYS ===
; ============================================================