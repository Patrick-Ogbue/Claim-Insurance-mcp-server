# Claim Pilot MCP Server — private deps via PAT (aims-api style).
# Installs claim-pilot-core from a shallow clone + pyproject patch so legacy
# claim-pilot/claim-pilot-logging@main pins on GitHub still resolve to INSURANCE-AGENTS-PLATFORM@master.

FROM python:3.11-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*

ARG GITHUB_TOKEN
RUN test -n "$GITHUB_TOKEN" || ( \
      echo "GITHUB_TOKEN build-arg is required." && exit 1 )
RUN case "$GITHUB_TOKEN" in ho_*) \
      echo "GITHUB_TOKEN starts with ho_ — did you mean gho_? Fix .env." && exit 1 ;; \
    esac
RUN git config --global url."https://x-access-token:${GITHUB_TOKEN}@github.com/".insteadOf "https://github.com/"

ENV GIT_TERMINAL_PROMPT=0

WORKDIR /deps
RUN git clone --depth 1 -b master https://github.com/INSURANCE-AGENTS-PLATFORM/claim-pilot-core.git claim-pilot-core \
    && sed -i 's|github.com/claim-pilot/claim-pilot-logging|github.com/INSURANCE-AGENTS-PLATFORM/claim-pilot-logging|g' claim-pilot-core/pyproject.toml \
    && sed -i 's|claim-pilot-logging.git@main|claim-pilot-logging.git@master|g' claim-pilot-core/pyproject.toml

RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir /deps/claim-pilot-core

WORKDIR /build
COPY pyproject.toml README.md ./
COPY src/ src/

RUN sed -i 's|claim-pilot-core @ git+https://github.com/INSURANCE-AGENTS-PLATFORM/claim-pilot-core.git@master|claim-pilot-core @ file:///deps/claim-pilot-core|g' pyproject.toml \
    && sed -i 's|claim-pilot-core @ git+https://github.com/INSURANCE-AGENTS-PLATFORM/claim-pilot-core.git@main|claim-pilot-core @ file:///deps/claim-pilot-core|g' pyproject.toml \
    && pip install --no-cache-dir .

FROM python:3.11-slim

WORKDIR /app

COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

EXPOSE 8001

CMD ["uvicorn", "claim_pilot_mcp_server.http_api:app", "--host", "0.0.0.0", "--port", "8001"]
