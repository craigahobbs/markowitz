# Running Markowitz on a Mac

These steps install Markowitz and run it on your Mac. You need to do the setup only once.

To run a command, copy the gray box, paste it into Terminal, and press Return. To open Terminal, press Command-Space,
type "Terminal", and press Return.


## Setup

This installs everything Markowitz needs, downloads it into a "markowitz" folder in your home folder, and downloads
the stock prices. It asks for your Mac password (nothing shows as you type - that's normal), and may ask you to press
Return. It takes about ten minutes.

~~~sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" && \
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile && \
    eval "$(/opt/homebrew/bin/brew shellenv)" && \
    brew install python couchdb && \
    printf '[admins]\nadmin = markowitz\n' > "$(brew --prefix couchdb)/etc/local.d/admin.ini" && \
    brew services restart couchdb && \
    for i in {1..30}; do curl -s http://127.0.0.1:5984/ > /dev/null && break; sleep 1; done && \
    cd ~ && \
    git clone https://github.com/craigahobbs/markowitz.git && \
    cd ~/markowitz && \
    MARKOWITZ_COUCH_CREDENTIALS=admin:markowitz make init
~~~


## Running Markowitz

Run this, then open <http://127.0.0.1:8080/> in Safari:

~~~sh
cd ~/markowitz && \
    MARKOWITZ_COUCH_CREDENTIALS=admin:markowitz make run
~~~

Markowitz runs until you close the Terminal window (or press Control-C in it).

To update the stock prices, go to the **Stocks** page and click **Update All**.


## Getting the latest version

~~~sh
cd ~/markowitz && \
    git pull
~~~


## If something goes wrong

If Markowitz says it can't reach the database (for example, after Homebrew updates CouchDB), restart CouchDB:

~~~sh
printf '[admins]\nadmin = markowitz\n' > "$(brew --prefix couchdb)/etc/local.d/admin.ini" && \
    brew services restart couchdb
~~~
