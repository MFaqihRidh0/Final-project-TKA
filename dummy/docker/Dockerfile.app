FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

COPY fp-tka-26-main/Resources/BE/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY fp-tka-26-main/Resources/BE/app.py .

CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:5000", "--timeout", "60", "app:app"]
