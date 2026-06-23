FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libglib2.0-0 libnss3 \
    && pip install --no-cache-dir flask gunicorn \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /app/temp /app/static

WORKDIR /app
COPY . .

ENV WORKERS=2
ENV THREADS=4
ENV MALLOC_ARENA_MAX=2
ENV PYTHONUNBUFFERED=1
EXPOSE 5000
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/')" || exit 1
CMD ["sh", "-c", "gunicorn -w ${WORKERS} --threads ${THREADS} -b 0.0.0.0:5000 --timeout 60 --max-requests 500 --max-requests-jitter 50 main:app"]
