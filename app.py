from flask import Flask
from flask import jsonify

import scraper

app = Flask(__name__)

# asdf
@app.route('/')
def index():
    return 'Server Works!'

@app.route('/actuator/health')
def healthCheck():
    return jsonify(status="up")

@app.route('/scrape/<ticker>')
def scrape_url(ticker):
    text = scraper.scrape_url(ticker, 'http://wilsoninformatics.com')
    return 'Paragraph: %s' % text
