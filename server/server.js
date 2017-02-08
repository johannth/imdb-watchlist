import express from 'express';
import fetch from 'node-fetch';
import cheerio from 'cheerio';
import bodyParser from 'body-parser';
import Cache from 'async-disk-cache';

const app = express();

const cache = new Cache('watchlist');

app.use(bodyParser.json());

app.post('/api/watchlist', (req, res) => {
  fetch(`http://www.imdb.com/user/${req.body.userId}/watchlist?view=detail`)
    .then(response => response.text())
    .then(text => {
      const initialStateRegex = /IMDbReactInitialState\.push\((\{.+\})\);/g;
      const matches = initialStateRegex.exec(text);
      const initialStateText = matches[1];

      const watchlistData = JSON.parse(initialStateText);

      const movieIds = watchlistData.list.items.map(i => i.const);

      return fetch(
        `http://www.imdb.com/title/data?ids=${movieIds.join(
          ','
        )}&pageId=${watchlistData.list.id}&pageType=list&subpageType=watchlist`
      )
        .then(response => response.json())
        .then(movieData => {
          const movies = movieIds.map(movieId => movieData[movieId].title);

          const list = {
            id: watchlistData.list.id,
            name: watchlistData.list.name,
            movies
          };

          res.json({ list });
        });
    });
});

const justwatchCacheKey = imdbId => {
  return `justwatch:${imdbId}`;
};

const saveJsonInCache = json => {
  return JSON.stringify({ timestamp: Date.now(), value: json });
};

const getJsonFromCachedEntry = cacheEntry => {
  if (cacheEntry.isCached) {
    const cacheValue = JSON.parse(cacheEntry.value);
    const now = Date.now();
    if (now - cacheValue.timestamp < 30 * 60 * 1000) {
      return cacheValue.value;
    } else {
      return null;
    }
  } else {
    return null;
  }
};

const handleErrors = response => {
  if (!response.ok) {
    throw Error(response.statusText);
  }
  return response;
};

app.post('/api/justwatch', (req, res) => {
  cache.get(justwatchCacheKey(req.body.imdbId)).then(cacheEntry => {
    const cachedResponse = getJsonFromCachedEntry(cacheEntry);
    if (cachedResponse) {
      console.log(`Serving from cache ${req.body.imdbId}`);
      res.json(cachedResponse);
      return;
    }

    fetch('https://api.justwatch.com/titles/en_US/popular', {
      method: 'POST',
      body: JSON.stringify({
        content_types: [ 'show', 'movie' ],
        query: req.body.title
      }),
      headers: {
        Accept: 'application/json, text/plain, */*',
        'Content-Type': 'application/json'
      }
    })
      .then(handleErrors)
      .then(response => {
        return response.json();
      })
      .then(json => {
        const possibleItem = json.items && json.items[0];

        if (!possibleItem || possibleItem.title !== req.body.title) {
          res.json({ item: null });
          return;
        }

        const item = possibleItem;

        const response = {
          item: {
            id: item.id,
            href: `https://www.justwatch.com${item.full_path}`,
            offers: item.offers,
            scoring: item.scoring
          }
        };

        cache
          .set(justwatchCacheKey(req.body.imdbId), saveJsonInCache(response))
          .then(() => {
            res.json(response);
          });
      });
  });
});

const bechdelCacheKey = imdbId => {
  return `bechdel:${imdbId}`;
};

app.post('/api/bechdel', (req, res) => {
  cache.get(bechdelCacheKey(req.body.imdbId)).then(cacheEntry => {
    const cachedResponse = getJsonFromCachedEntry(cacheEntry);
    if (cachedResponse) {
      console.log(`Serving from cache ${req.body.imdbId}`);
      res.json(cachedResponse);
      return;
    }

    const imdbIdWithoutPrefix = req.body.imdbId.replace('tt', '');
    const url = `http://bechdeltest.com/api/v1/getMovieByImdbId?imdbid=${imdbIdWithoutPrefix}`;

    fetch(url, {
      method: 'GET',
      headers: {
        Accept: 'application/json, text/plain, */*',
        'Content-Type': 'application/json'
      }
    })
      .then(handleErrors)
      .then(response => {
        return response.json();
      })
      .then(json => {
        if (json.status) {
          return null;
        }
        return json;
      })
      .then(json => {
        const response = { item: json };

        cache
          .set(bechdelCacheKey(req.body.imdbId), saveJsonInCache(response))
          .then(() => {
            res.json(response);
          });
      });
  });
});

app.listen(3001, () => {
  console.log('App listening on port 3001!');
});
