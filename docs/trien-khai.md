# Hướng dẫn cấu hình & triển khai Letta

## 1. Chuẩn bị
- Yêu cầu Python ≥ 3.11 nếu chạy trực tiếp, hoặc Docker/Compose khi tự host.
- Tạo tài khoản Letta Cloud để lấy `LETTA_API_KEY` hoặc chuẩn bị khóa mô hình (OpenAI, Anthropic, Groq, Gemini…) khi self-host.【F:README.md†L40-L119】

## 2. Biến môi trường quan trọng
Các biến được quản lý bởi `letta/settings.py`, gồm:
- Khóa mô hình: `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GROQ_API_KEY`, `AZURE_API_KEY`, `GEMINI_API_KEY`, `VLLM_API_BASE`, `OPENLLM_API_KEY`...【F:letta/settings.py†L101-L186】
- Sandbox & tool: `LETTA_TOOL_EXEC_DIR`, `LETTA_TOOL_SANDBOX_TIMEOUT`, `E2B_API_KEY` (qua `ToolSettings`).【F:letta/settings.py†L17-L49】
- Telemetry/CORS: `ACCEPTABLE_ORIGINS`, `LETTA_OTEL_EXPORTER_OTLP_ENDPOINT`, cấu hình profiler.【F:letta/server/rest_api/app.py†L84-L189】【F:letta/settings.py†L188-L200】

Đặt biến trong file `.env` để Compose và ứng dụng đọc tự động.【F:compose.yaml†L32-L52】

## 3. Triển khai nhanh với Docker Compose
1. Sao chép repo và tạo thư mục `.persist` để lưu dữ liệu Postgres.
2. Cập nhật `.env` với khóa mô hình và biến `LETTA_PG_URI` nếu cần.
3. Chạy `docker compose up` để khởi động Postgres (pgvector) và Letta server, map port 8283/8083 cho API/UI.【F:compose.yaml†L1-L65】
4. Tuỳ chọn gắn cấu hình cá nhân (`configs/server_config.yaml`) hoặc thư mục thực thi tool bằng biến `LETTA_SANDBOX_MOUNT_PATH`.【F:compose.yaml†L53-L58】

Sau khi chạy, dùng SDK Python/TS trỏ `base_url` tới `http://localhost:8283` để kiểm tra agent theo ví dụ trong README.【F:README.md†L43-L125】

## 4. Môi trường phát triển
- Sử dụng `development.compose.yml` để build image từ Dockerfile mục tiêu `development`, mount source code và test để hot-reload.【F:development.compose.yml†L1-L28】
- Cấu hình volume `~/.letta/credentials` và `configs/server_config.yaml` giúp chia sẻ secret, override config trong container dev.【F:development.compose.yml†L18-L26】
- Bật `WATCHFILES_FORCE_POLLING=true` để refresh code trong môi trường container.【F:development.compose.yml†L15-L16】

## 5. Triển khai thủ công (tùy chọn)
1. Tạo database Postgres với extension `pgvector` (xem `init.sql`).
2. Cài đặt dependencies bằng `pip install -e .` trong repo.
3. Xuất các biến môi trường cần thiết (LLM keys, `LETTA_PG_URI`, `LETTA_DEBUG`).【F:letta/settings.py†L95-L186】
4. Chạy server FastAPI: `uvicorn letta.server.rest_api.app:create_application --factory --host 0.0.0.0 --port 8283`.
5. Kiểm tra health bằng cách gọi `/v1/agents` hoặc sử dụng SDK.

## 6. Theo dõi & vận hành
- Scheduler và telemetry được khởi động trong giai đoạn lifespan, nên cần đảm bảo quyền truy cập tới hệ thống hàng đợi/ClickHouse/Pinecone nếu bật.【F:letta/server/rest_api/app.py†L122-L189】【F:compose.yaml†L48-L52】
- Để thu thập log tool execution, mount thư mục sandbox và theo dõi stdout/stderr trong log container.【F:letta/services/tool_executor/tool_execution_sandbox.py†L99-L107】【F:compose.yaml†L53-L58】
- Điều chỉnh ngưỡng summarizer bằng biến `LETTA_SUMMARIZER_*` (đọc trong `SummarizerSettings`).【F:letta/settings.py†L52-L90】

## 7. Kiểm thử nhanh sau triển khai
- Chạy script Python/TypeScript Hello World để tạo agent và gửi tin nhắn.【F:README.md†L43-L125】
- Gửi request batch tới `/v1/messages/batches` để xác nhận job worker hoạt động.【F:letta/server/rest_api/routers/v1/messages.py†L21-L171】
- Kiểm tra `/openapi_letta.json` sinh tự động khi server khởi động để xem tài liệu API.【F:letta/server/rest_api/app.py†L84-L110】
