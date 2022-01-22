#FROM python:3.7-bullseye
FROM ghcr.io/a224327780/python

COPY . /data/python

WORKDIR /data/python

RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 8080

CMD sanic main.app --host=0.0.0.0 --port=8080 --fast --access-logs