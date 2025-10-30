# Tổng quan kiến trúc Letta

## Mục đích
Tài liệu này mô tả kiến trúc tổng quan của Letta – nền tảng xây dựng agent có trạng thái với hệ thống bộ nhớ phân cấp. Kiến trúc được thiết kế để hỗ trợ triển khai đa môi trường (cloud, self-hosted) và mở rộng qua SDK Python/TypeScript.

## Các lớp thành phần chính

### 1. Lớp biên API & giao thức
Letta cung cấp REST API và WebSocket/stream dựa trên FastAPI. Ứng dụng khởi tạo trong `letta/server/rest_api/app.py` với FastAPI và cấu hình lifespan để chuẩn bị server đồng bộ, job scheduler, CORS và giám sát.【F:letta/server/rest_api/app.py†L12-L189】 Tầng này gắn các router `/v1` cho agent, message, tool… giúp client SDK và ADE giao tiếp thống nhất.【F:letta/server/rest_api/routers/v1/agents.py†L69-L200】【F:letta/server/rest_api/routers/v1/messages.py†L16-L171】

### 2. Lớp điều phối server đồng bộ
`SyncServer` trong `letta/server/server.py` giữ trạng thái hệ thống chạy agent, khởi tạo các manager truy cập dữ liệu (agent, message, block, tool, job…), cấu hình kết nối cơ sở dữ liệu và HTTP client dùng chung.【F:letta/server/server.py†L117-L200】 Server cũng duy trì cache cấu hình mô hình và client MCP để hỗ trợ tool bên ngoài.【F:letta/server/server.py†L192-L199】

### 3. Lớp dịch vụ nghiệp vụ (Service Managers)
Các service manager (ví dụ `AgentManager`, `MessageManager`, `ToolManager`) chịu trách nhiệm giao tiếp ORM, tính toán context window, quản lý nguồn dữ liệu, công cụ và telemetry.【F:letta/services/agent_manager.py†L1-L200】 Các manager được `SyncServer` và Agent runtime sử dụng lại để đảm bảo logic thống nhất giữa API, job scheduler và batch runner.【F:letta/agent.py†L142-L148】

### 4. Lớp Agent Runtime
`Agent` trong `letta/agent.py` hiện thực vòng lặp suy luận của agent, tương tác với LLM, dịch vụ bộ nhớ, quản lý tool rules và xử lý chain/heartbeat để duy trì hội thoại dài hạn.【F:letta/agent.py†L96-L834】 Lớp này kết nối tới interface streaming (CLI/REST), managers và telemetry nhằm duy trì trạng thái agent, ghi log bước và áp dụng cảnh báo bộ nhớ.【F:letta/agent.py†L768-L1019】

### 5. Lớp bộ nhớ và ngữ cảnh
Bộ nhớ trong bối cảnh (core memory) được biểu diễn bằng `Memory` (các block có nhãn, giới hạn, thuộc tính read-only, file).【F:letta/schemas/memory.py†L31-L124】 Dịch vụ `ContextWindowCalculator` tính toán phân bổ token giữa system prompt, memory, summary và message, giúp agent tự điều chỉnh lượng thông tin trong context.【F:letta/services/context_window_calculator/context_window_calculator.py†L19-L193】

### 6. Lớp công cụ và sandbox
Công cụ được thực thi thông qua `ToolExecutionSandbox`, hỗ trợ sandbox cục bộ hoặc dịch vụ E2B/Modal với cơ chế tạo môi trường, cài đặt dependency và log output an toàn.【F:letta/services/tool_executor/tool_execution_sandbox.py†L37-L200】 Điều này giúp agent mở rộng khả năng hành động nhưng vẫn kiểm soát rủi ro bảo mật.

## Luồng hoạt động tổng quát
1. Client gửi yêu cầu (REST hoặc streaming). Router xác thực, lấy `SyncServer` và actor.【F:letta/server/rest_api/routers/v1/agents.py†L82-L159】
2. `SyncServer` sử dụng các manager truy xuất trạng thái agent/memory, chuẩn bị cấu hình LLM, tool, sandbox.【F:letta/server/server.py†L151-L199】
3. `Agent.step` chuyển đổi message, gọi LLM qua `LLMClient`, nhận phản hồi (bao gồm tool call) và ghi nhận usage.【F:letta/agent.py†L753-L1019】
4. Nếu vượt ngưỡng context hoặc cần tổng hợp, Agent kích hoạt summarizer/ContextWindowCalculator để tái cấu hình bộ nhớ.【F:letta/agent.py†L945-L1040】【F:letta/services/context_window_calculator/context_window_calculator.py†L63-L193】
5. Message, tool execution và telemetry được ghi qua các manager, trả kết quả về API/streaming.【F:letta/agent.py†L979-L1019】

## Đặc điểm kiến trúc nổi bật
- **Stateful Agents**: mỗi agent có lịch sử vĩnh viễn, bộ nhớ phân cấp (core, summary, recall/archival) được quản lý bởi services chung.【F:letta/schemas/memory.py†L31-L118】【F:letta/services/context_window_calculator/context_window_calculator.py†L131-L193】
- **Khả năng mở rộng multi-agent**: Shared memory blocks và group manager cho phép nhiều agent cùng truy cập nguồn kiến thức chung, kết hợp batch/loop engine trong routers v1.【F:letta/server/rest_api/routers/v1/agents.py†L181-L200】【F:letta/server/rest_api/routers/v1/messages.py†L21-L171】
- **Tooling & Integration**: sandbox hóa tool, hỗ trợ MCP, batch job, telemetry OTEL giúp tích hợp hệ sinh thái phong phú mà vẫn đảm bảo an toàn và quan sát được.【F:letta/services/tool_executor/tool_execution_sandbox.py†L50-L200】【F:letta/server/server.py†L192-L199】
