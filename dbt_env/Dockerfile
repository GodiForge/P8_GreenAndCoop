FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    TZ=Europe/Paris

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    libpq-dev \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/app/dbt

COPY requirements.txt /tmp/requirements.txt
RUN pip install --upgrade pip && \
    pip install -r /tmp/requirements.txt

RUN mkdir -p /usr/app/dbt /local_files /scripts
