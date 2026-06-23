FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libglib2.0-0 libnss3 \
    && pip install --no-cache-dir flask gunicorn \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /app/temp /app/static

WORKDIR /app
COPY . .

ENV WORKERS=4
EXPOSE 5000
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/')" || exit 1
CMD ["sh", "-c", "gunicorn -w ${WORKERS} -b 0.0.0.0:5000 --timeout 60 main:app"]
