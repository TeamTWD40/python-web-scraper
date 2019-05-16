from bs4 import BeautifulSoup
from bs4.element import Comment
from pymongo import MongoClient
from pprint import pprint
import urllib.request


# connect to MongoDB, change the << MONGODB URL >> to reflect your own connection string
client = MongoClient('localhost')
db = client.ticker_scrape
# Issue the serverStatus command and print the results
serverStatusResult = db.command("serverStatus")
# pprint(serverStatusResult)

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

