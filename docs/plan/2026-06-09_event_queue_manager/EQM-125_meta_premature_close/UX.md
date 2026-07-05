# EQM-125 UX — premature close
user goal: 迎撃系スキルが「相手の進行を残りだけ止める」を、メタレベル宣言 (int 1 個) と標準 API 1 呼び出しで実現し、回避された場合も trace で理由が読める。
## 採用/廃止 UX
- 採用: 介入の成立/回避が window_closed / 回避 trace で機械的に説明される。
- 廃止 (hack): ゲーム側での残 step 手動 cancel。
