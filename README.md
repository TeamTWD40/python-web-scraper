# Corporate Website scraper

## Local development
``` shell
$ python3 -m virtualenv venv
$ source .env/bin/activate
$ pip install -r requirements.txt

$ docker build -t scraper:latest .
$ docker run --network="host" -p 5000:5000 scraper
```
