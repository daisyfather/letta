# Logic lõi & hành vi API của Letta

## Tổng quan
Letta tập trung vào việc duy trì trạng thái hội thoại dài hạn với quản lý bộ nhớ phân cấp. Logic lõi xoay quanh vòng lặp agent, các dịch vụ memory, công cụ và cơ chế API đồng bộ/bất đồng bộ.

## Vòng lặp Agent & quản lý trạng thái
- Hàm `Agent.step` nhận danh sách `MessageCreate`, chuyển đổi sang `Message`, sau đó lặp để gọi `inner_step`, xử lý chaining, heartbeat và cảnh báo bộ nhớ.【F:letta/agent.py†L753-L834】
- Mỗi lượt gọi sẽ ghi nhận usage, log step, lưu thông điệp mới vào kho lưu trữ qua `AgentManager`, `MessageManager`, đồng thời phát tín hiệu cho job manager khi chạy trong batch/job.【F:letta/agent.py†L979-L1013】
- Khi phát hiện overflow hoặc lỗi context, agent kích hoạt summarizer để tạo thông điệp tóm tắt ở index 1 và tái cấu trúc bộ nhớ hội thoại.【F:letta/agent.py†L945-L1040】

## Hệ thống bộ nhớ tiên tiến
- `Memory` định nghĩa core memory gồm nhiều block có metadata (nhãn, mô tả, giới hạn ký tự, read-only) và hỗ trợ block dạng file – cho phép agent truy cập tài liệu lớn theo chế độ mở file động.【F:letta/schemas/memory.py†L31-L118】
- `ContextWindowCalculator` tách hệ thống prompt thành phần: base instructions, memory blocks, metadata, summary memory. Nó đếm token song song để biết phần nào đang chiếm context nhằm ra quyết định summarize hoặc gửi cảnh báo.【F:letta/services/context_window_calculator/context_window_calculator.py†L19-L193】
- `Summarizer` hỗ trợ chế độ Partial Evict: xác định phạm vi thông điệp cần tóm tắt, gọi LLM tạo summary và chèn lại vào lịch sử để giữ bối cảnh quan trọng.【F:letta/services/summarizer/summarizer.py†L27-L199】

## Logic tool & sandbox
- Agent áp dụng `ToolRulesSolver` để quyết định gọi tool nào và có cần heartbeat tiếp theo hay không, đảm bảo tuần tự an toàn cho các hành động multi-step.【F:letta/agent.py†L736-L748】
- `ToolExecutionSandbox` tạo môi trường cô lập (local hoặc E2B) cho tool, quản lý biến môi trường, venv, cài dependency và thu gom stdout/stderr.【F:letta/services/tool_executor/tool_execution_sandbox.py†L37-L200】 Điều này giảm rủi ro khi cho phép agent thực thi mã.

## API logic nổi bật
- Router `/agents` cung cấp CRUD, export/import, gửi tin nhắn, quản lý block, tool, file. Tất cả request đều lấy `SyncServer`, tải actor và ủy quyền cho service manager tương ứng, giữ consistent logic giữa REST và các client khác.【F:letta/server/rest_api/routers/v1/agents.py†L69-L200】
- Router `/messages` xử lý batch run: kiểm tra kích thước payload, tạo job async, fan-out tới nhiều agent bằng `LettaAgentBatch`, và cung cấp API polling kết quả.【F:letta/server/rest_api/routers/v1/messages.py†L21-L190】
- Lifespan của FastAPI khởi động job scheduler, kết nối Pinecone khi cần và đăng ký telemetry/trace, đảm bảo các tác vụ nền (như summarize async, batch) hoạt động ổn định.【F:letta/server/rest_api/app.py†L122-L189】

## Điểm khác biệt về quản lý bộ nhớ
- Letta duy trì core memory như cấu trúc XML dạng block nên LLM có thể tự đọc/ghi từng phần thay vì chuỗi đơn, giảm lỗi ghi đè và giúp tool sửa block cụ thể.【F:letta/schemas/memory.py†L63-L118】
- Cơ chế summary được kích hoạt tự động dựa trên ngưỡng token và tái chèn summary message kèm metadata thời gian, giúp agent giữ được “trí nhớ dài hạn” mà vẫn tiết kiệm context.【F:letta/agent.py†L945-L1019】【F:letta/services/summarizer/summarizer.py†L114-L199】
- ContextWindowCalculator phân tách token cho system prompt, memory, summary, tin nhắn và định nghĩa tool schema. Việc này giúp công cụ giám sát chi tiết, minh bạch hóa “context budget” – khác biệt so với các framework chỉ đếm token tổng quát.【F:letta/services/context_window_calculator/context_window_calculator.py†L131-L193】
