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

### 15. Brain CT infarct → Impression
- **位置**: `GenerateImpression` `acuteRx` (~line 3421)
- **問題**: "subacute infarct in the left MCA territory" 不出現在 impression（`acuteRx` 缺少 infarct）
- **修正**: 新增 `|infarct` 到 `acuteRx`

### 16. Suspect 不再被改寫為 "X, suspected."
- **位置**: `GenerateImpression` (~line 3462)、`_IMP_ExtractDDxClause` (~line 3042)
- **問題**: 兩條路徑會改寫 Suspect 句子：(1) GenerateImpression 直接轉換 "Suspect X" → "X, suspected."；(2) _IMP_ExtractDDxClause 把 Suspect 當作 DDx clause 提取移到尾部
- **修正**: (1) 移除 Suspect → X, suspected 轉換（只保留 Consider/Suggest 改寫）；(2) 從 _IMP_ExtractDDxClause 的 clause 提取模式中移除 "Suspect"

### 17. Se/Im 括號保留 + Size 提取修正
- **位置**: `FilterBullet_ChestCT` (~line 1423)、`Impression_SummaryOnly` (~line 3052)、`_IMP_ExtractFirstSize` (~line 3011)
- **問題**: "Small subpleural nodules at RML and BLL. (0.3-0.5cm, Se/Im: 5/75)" — BLL 後的句號被當作 sentence boundary，括號被切斷；Size 提取在 Se/Im 剝離之後執行，數值已被移除
- **修正**:
  - FilterBullet：新增句號後接 Se/Im 括號時的跳過規則
  - Impression_SummaryOnly：將 `_IMP_ExtractFirstSize` 移到 `_IMP_StripSeImAndRefs` 之前
  - _IMP_ExtractFirstSize：支援 size range 格式（如 "0.3-0.5cm"）

### 18. Impression 順序保留原始 bullet 順序
- **位置**: `GenerateImpression` (~line 3596)、`BuildImpressionFromList` (~line 3086, 3199-3239)
- **問題**: Impression 項目不按照原始 report 順序
- **修正**:
  - 移除 `GenerateImpression` 中的 clinical relevance 排序
  - `BuildImpressionFromList` 新增 `bulletsText` 參數，合併後依據 keyword 在原始 bullets 中的位置做 bubble sort 重排

### 19. Fatty liver → chronic（不放 Impression）
- **位置**: `GenerateImpression` `definitelyChronicRx` (~line 3404)、`GenerateImpression_LungNoPrior` `_chronicExcludeRx` (~line 3292)
- **修正**: 新增 `fatty liver|hepatic steatosis|steatosis` 到 chronic 模式

### 20. RIS 貼上時 Clinical Information 後缺少空行
- **位置**: `EnsureBlankLineAfterClinicalInfo` (~line 1188)
- **問題**: regex 預期 study header 以 `:` 結尾，但 `BuildStudyHeader` 產生的 header 以 `.` 結尾
- **修正**: 將 regex `[^\r\n]*:` 改為 `[^\r\n]*[.:]`

### 21. Osteoporosis / osteopenia → chronic（不放 Impression）
- **位置**: `GenerateImpression` `definitelyChronicRx` (~line 3403)、`GenerateImpression_LungNoPrior` `_chronicExcludeRx` (~line 3293)
- **修正**: 新增 `osteoporos|osteopenia` 到 chronic 模式

### 22. Compression fracture 路由 + vertebroplasty chronic
- **位置**: `ExtractLocation_ChestCT` (~line 1689)、`HeuristicRoutes_ChestCT` (~line 1790)、`InferSectionFromText` (~line 4426)、`_SectionHitCount_ChestCT` (~line 4640)、`AutoDetectSection` (~line 4866)、`GenerateImpression` `definitelyChronicRx` (~line 3405)、`GenerateImpression_LungNoPrior` `_chronicExcludeRx` (~line 3294)
- **問題**: Chest CT compression fracture 沒有出現在 findings；有做過 vertebroplasty 的 compression fracture 應視為 chronic
- **修正**:
  - 路由（共 5 處）：新增 `vertebroplasty|kyphoplasty` 到 spine/osseous 偵測模式；`HeuristicRoutes_ChestCT` Layer 3 新增 `\bfracture\b|vertebroplasty|kyphoplasty` safety net
  - Chronic（共 2 處）：新增 `vertebroplasty|kyphoplasty` 到 `definitelyChronicRx` 和 `_chronicExcludeRx`

### 23. Ground glass opacity near hilum → Lung section（非 Mediastinum）
- **位置**: `ExtractLocation_ChestCT` Priority 0 (~line 1567)、`InferSectionFromText` Priority 0 (~line 4357)
- **問題**: "Mild ground glass opacity near left pulmonary hilum" 因 `\bhilum\b` 匹配 mediastinum 模式而錯誤路由到 Mediastinum（lung pattern 需要 `\blung\b` 或 `pulmonary\s+parenchyma` 但文中只有 "pulmonary hilum"）
- **修正**: 新增 Priority 0 compound override — 當句子同時含有肺實質 finding 模式（`ground.?glass|opaci|consolidat|atelectas|infiltrat|pneumoni|fibrosis|fibrot`）和 hilar/hilum 時（且不含 lymph/adenopathy），路由到 Lung

### 24. Acute override：strong acute 覆蓋 definitelyChronicRx
- **位置**: `GenerateImpression` (~line 3494-3504)、`GenerateImpression_LungNoPrior` (~line 3320-3328)
- **問題**: `definitelyChronicRx` 完全覆蓋 `acuteRx`，導致含有 strong acute 指標的句子被錯誤分類為 chronic：
  - "New cardiomegaly" — `cardiomegal` 匹配 chronic，`new ` 被忽略
  - "Cholelithiasis with cholecystitis" — `cholelithiasis` 匹配 chronic，cholecystitis 被壓制
  - "Breast nodule, suspect malignancy" — `breast.{0,10}nodule` 匹配 chronic，malignancy 被忽略
- **修正**: 新增 `acuteOverrideRx` 模式，當 `definitelyChronicRx` 和 `acuteRx` 同時匹配時，若句子含有 strong acute 指標則 acute 優先：
  - 時序/變化：`\bnew\s|\bincreas|\benlarg|\bworsen|\bprogress`
  - 惡性腫瘤：`\bcanc|\bcarcinom|\bmalignan|\bneoplasm|\bmetasta`
  - 急性疾病：`cholecystitis|appendicitis`
  - 明確急性：`\bacute\b`
- **保留不變**: 弱 acute 模式（如 `nodule` 單獨出現）仍被 chronic 覆蓋（如 "calcified nodule" 仍為 chronic）

### 25. AbdomenCT: Hepatic duct → Biliary（非 Liver）
- **位置**: `HeuristicRoutes_AbdomenCT` Priority 0 (~line 2593)
- **問題**: "Dilated hepatic duct" / "Intrahepatic duct dilatation" — `hepatic` 匹配 Liver 模式（step 1），biliary 模式（step 2）永遠不會被執行
- **修正**: 在 HeuristicRoutes_AbdomenCT 開頭新增 Priority 0 compound override，模式 `(hepatic|intrahepatic|intra.hepatic)\s+(bile\s+)?duct|\bihd\b|\bihds\b|common\s+hepatic\s+duct|biliary\s+dil|duct\s+dil` → "Biliary system:"

### 26. AbdomenCT: Mesenteric artery/vein → Vessels（非 GI）
- **位置**: `HeuristicRoutes_AbdomenCT` Priority 0 (~line 2600)
- **問題**: "SMA stenosis" / "Mesenteric artery thrombosis" — `mesenteric` 匹配 GI 模式（step 7），Vessels 模式（step 8）永遠不會被執行
- **修正**: 在 HeuristicRoutes_AbdomenCT Priority 0 新增 override，模式 `mesenteric\s+(arter|vein)|mesenteric.{0,20}(thrombo|stenosis|aneurysm|occlus|dissect|embol)|\bsma\b|\bsmv\b|\bima\b|\bimv\b` → "Vessels and lymph nodes:"

### 27. ChestCT: Hepatic duct → Biliary（非 Liver）— 同步 #25
- **位置**: `ExtractLocation_ChestCT` Priority 0 (~line 1586)、`HeuristicRoutes_ChestCT` Layer 3 (~line 1779)、`InferSectionFromText` Priority 0 (~line 4406)（共 3 處）
- **問題**: 與 #25 相同的衝突存在於 Chest CT 管線 — `\bhepatic\b`（ExtractLocation）、`\bhepat`（HeuristicRoutes Layer 3）、`liver|hepatic`（InferSectionFromText）都會在 biliary 模式之前先匹配 "hepatic duct"
- **修正**: 三個函式各新增 Priority 0 / early override，使用與 #25 相同的 biliary duct 模式，確保 hepatic duct 句子路由到 Biliary section

### 28. Esophageal finding → Mediastinum（InferSectionFromText 一致性修正）
- **位置**: `InferSectionFromText` (~line 4455)
- **問題**: `ExtractLocation_ChestCT` 路由 esophag → "mediastinum"，`HeuristicRoutes_ChestCT` 路由 esophag → "Mediastinum"，但 `InferSectionFromText` 路由 esophag → "Others:" — 不一致
- **修正**: 將 `InferSectionFromText` 中的 esophag 從 GI "Others:" 群組拆出，獨立路由到 "Mediastinum and lymph nodes:"（食道解剖位置在 mediastinum 中），此函式僅在 Chest CT 上下文使用

### 29. Pleural effusion + pericardial effusion compound 分割
- **位置**: `SplitAndConjunction_ChestCT` (~line 3786)
- **問題**: "Bilateral pleural effusion and pericardial effusion" — Priority 0 `\bpleural\s+effusion` 攔截整句 → 全部路由到 Pleura，pericardial effusion 遺失
- **修正**: 在 `SplitAndConjunction_ChestCT` 開頭新增 pleural+pericardial effusion 分割模式（雙向）；分割後各片段獨立路由，pleural → Pleura，pericardial → Heart and vessels

### 30. `acuteOverrideRx` 新增 `\bsuspic`（suspicious 覆蓋 chronic）
- **位置**: `GenerateImpression` `_acuteOverrideRx` (~line 3529)、`GenerateImpression_LungNoPrior` `_acuteOverrideRx2` (~line 3351)
- **問題**: "Suspicious thyroid nodule" — `thyroid` 匹配 `definitelyChronicRx`，但 "suspicious" 不在 `acuteOverrideRx` 中，無法逆轉 chronic 分類
- **修正**: 新增 `|\bsuspic` 到兩個 `acuteOverrideRx` 模式，使 "suspicious" 成為 strong acute 指標

### 31. FilterBullet 移除 diagnostic interpretation 截斷關鍵字
- **位置**: `FilterBullet_ChestCT` detection regex (~line 1409) 和 keyword list (~line 1449)
- **問題**: "compatible with"、"consistent with"、"suggestive of"、"concerning for" 被作為截斷關鍵字，導致 FINDINGS 過度截斷：
  - "Lesion compatible with hemangioma" → 截斷為 "Lesion"（太短）
  - "Ground glass opacity suggestive of infection" → 截斷為 "Ground glass opacity"（遺失特徵描述）
- **修正**: 從 detection regex 和 keyword list 中移除這 4 個 diagnostic interpretation 關鍵字。它們是影像特徵的描述性詞彙（屬於 finding），不是處置指令（recommend/follow-up）。Impression capture 使用 `rawSentence`（截斷前），不受影響
- **保留截斷**: DDx 標記（`ddx:`）、管理指令（`recommend`、`suggest`、`advise`、`follow-up`、`correlation`、`further evaluation`、`sonography`）、弱推測（`suspect`、`likely`、`probably`、`possible`、`may represent`、`could represent`）

### 32. Suspect-lead 句子被錯誤跳過（不放在 Finding 也不放在 Impression）
- **位置**: Chest CT impression capture (~line 4049)、non-Chest-CT impression capture (~line 4268)、`BuildImpressionFromList` bubble sort (~line 3254)
- **問題**: "Suspect chronic pancreatitis" / "Suspect centrilobular emphysema" — `_preSug=""` → `_isPureSuggest=true`，但 `_isSuspectLead=true` → 兩個 impression push block 都不執行 → `_isPureSuggest → continue` 跳過 findings bucket
- **根因**: `_isPureSuggest` 判斷沒有排除 `_isSuspectLead`。"Suspect X" 是帶有不確定性的 finding，不是「純推薦」
- **修正**:
  - 兩個 `_isPureSuggest` 檢查改為 `_isPureSuggest && !_isSuspectLead`
  - 新增第三個 impression push block：`_isSuspectLead` 時推送完整句子到 impression
  - `BuildImpressionFromList` bubble sort：新增 leading "Suspect(ed)" 預先剝離，避免 regex 把整句清空導致 pos=999999

### 33. Axillary → Osseous（`\baxillar\b` word boundary 修正）
- **位置**: `ExtractLocation_ChestCT` (~line 1688)、`HeuristicRoutes_ChestCT` Layer 3 (~line 1776)
- **問題**: `\baxillar\b` 的 trailing `\b` 要求 "r" 後面是 word boundary，但 "axillary" 的 "r" 後面是 "y"（word character）→ 不匹配 → "No axillary metastatic lymphadenopathy" 跳過 chest_wall 模式 → `lymphadenopathy` 匹配 Mediastinum
- **修正**: `\baxillar\b` → `\baxillar`（移除 trailing `\b`，同時匹配 "axillar" 和 "axillary"）

### 34. Impression 排序改用 per-line keyword overlap score
- **位置**: `BuildImpressionFromList` bubble sort (~line 3243-3290)
- **問題**: 原本的 single-keyword 匹配（找 bulletsText 中最早出現的 keyword position）容易 cross-contaminate — 例如 "bilateral" 出現在 bullet 1 但 impression 項目來自 bullet 3
- **修正**: 改為 per-line scoring：
  - 將 bulletsText 分割為各行，記錄每行的累積位置
  - 對每個 impression 項目提取 key words（>4 chars）
  - 對每個 bullet line 計算 keyword overlap score（匹配幾個 key words）
  - 選擇 score 最高的 bullet line 的位置作為排序依據
  - 比 single-keyword 更穩健，因為需要多個 keyword 同時匹配才能確定來源

### 35. InferSectionFromText：bone/soft tissue/breast override 移到 Lung 前
- **位置**: `InferSectionFromText` (~line 4515)
- **問題**: Lung block 的 `nodule|mass|lesion|cyst` 是 bare generic terms，會攔截非肺部 findings：
  - "Breast mass" → `mass` 匹配 Lung → 錯誤（應為 Osseous）
  - "Rib mass" → `mass` 匹配 Lung → 錯誤（應為 Osseous）
  - "Soft tissue nodule" → `nodule` 匹配 Lung → 錯誤（應為 Osseous）
  - 現有 organ overrides（kidney、liver、spleen、thyroid）在 Lung 之前，但 bone/soft tissue 沒有
- **修正**: 在 Lung block 之前新增 bone/soft tissue/breast/chest wall override，使用完整的 osseous 模式：`\bbreast\b|\baxillar|\baxilla\b|\bintramammar|\bmammary\b|\bchest\s*wall|\bbone\b|\bosseous\b|\bspine\b|\bvertebra|\brib\b|\bribs\b|\bfracture|\bscoliosis|\bkyphosis|\bspondyl|\bdegenerative|\bsoft\s*tissue|\bvertebroplas|\bkyphoplas|\bsubcutan`
- **設計原則**: lesion+location routing — 以解剖位置決定 section，非 lesion type

### 36. _SectionHitCount_ChestCT：lungHit 移除 bare generic terms
- **位置**: `_SectionHitCount_ChestCT` (~line 4759)
- **問題**: `lungHit` 包含 `nodule|mass|lesion|cyst|tumour|cancer|carcinoma|neoplasm` 等 bare generic terms，導致非肺部 findings 被計為 lung hit：
  - "Hepatic cyst and pleural effusion" → lungHit=1（false，from `cyst`）+ pleHit=1 → cnt=2（結果正確但原因錯誤）
  - "Breast mass" → lungHit=1（false）+ boneHit=1 → cnt=2（應為 1，可能導致不必要的 splitting）
- **修正**: 移除 bare generic terms（`nodule|mass|lesion|cyst|tumour|cancer|carcinoma|neoplasm`），新增 lung-specific terms（`\blung\b|bronchiectasis`），保留所有 lung-specific 影像模式（GGO、consolidation、opacity、atelectasis 等）和肺葉定位詞
- **設計原則**: hit count 只計算 lung-SPECIFIC terms 或 lung LOCATION terms，generic lesion terms 需要明確的 lung context

### 37. Portal venous gas → Liver（非 Osseous/GI）
- **位置**: `ExtractLocation_ChestCT` Priority 0 (~line 1593)、`HeuristicRoutes_ChestCT` Layer 3、`InferSectionFromText`（共 3 處）+ 移除 GI 中的 `portal\s+gas`
- **問題**: "Portal veinous gas" / "Portal venous gas" — `portal\s+gas` 模式不匹配中間有形容詞（venous/veinous）的寫法 → fallback 到 Osseous
- **修正**: 新增 `portal\s+(venous|veinous|vein)\s+(gas|air)|portal\s+gas` Priority 0 override → liver/Liver；從 GI 模式中移除 `portal\s+gas` 避免衝突

### 38. Perinephric → Kidneys、Subcutaneous → Osseous（infiltrat 覆蓋修正）
- **位置**: `ExtractLocation_ChestCT` kidney/chest_wall 模式、`HeuristicRoutes_ChestCT` Layer 3（Lung 前新增兩個 override）、`InferSectionFromText` kidney override（共 5 處）
- **問題**:
  - "Increased infiltration in the bilateral perinephric regions" → Lung 的 `infiltrat` 先匹配 → 錯誤路由到 Lung（應為 Kidneys）
  - `\bnephr` 的 word boundary 不匹配 "perinephric"（compound word 內無 boundary）
  - "Suspect increased subcutaneous and muscular infiltration" → 同樣被 Lung 的 `infiltrat` 攔截
- **修正**:
  - ExtractLocation kidney 模式：新增 `perinephric|perirenal`
  - ExtractLocation chest_wall 模式：新增 `\bsubcutan|\bmuscular\s+infilt|\babdominal\s+wall`
  - HeuristicRoutes Layer 3：在 Lung 的 `infiltrat` 模式之前新增 perinephric→Kidneys 和 subcutaneous→Osseous override
  - InferSectionFromText kidney override：新增 `perinephric|perirenal`

### 39. "Please correlate..." 不獨立拆分為 Impression 項目 + "further. follow-up." 修正
- **位置**: Router impression capture（Chest CT ~line 4129、non-Chest-CT ~line 4352）、`BuildImpressionFromList` `_pureRecommendRx` (~line 3208)、`_IMP_IsNonFindingSentence` (~line 3069)、`_IMP_ExtractDDxClause` (~line 3107)（共 5 處）
- **問題**: "Please correlate with clinical condition and further follow-up." 被獨立推送到 impression 且文字變形為 "further. follow-up."
  - Router impression capture: `_sugMatch` 匹配 "Follow-up"，`_preSug`（"Please correlate..."前面文字）長度 > 8 → `_isPureSuggest=false` → 全句推送到 impList
  - `BuildImpressionFromList` `_pureRecommendRx` 不含 "please" → 無法過濾
  - `_IMP_ExtractDDxClause` 將 "Follow-up" 從 "further follow-up" 中提取為 DDx clause → core "...further." + ddx "follow-up." → 重組為 "further. follow-up."
- **修正**:
  - Router impression capture（兩處）：新增 `^\s*please\b` 檢查 → `continue`，跳過 impression push 和 findings bucket
  - `BuildImpressionFromList`：`_pureRecommendRx` 新增 "please"（安全網）
  - `_IMP_IsNonFindingSentence`：新增 "please"（安全網）
  - `_IMP_ExtractDDxClause`：當匹配到 "Follow-up" 且前面是 "further/and/for" 時，判定為 compound phrase → 不提取，避免 "further. follow-up." 變形
- **設計考量**: "Suggest" 故意不加入 `_pureRecommendRx`，因 Fix #5 要求保留 "Suggest clinical correlation" 的 clinical intent

### 40. Compression fracture + vertebroplasty 跨句 chronic 判定
- **位置**: 新增 `_IsTreatedCompressionFracture` helper (~line 3225)、`GenerateImpression` isChronic 後 (~line 3727)、`GenerateImpression_LungNoPrior` (~line 3528)、`BuildImpressionFromList` filtering (~line 3380)（共 4 處）
- **問題**: "Suspect compression fracture at L1 vertebra." 和 "Status post vertebroplasty at L1." 分別出現在不同 bullet — `definitelyChronicRx` 只看單句，fracture 句沒有 "vertebroplasty" → 不被視為 chronic → 出現在 impression
- **修正**: 新增 `_IsTreatedCompressionFracture(text, bulletsText)` helper 函式：
  - 偵測句子是否含有 `compression\s+fracture`
  - 收集 bulletsText 中含有 `vertebroplast|kyphoplast` 的行
  - 從 fracture 句子提取椎體層級（如 `l1`、`t12`）
  - 與 vertebroplasty 行的層級做交叉比對
  - 相同層級 → return true（treated fracture → chronic）
- **呼叫位置**: `GenerateImpression`（isChronic 後覆蓋）、`GenerateImpression_LungNoPrior`（chronic 過濾後）、`BuildImpressionFromList`（IsAlwaysNonImpressionFinding 後）
- **設計原則**: 跨句邏輯 — fracture 是否 treated 需要參考其他 bullet 的 vertebroplasty 資訊，不能只看單句

### 41. JoinWrappedLines：Suggest/Recommend 接續行合併
- **位置**: `JoinWrappedLines` (~line 1297)
- **問題**: DDx 句子後的 "Suggest clinical correlation and follow-up." 被視為獨立 bullet（前一行以 `.` 結尾 → merge 停止），導致在 impression 中拆為兩個獨立項目
- **修正**: 在 `JoinWrappedLines` 的句號 merge-stop 邏輯中新增例外 — 當下一行以 `^(Suggest|Recommend|Advise|Please)\b` 開頭時，視為前句的 recommendation tail，繼續合併

### 42. Hepatic cyst + Adrenal nodule → IsAlwaysNonImpressionFinding（雙路徑 chronic）
- **位置**: `IsAlwaysNonImpressionFinding` (~line 3200)、`GenerateImpression` `definitelyChronicRx` (~line 3584)、`GenerateImpression_LungNoPrior` `_chronicExcludeRx` (~line 3443)
- **問題**:
  - "Suspect hepatic cyst in the S2-3 and S6." — `definitelyChronicRx` 已有 `hepatic cyst`，但 Suspect-lead 句子走 Router impList 路徑，繞過 `GenerateImpression` → 仍出現在 impression
  - Adrenal nodule 不在 `definitelyChronicRx` 中
- **修正**:
  - `IsAlwaysNonImpressionFinding` 新增：`\b(hepatic|liver|renal|kidney|splenic|simple)\s+cysts?\b` → true（除非 new/enlarg/complex/hemorrhag 等急性特徵）
  - `IsAlwaysNonImpressionFinding` 新增：`\badrenal\s+(nodule|adenoma|cyst|myelolipoma)` → true（除非 new/enlarg/suspic/malignan 等）
  - `definitelyChronicRx` 和 `_chronicExcludeRx` 新增 `adrenal\s+(nodule|adenoma|cyst|myelolipoma)`
- **設計重點**: `IsAlwaysNonImpressionFinding` 在 GenerateImpression 和 BuildImpressionFromList 兩條路徑都會被呼叫，確保 Suspect-lead 句子也被過濾

### 43. Brain CT significant findings → acuteRx（impression-worthy）
- **位置**: `GenerateImpression` `acuteRx` (~line 3652)
- **問題**: Brain CT 有 "Cerebral and cerebellar cortical atrophy with ventricular dilatation" 等顯著 finding，但 `acuteRx` 不含 `atrophy` → 不被視為 actionable → impression 只剩 "No interval change"
- **修正**: 新增 `|atrophy|ventriculomegal|ventricular dilat|hydrocephal|encephalomalac` 到 `acuteRx`

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
| `IsAlwaysNonImpressionFinding()` | 雙路徑 impression 排除（benign/CKD/cyst/cholelithiasis/fibrosis 等） |
| `_IsTreatedCompressionFracture()` | 跨句判定 compression fracture 是否已做 vertebroplasty |
| `JoinWrappedLines()` | 合併被分行的 bullet（Se/Im 括號、DDx、Suggest 接續行） |
| `GetNegativeWording()` | 產生 section 陰性描述（prior-aware） |
| `PrependClinicalInfo()` | 加上 Clinical Information 前綴 |
| `SplitAndConjunction_ChestCT()` | "X and Y" cross-section 分割 |
| `SplitWithMetastasis_ChestCT()` | "with X metastasis" 分割 |
| `SplitNegativeSentence_ChestCT()` | Negative compound sentence 分割 |
| `SplitSentences_ChestCT()` | 句子分割器 |

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
- `definitelyChronicRx` 會覆蓋 `acuteRx`（例如 "calcified nodule" 永遠是 chronic），但 `acuteOverrideRx` strong acute 指標可逆轉 chronic 分類（見 #24）
- AHK v2 中每個函式需要單獨宣告 `global` 變數
- DPI 定位使用 `A_ScreenDPI / 96` 將物理像素轉換為邏輯座標
- **Lesion+Location 路由原則**：section routing 應以「lesion 的解剖位置」決定，而非 lesion type 的 bare keyword。Generic terms（nodule、mass、lesion、cyst）需要搭配 organ/location context 才能決定 section。InferSectionFromText 和 _SectionHitCount_ChestCT 已依此原則修正（見 #35、#36）
- **Impression 雙路徑**：(1) Router `impList` → `BuildImpressionFromList`，(2) `GenerateImpression` rule-based。`definitelyChronicRx` 只在路徑 (2) 生效；`IsAlwaysNonImpressionFinding()` 在兩條路徑都生效。新增 chronic 規則時需考慮是否需要同時在兩處加入（見 #42）
- **跨句邏輯**：`_IsTreatedCompressionFracture` 是第一個跨句判定函式，需要 `bulletsText` 參數來參考其他 bullet 的資訊（見 #40）

## Git 版本控制

- **Local repo**: `C:\Users\2D\Desktop\Test\New_v1 folder`
- **Remote**: `https://github.com/stararrow1030-svg/gui.git`
- **Branch**: `main`
- **Git identity**: `stararrow1030-svg` / `stararrow1030-svg@users.noreply.github.com`（local config）
- **初始 commit**: `init: FindingAssistant v60 with fixes #1-#40`

### .gitignore
```
.claude/           # Claude Code local settings
golden_review_*.html  # Generated review files
```

### 日常工作流程
```bash
# 每次 Claude Code session 結束後
cd "C:\Users\2D\Desktop\Test\New_v1 folder"
git add -A
git commit -m "fix: 描述修改內容"
git push

# 另一台電腦開始前
git pull
```

### F: 磁碟同步
- 主要開發在 F:\Type tool-SD\New_v1 folder（PACS 電腦）
- C:\Users\2D\Desktop\Test\New_v1 folder 為 git repo + 同步副本
- 每次修改後需手動 `cp` 同步 F: → C:（或反向）
- F: 磁碟為外接/可卸除裝置，不一定隨時可用
