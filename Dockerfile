FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1
WORKDIR /app

RUN useradd --create-home appuser
USER appuser

COPY --chown=appuser main.py .

EXPOSE 8080

CMD ["python", "main.py"]
