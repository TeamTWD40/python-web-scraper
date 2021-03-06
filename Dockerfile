FROM python:3.7.3-alpine3.9

RUN adduser -D scraper

WORKDIR /home/scraper

COPY . /home/scraper

RUN pip install -r requirements.txt
ENV FLASK_RUN_PORT=8082
ENTRYPOINT [ "python" ]
EXPOSE 8082
CMD [ "app.py" ]
