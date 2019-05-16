from bs4 import BeautifulSoup
from bs4.element import Comment
from pymongo import MongoClient
from pprint import pprint
import urllib.request
import os

# mongodb://root:pass@localhost:27017/
os.environ['HOME']
MONGO_URI = 'mongodb://' + os.environ['DB_USERNAME'] + ':' + os.environ['DB_PASSWORD'] + '@' + os.environ['DB_URL'] + ':' + os.environ['DB_PORT']
client = MongoClient(MONGO_URI)
db = client.ticker_scrape
serverStatusResult = db.command("serverStatus")

def scrape_url(symbol, url):
    html = urllib.request.urlopen(url).read()
    text = text_from_html(html)
    result = db.reviews.insert_one(build_datastructure(symbol, url, text))
    print('Inserted scraped text for symbol {0}. ID: {1}'.format(symbol,result.inserted_id))
    return 'success'

def build_datastructure(symbol, url, text):
    company = {
        'ticker' : symbol,
        'url' : url,
        'text' : text 
    }
    return company

def tag_visible(element):
    if element.parent.name in ['style', 'script', 'head', 'title', 'meta', '[document]']:
        return False
    if isinstance(element, Comment):
        return False
    return True

def text_from_html(body):
    soup = BeautifulSoup(body, 'html.parser')
    texts = soup.findAll(text=True)
    visible_texts = filter(tag_visible, texts)  
    return u" ".join(t.strip() for t in visible_texts)

