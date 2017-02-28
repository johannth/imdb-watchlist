import newrelic from 'newrelic';
import express from 'express';
import fetch from 'node-fetch';
import cheerio from 'cheerio';
import bodyParser from 'body-parser';
import request from 'request';
import cors from 'cors';
import bluebird from 'bluebird';
import redis from 'redis';
import leven from 'leven';
bluebird.promisifyAll(redis.RedisClient.prototype);
bluebird.promisifyAll(redis.Multi.prototype);

const app = express();

const cache = redis.createClient({ url: process.env.REDIS_URL });

if (process.env.DISABLE_CACHE) {
  console.log('Cache is disabled');
}

app.use(bodyParser.json());
app.use(cors());

const handleErrors = response => {
  if (!response.ok) {
    throw Error(response.statusText);
  }
  return response;
};

const getJsonFromCache = cache => key => {
  if (process.env.DISABLE_CACHE) {
    return Promise.resolve(null);
  }
  return cache.getAsync(key).then(result => {
    if (result) {
      return JSON.parse(result);
    } else {
      return null;
    }
  });
};
const saveJsonToCache = cache => (key, value, expiryInSeconds) => {
  return cache.setexAsync(key, expiryInSeconds, JSON.stringify(value));
};

app.get('/api/watchlist', (req, res) => {
  fetch(`http://www.imdb.com/user/${req.query.userId}/watchlist?view=detail`)
    .then(response => response.text())
    .then(text => {
      const initialStateRegex = /IMDbReactInitialState\.push\((\{.+\})\);/g;
      const matches = initialStateRegex.exec(text);
      const initialStateText = matches[1];

      const watchlistData = JSON.parse(initialStateText);

      const movieIds = watchlistData.list.items.map(i => i.const);

      return fetch(`http://www.imdb.com/title/data?ids=${movieIds.join(',')}`, {
        method: 'GET',
        headers: { 'Accept-Language': 'en-US,en' }
      })
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

const findBestPossibleJustwatchResult = (title, year, type, results) => {
  if (!results) {
    return null;
  }

  return results.filter(result => {
    const titleMatch = leven(result.title.toLowerCase(), title.toLowerCase());
    const titleAndYearMatch = titleMatch === 0 &&
      result.original_release_year === year;
    const fuzzyTitleAndYearMatch = titleMatch <= 5 &&
      result.original_release_year === year;
    const titleMatchesForSeries = titleMatch === 0 && type === 'series';
    return titleAndYearMatch || fuzzyTitleAndYearMatch || titleMatchesForSeries;
  })[0];
};

const justwatchType = itemType => {
  switch (itemType) {
    case 'film':
      return 'movie';
    case 'series':
      return 'show';
  }
};

app.get('/api/justwatch', (req, res) => {
  const imdbId = req.query.imdbId;
  const title = req.query.title;
  const type = req.query.type;
  const year = parseInt(req.query.year || '0');

  getJsonFromCache(cache)(justwatchCacheKey(imdbId)).then(cachedResponse => {
    if (cachedResponse) {
      console.log(`/api/justwatch ${imdbId}: Serving from cache`);
      res.json(cachedResponse);
      return;
    }

    fetch('https://api.justwatch.com/titles/en_US/popular', {
      method: 'POST',
      body: JSON.stringify({
        content_types: [justwatchType(type)],
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
        const possibleItem = findBestPossibleJustwatchResult(
          title,
          year,
          type,
          json.items
        );

        if (!possibleItem) {
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

        saveJsonToCache(cache)(
          justwatchCacheKey(imdbId),
          response,
          24 * 60 * 60
        ).then(() => {
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
  getJsonFromCache(cache)(bechdelCacheKey(imdbId)).then(cachedResponse => {
    if (cachedResponse) {
      console.log(`/api/bechdel ${imdbId}: Serving from cache`);
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

        saveJsonToCache(cache)(
          bechdelCacheKey(imdbId),
          response,
          30 * 24 * 60 * 60
        ).then(() => {
          res.json(response);
        });
      });
  });
});

const netflixCacheKey = imdbId => {
  return `netflix:${imdbId}`;
};

//
// We get Netflix urls from JustWatch which work for the U.S. Netflix.
// Those won't necessary work on the Icelandic Netflix. The movie
// seems to have the same ID though so we try to see if a localized
// url returns 200.
app.get('/api/netflix', (req, res) => {
  const imdbId = req.query.imdbId;
  const title = req.query.title;
  const year = parseInt(req.query.year || '0');
  const locale = req.query.locale;
  var netflixUrl = req.query.netflixUrl &&
    req.query.netflixUrl.replace('http://', 'https://');

  getJsonFromCache(cache)(netflixCacheKey(imdbId)).then(cachedResponse => {
    if (cachedResponse) {
      console.log(`/api/netflix ${imdbId}: Serving from cache`);
      res.json(cachedResponse);
      return;
    }

    if (netflixUrl) {
      checkIfMovieIsAvailableOnNetflix(
        imdbId,
        netflixUrl,
        locale
      ).then(netflixUrl => {
        const payload = { data: { netflixUrl: netflixUrl } };

        saveJsonToCache(cache)(
          netflixCacheKey(imdbId),
          payload,
          24 * 60 * 60
        ).then(() => {
          res.json(payload);
        });
      });
    } else {
      fetch(`http://denmark.flixlist.co/autocomplete/titles?q=${title}`)
        .then(response => {
          if (!response.ok) {
            return {};
          }
          return response.json();
        })
        .then(json => {
          const possibleNetflixId = json
            .filter(result => {
              return result.title === title; // This missing a check for year but it still much better than nothing.
            })
            .map(result => {
              return result.url.replace('/titles/', '');
            })[0];

          if (possibleNetflixId) {
            checkIfMovieIsAvailableOnNetflix(
              imdbId,
              `https://www.netflix.com/title/${possibleNetflixId}`,
              locale
            ).then(netflixUrl => {
              const payload = { data: { netflixUrl: netflixUrl } };

              saveJsonToCache(cache)(
                netflixCacheKey(imdbId),
                payload,
                24 * 60 * 60
              ).then(() => {
                res.json(payload);
              });
            });
          } else {
            res.json({ data: null });
          }
        });
    }
  });
});

const checkIfMovieIsAvailableOnNetflix = (imdbId, netflixUrl, locale) => {
  const netflixUrlInLocale = netflixUrl.replace('/title/', `/${locale}/title/`);

  const requestUrl = netflixUrl;
  return new Promise(function(resolve, reject) {
    request({ method: 'GET', followRedirect: false, url: requestUrl }, (
      error,
      response,
      body
    ) => {
      const locationHeader = response.headers['location'];
      console.log(
        `/api/netflix ${imdbId}: Netflix returned ${response.statusCode} on ${requestUrl} with location ${locationHeader}`
      );

      resolve(
        response.statusCode == 200 || locationHeader === netflixUrlInLocale
          ? netflixUrlInLocale
          : null
      );
    });
  });
};

// process.env.PORT lets the port be set by Heroku
const port = process.env.PORT || 8080;

app.listen(port, () => {
  console.log(`App listening on port ${port}!`);
});
