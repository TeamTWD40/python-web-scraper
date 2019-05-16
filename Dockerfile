FROM python:3.7.3-alpine3.9

RUN adduser -D scraper

WORKDIR /home/scraper

COPY . /home/scraper

RUN pip install -r requirements.txt

ENTRYPOINT [ "python" ]

CMD [ "app.py" ]
