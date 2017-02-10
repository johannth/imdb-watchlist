import express from 'express';
import fetch from 'node-fetch';
import cheerio from 'cheerio';
import bodyParser from 'body-parser';
import Cache from 'async-disk-cache';
import request from 'request';
import cors from 'cors';

const app = express();

const cache = new Cache('watchlist');

app.use(bodyParser.json());
app.use(cors());

app.get('/api/watchlist', (req, res) => {
  fetch(`http://www.imdb.com/user/${req.query.userId}/watchlist?view=detail`)
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

app.get('/api/justwatch', (req, res) => {
  const imdbId = req.query.imdbId;
  const title = req.query.title;

  cache.get(justwatchCacheKey(imdbId)).then(cacheEntry => {
    const cachedResponse = getJsonFromCachedEntry(cacheEntry);
    if (cachedResponse) {
      console.log(`/api/justwatch: Serving from cache ${imdbId}`);
      res.json(cachedResponse);
      return;
    }

    fetch('https://api.justwatch.com/titles/en_US/popular', {
      method: 'POST',
      body: JSON.stringify({
        content_types: [ 'show', 'movie' ],
        query: title
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

        if (!possibleItem || possibleItem.title !== title) {
          res.json({ data: null });
          return;
        }

        const item = possibleItem;

        const response = {
          data: {
            id: item.id,
            href: `https://www.justwatch.com${item.full_path}`,
            offers: item.offers,
            scoring: item.scoring
          }
        };

        cache
          .set(justwatchCacheKey(imdbId), saveJsonInCache(response))
          .then(() => {
            res.json(response);
          });
      });
  });
});

const bechdelCacheKey = imdbId => {
  return `bechdel:${imdbId}`;
};

app.get('/api/bechdel', (req, res) => {
  const imdbId = req.query.imdbId;
  cache.get(bechdelCacheKey(imdbId)).then(cacheEntry => {
    const cachedResponse = getJsonFromCachedEntry(cacheEntry);
    if (cachedResponse) {
      console.log(`/api/bechdel: Serving from cache ${imdbId}`);
      res.json(cachedResponse);
      return;
    }

    const imdbIdWithoutPrefix = imdbId.replace('tt', '');
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
        const response = { data: json };

        cache
          .set(bechdelCacheKey(imdbId), saveJsonInCache(response))
          .then(() => {
            res.json(response);
          });
      });
  });
});

const netflixCacheKey = imdbId => {
  return `netflix:${imdbId}`;
};

// We get Netflix urls from JustWatch which work for the U.S. Netflix.
// Those won't necessary work on the Icelandic Netflix. The movie
// seems to have the same ID though so we try to see if a localized
// url returns 200.
app.get('/api/netflix', (req, res) => {
  const imdbId = req.query.imdbId;
  const netflixUrl = req.query.netflixUrl;
  const locale = req.query.locale;

  cache.get(netflixCacheKey(imdbId)).then(cacheEntry => {
    if (!netflixUrl) {
      res.json({ data: null });
      return;
    }

    const cachedResponse = getJsonFromCachedEntry(cacheEntry);
    if (cachedResponse) {
      console.log(`/api/netflix: Serving from cache ${imdbId}`);
      res.json(cachedResponse);
      return;
    }

    const netflixUrlInLocale = netflixUrl
      .replace('/title/', `/${locale}/title/`)
      .replace('http://', 'https://');

    request({ method: 'GET', followRedirect: false, url: netflixUrlInLocale }, (
      error,
      response,
      body
    ) =>
      {
        const payload = {
          data: {
            netflixUrl: response.statusCode == 200 ? netflixUrlInLocale : null
          }
        };

        cache
          .set(netflixCacheKey(imdbId), saveJsonInCache(payload))
          .then(() => {
            res.json(payload);
          });
      });
  });
});

app.listen(3001, () => {
  console.log('App listening on port 3001!');
});
