FROM python:3.12-slim

RUN apt-get update && apt-get install -y \
    libglib2.0-0 \
    libnss3 \
    && rm -rf /var/lib/apt/lists/*

RUN pip install flask gunicorn

COPY wcocr.cpython-312-x86_64-linux-gnu.so /app/wcocr.cpython-312-x86_64-linux-gnu.so

COPY wx /app/wx

COPY main.py /app/main.py
COPY templates /app/templates

WORKDIR /app

# Each gunicorn worker calls wcocr.init() at import, spawning an independent
# wxocr subprocess (9 threads each). Tune WORKERS to your CPU count:
# roughly cores/2..cores/4 (each instance is multi-threaded internally).
ENV WORKERS=4
CMD ["sh", "-c", "gunicorn -w ${WORKERS} -b 0.0.0.0:5000 --timeout 60 main:app"]
