# FindingAssistant_Core_v60 — 修改紀錄

## 專案概述

- **檔案**: `FindingAssistant_Core_v60.ahk`
- **語言**: AutoHotkey v2
- **用途**: 放射科報告自動結構化工具，處理 radiology report bullets，路由到解剖 section，產生 FINDINGS + IMPRESSION

## 架構重點

- **多層路由**: ExtractLocation → LocationToSection → RefineSection → Layer 3 HeuristicRoutes (fallback)
- **Router 流程**: raw text → FilterBullet → impression capture → SplitNegativeSentence → SplitSentences → HeuristicRoutes → bucket
- **Impression 流程**: `gCapturedImpList`(router 擷取) → `BuildImpressionFromList` 合併 `GenerateImpression`(rule-based) 輸出
- **ExamRegistry**: 每種檢查類型的 filter function、heuristic routing、sections、map files

## v60 修改清單

### 1. Session 狀態重置 (Alt+A)
- **位置**: `CreateMainGUI()` (~line 404)
- **問題**: Clinical information 會遺留上次內容
- **修正**: 每次 Alt+A 重置 `gClinicalText`、`gBulletText`、`gModeManual`、`gCandidatesText`

### 2. DPI 感知視窗定位
- **位置**: `CreateMainGUI()` (~line 646)、`ExpandExtractedUI()` (~line 1013)
- **問題**: 螢幕放大 125% 時視窗跑到太右下角
- **修正**: 使用 `A_ScreenDPI / 96` 縮放因子，將 `MonitorGetWorkArea` 的物理像素轉換為邏輯座標

### 3. Centrilobular emphysema → Lung section
- **位置**: `ExtractLocation_ChestCT`、`HeuristicRoutes_ChestCT`、`InferSectionFromText`、`_SectionHitCount_ChestCT`、`AutoDetectSection`（共 5 處）
- **修正**: 新增 `centrilobular` 關鍵字到 lung detection 模式

### 4. Old ribs fracture / rib old fracture → Osseous section
- **位置**: `ExtractLocation_ChestCT` (~line 1678)、`GenerateImpression`、`GenerateImpression_LungNoPrior`、`InferSectionFromText`
- **修正**: 新增 `rib.{0,30}fracture|fracture.{0,30}rib` 任意字序模式，以及 `fracture.{0,20}old|fracture.{0,20}healed` 反序 chronic 模式

### 5. "Suggest clinical correlation and follow-up" 保留在 Impression
- **位置**: `GenerateFindings_Router` (~line 3783)、`BuildImpressionFromList` (~line 3037)
- **問題**: (1) FilterBullet 把 "suggest" 開頭行過濾為空，impression capture 在 `if (clean="") continue` 之後才執行，所以被跳過；(2) `BuildImpressionFromList` 明確抑制 "Suggest clinical correlation" 行
- **修正**: 將 impression capture 移到 `clean=""` 檢查之前（使用 `rawSentence`）；移除 BuildImpressionFromList 中的抑制邏輯

### 6. Pneumobilia → Biliary section（非 Osseous）
- **位置**: `ExtractLocation_ChestCT`、`HeuristicRoutes_ChestCT`、`HeuristicRoutes_AbdomenCT`、`InferSectionFromText`、`AutoDetectSection`（共 5 處）
- **修正**: 新增 `pneumobilia` 關鍵字到 biliary detection 模式

### 7. `** motion artifact **` 不當作 bullet
- **位置**: `FilterBullet_ChestCT` (~line 1350)、`FilterBullet_BrainCT` (~line 1787)、`FilterBullet_AbdomenCT` (~line 2479)、`IsJunkSentence` (~line 1082)
- **修正**: 新增 3 種過濾模式：`^\*\*\s+.*\*\*\s*$`、`^\*\*\s+`、`motion\s+artifact`

### 8. Brain CT osteoma/ostoma → Calvarium section
- **位置**: `HeuristicRoutes_BrainCT`、`HeuristicRoutes_BrainMRI`
- **修正**: 新增 `osteoma|ostoma` 到 Calvarium 模式

### 9. Pleural effusion 優先路由到 Pleura
- **位置**: `ExtractLocation_ChestCT` (~line 1549)、`InferSectionFromText` (~line 4200)
- **修正**: 即使句子提到 lung lobe，pleural effusion 仍路由到 Pleura section

### 10. Abdominal lymphadenopathy 路由修正
- **位置**: `ExtractLocation_ChestCT` (~line 1554)、`InferSectionFromText` (~line 4203)
- **修正**: Abdominal/retroperitoneal lymphadenopathy → Others（非 Mediastinum/Liver）

### 11. 沒有舊片時不帶入 "No interval change"
- **位置**: `GenerateFindings_Router` interval capture (~line 4056)、`BuildImpressionFromList` (~line 3081)
- **問題**: 當 `gHasPrior=0` 時，含有 "no interval change" 的句子仍被推送到 impression
- **修正**:
  - Router interval capture：偵測 stability type（no change / unchanged / stable / stationary）vs progression type，`gHasPrior=0` 且為 stability type 時不推送到 `impList`
  - `BuildImpressionFromList`：安全過濾器，`gHasPrior=0` 時移除開頭為 "No interval change" / "Unchanged compared" / "Stable compared" 的項目

### 12. Subsegmental atelectasis 開頭 → chronic（不放 Impression）
- **位置**: `GenerateImpression` `definitelyChronicRx` (~line 3277)、`GenerateImpression_LungNoPrior` `_chronicExcludeRx` (~line 3168)
- **修正**: 新增 `^subsegmental\s+atelectasis`，句子開頭為 subsegmental atelectasis 時視為 incidental

### 13. DDx + Suggest clinical correlation 合併保留
- **位置**: Chest CT impression capture (~line 3802)、non-Chest-CT impression capture (~line 4008)、`_IMP_ExtractDDxClause` (~line 2954)
- **問題**: DDx 句子後的 "Suggest clinical correlation and follow-up" 被剝離，在 impression 中拆開
- **修正**: 移除 DDx 句子中的 Suggest/Recommend 剝離邏輯，保持完整句子作為一個 impression 項目

### 14. 多行 Clinical Information 支援
- **位置**: `CreateMainGUI` Edit 控件 (~line 576)、`BtnGenerate` (~line 783)、`PrependClinicalInfo` (~line 2914)
- **修正**: Clinical Info 欄位改為 `Multi` 模式（可貼上多行文字），輸出時自動以 `"; "` 合併為單行

## 關鍵函式對照

| 函式名稱 | 用途 |
|----------|------|
| `CreateMainGUI()` | 建立 GUI、定位視窗、初始化狀態 |
| `BtnGenerate()` | 主要產生按鈕，呼叫 Router → Impression |
| `BtnNoChange()` | 快速蓋印 "No interval change" |
| `FilterBullet_ChestCT()` | Chest CT 前處理過濾 |
| `FilterBullet_BrainCT()` | Brain CT 前處理過濾 |
| `FilterBullet_AbdomenCT()` | Abdomen CT 前處理過濾 |
| `ExtractLocation_ChestCT()` | Layer 1 位置提取 |
| `HeuristicRoutes_ChestCT()` | Layer 3 fallback 路由 |
| `HeuristicRoutes_BrainCT()` | Brain CT 啟發式路由 |
| `HeuristicRoutes_BrainMRI()` | Brain MRI 啟發式路由 |
| `HeuristicRoutes_AbdomenCT()` | Abdomen CT 啟發式路由 |
| `GenerateFindings_Router()` | Router 模式產生 FINDINGS |
| `GenerateImpression()` | Rule-based impression 產生器 |
| `GenerateImpression_LungNoPrior()` | 無舊片 Chest CT lung impression |
| `BuildImpressionFromList()` | 合併 router 擷取項目 + rule-based impression |
| `Impression_SummaryOnly()` | Impression 摘要渲染器 |
| `_IMP_ExtractDDxClause()` | 提取 DDx 子句 |
| `_IMP_IsNonFindingSentence()` | 偵測非 finding 句子（no change、recommend 等） |
| `InferSectionFromText()` | 文字推斷 section |
| `_SectionHitCount_ChestCT()` | Chest CT section 計分 |
| `AutoDetectSection()` | 自動偵測 section |
| `IsJunkSentence()` | 偵測垃圾句子（motion artifact 等） |
| `GetNegativeWording()` | 產生 section 陰性描述（prior-aware） |
| `PrependClinicalInfo()` | 加上 Clinical Information 前綴 |

## 重要全域變數

| 變數 | 用途 |
|------|------|
| `gHasPrior` | 是否有舊片比較（checkbox） |
| `gClinicalText` | 臨床資訊文字 |
| `gCapturedImpList` | Router 擷取的 impression 候選句子 |
| `gReportMode` | 報告模式（Standard / Oncology） |
| `gExamType` | 檢查類型（Chest CT、Brain CT 等） |
| `gContrastChoice` | 顯影劑選擇 |
| `gBulletText` | 原始 bullet 輸入 |
| `gCandidatesText` | Extract 後的候選文字 |
| `gLastResult` | 最後產生的結果文字 |
| `ExamRegistry` | 各檢查類型的設定登錄表 |

## 注意事項

- 修改 regex 模式時需同步更新多個函式（ExtractLocation、HeuristicRoutes、InferSectionFromText、AutoDetectSection、_SectionHitCount 等）
- Impression 擷取必須在 `FilterBullet` 之後、`if (clean="") continue` 之前執行（使用 `rawSentence`）
- `definitelyChronicRx` 會覆蓋 `acuteRx`（例如 "calcified nodule" 永遠是 chronic，即使 "nodule" 是 acute）
- AHK v2 中每個函式需要單獨宣告 `global` 變數
- DPI 定位使用 `A_ScreenDPI / 96` 將物理像素轉換為邏輯座標
