import newrelic from 'newrelic';
import express from 'express';
import fetch from 'node-fetch';
import cheerio from 'cheerio';
import bodyParser from 'body-parser';
import request from 'request';
import cors from 'cors';
import bluebird from 'bluebird';
import redis from 'redis';
import expressWs from 'express-ws';
import http from 'http';
import leven from 'leven';
bluebird.promisifyAll(redis.RedisClient.prototype);
bluebird.promisifyAll(redis.Multi.prototype);

const app = express();
expressWs(app);

const cache = redis.createClient({ url: process.env.REDIS_URL });

if (process.env.DISABLE_CACHE) {
  console.log('Cache is disabled');
}

app.use(bodyParser.json());
app.use(cors());

app.ws('/stream', (ws, req) => {
  console.log('Connected');
  ws.on('message', messageAsString => {
    const message = JSON.parse(messageAsString);
    switch (message.type) {
      case 'watchlist': {
        const { userId } = message.body;
        fetchWatchList(userId).then(list => {
          ws.send(
            JSON.stringify({ type: message.type, body: { userId, list } })
          );
        });
        break;
      }
      case 'movies': {
        const { movies } = message.body;
        Promise.all(
          movies.map(movie => fetchMovieDetails(movie))
        ).then(movies => {
          ws.send(JSON.stringify({ type: message.type, body: { movies } }));
        });
        break;
      }

      case 'movie': {
        const { movie } = message.body;
        fetchMovieDetails(movie).then(movie => {
          ws.send(JSON.stringify({ type: message.type, body: { movie } }));
        });
        break;
      }
    }
  });
});

const getJsonFromCache = cache =>
  key => {
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

const saveJsonToCache = cache =>
  (key, value, expiryInSeconds) => {
    return cache.setexAsync(key, expiryInSeconds, JSON.stringify(value));
  };

const fetchWatchList = userId => {
  return fetch(`http://www.imdb.com/user/${userId}/watchlist?view=detail`)
    .then(response => response.text())
    .then(text => {
      const initialStateRegex = /IMDbReactInitialState\.push\((\{.+\})\);/g;
      const matches = initialStateRegex.exec(text);
      const initialStateText = matches[1];

      const watchlistData = JSON.parse(initialStateText);

      const movieIds = watchlistData.list.items.map(i => i.const);

      return fetch(`http://www.imdb.com/title/data?ids=${movieIds.join(',')}`, {
        method: 'GET',
        headers: { 'Accept-Language': 'en-US,en' },
      })
        .then(response => response.json())
        .then(movieData => {
          const movies = movieIds.map(movieId =>
            convertImdbMovieToMovie(movieData[movieId].title));

          return {
            id: watchlistData.list.id,
            name: watchlistData.list.name,
            movies,
          };
        });
    });
};

const calculateMovieRunTime = imdbMovieData => {
  const numberOfEpisodes = imdbMovieData.metadata.numberOfEpisodes || 1;
  const runTimeInSeconds = imdbMovieData.metadata.runtime;
  return runTimeInSeconds ? runTimeInSeconds * numberOfEpisodes / 60 : null;
};

const imdbMovieTypes = {
  featureFilm: 'film',
  series: 'series',
};

const convertImdbMovieToMovie = imdbMovieData => {
  return movieData({
    id: imdbMovieData.id,
    title: imdbMovieData.primary.title,
    imdbUrl: `http://www.imdb.com${imdbMovieData.primary.href}`,
    type: imdbMovieTypes[imdbMovieData.type],
    releaseDate: imdbMovieData.metadata.release,
    runTime: calculateMovieRunTime(imdbMovieData),
    genres: imdbMovieData.metadata.genres,
    metascore: imdbMovieData.ratings.metascore,
    imdbRating: imdbMovieData.ratings.rating * 10,
  });
};

const movieData = (
  {
    id,
    title,
    imdbUrl,
    type,
    releaseDate,
    runTime,
    genres,
    metascore,
    rottenTomatoesMeter,
    imdbRating,
    bechdelRating,
    netflix,
    hbo,
    itunes,
    amazon,
  }
) => {
  return {
    id,
    title,
    imdbUrl,
    type,
    releaseDate,
    runTime,
    genres,
    ratings: {
      metascore,
      rottenTomatoesMeter,
      imdb: imdbRating,
      bechdel: bechdelRating,
    },
    viewingOptions: {
      netflix: netflix || null,
      hbo: hbo || null,
      itunes: itunes || null,
      amazon: amazon || null,
    },
  };
};

const fetchWithCache = (url, options, expiryInSeconds) => {
  const cacheKey = `request:${url}:${JSON.stringify(options)}`;
  const promiseBuilder = () =>
    fetch(url, options)
      .then(response => {
        if (!response.ok) {
          throw Error(response.statusText);
        }
        return response;
      })
      .then(response => {
        return response.json();
      });

  return cachePromise(cacheKey, promiseBuilder, expiryInSeconds);
};

const cachePromise = (key, promiseBuilder, expiryInSeconds) => {
  return getJsonFromCache(cache)(key).then(cachedValue => {
    if (cachedValue) {
      console.log(`${key}: Serving from cache`, cachedValue);
      return cachedValue;
    }

    console.log(`${key}: resolving...`);
    return promiseBuilder().then(value =>
      saveJsonToCache(cache)(key, value, expiryInSeconds).then(() => value));
  });
};

const fetchMovieDetails = movie => {
  return Promise.all([
    fetchBechdel(movie.id).catch(error => {
      console.error('Bechdel', error);
      return null;
    }),
    fetchJustWatchData(
      movie.id,
      movie.title,
      movie.type,
      movie.releaseDate
    ).catch(error => {
      console.error('JustWatch', error);
      return { viewingOptions: null, ratings: null };
    }),
    checkIfMovieIsOnLocalNetflix(movie.id, movie.title).catch(error => {
      console.error('Netflix', error);
      return { netflixUrl: null };
    }),
  ])
    .then(bechdelRating_justWatch_localNetflixUrl => {
      const bechdelRating = bechdelRating_justWatch_localNetflixUrl[0];

      const {
        viewingOptions,
        ratings,
      } = bechdelRating_justWatch_localNetflixUrl[1];

      const { netflixUrl } = bechdelRating_justWatch_localNetflixUrl[2];
      const netflix = netflixUrl
        ? offerData({
            provider: 'netflix',
            presentationType: 'hd',
            monetizationType: 'flatrate',
            url: netflixUrl,
          })
        : null;

      return movieData({
        ...movie,
        imdbRating: movie.ratings.imdb,
        metascore: movie.ratings.metascore,
        bechdelRating,
        netflix,
        rottenTomatoesMeter: ratings && ratings.rottenTomatoesMeter,
        amazon: viewingOptions && viewingOptions.amazon,
        itunes: viewingOptions && viewingOptions.itunes,
        hbo: viewingOptions && viewingOptions.hbo,
      });
    })
    .catch(error => {
      console.error(error);
    });
};

const fetchBechdel = imdbId => {
  const imdbIdWithoutPrefix = imdbId.replace('tt', '');
  const url = `http://bechdeltest.com/api/v1/getMovieByImdbId?imdbid=${imdbIdWithoutPrefix}`;

  return fetchWithCache(
    url,
    {
      method: 'GET',
      headers: {
        Accept: 'application/json, text/plain, */*',
        'Content-Type': 'application/json',
      },
    },
    30 * 24 * 60 * 60
  )
    .then(json => {
      if (json.status) {
        return null;
      }
      return json;
    })
    .then(json => {
      if (json) {
        return { rating: parseInt(json.rating), dubious: json.dubious === '1' };
      } else {
        return null;
      }
    });
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

const justWatchProviders = {
  2: 'itunes',
  8: 'netflix',
  10: 'amazon',
  27: 'hbo',
};

const offerData = (
  {
    provider,
    url,
    monetizationType,
    presentationType,
    price,
  }
) => {
  return {
    provider,
    url,
    monetizationType,
    presentationType,
    price: price || null,
  };
};

const extractBestViewingOption = (provider, viewingOptions) => {
  const viewingOptionsByProvider = viewingOptions.filter(
    viewingOption => viewingOption.provider === provider
  );

  viewingOptionsByProvider.sort((viewingOptionA, viewingOptionB) => {
    const ordinalA = viewingOptionOrdinal(viewingOptionA);
    const ordinalB = viewingOptionOrdinal(viewingOptionB);

    for (var i = 0; i !== ordinalA.length; i++) {
      const result = ordinalA[i] - ordinalB[i];
      if (result !== 0) {
        return result;
      }
    }
    return 0;
  });

  return viewingOptionsByProvider[0] || null;
};

const viewingOptionOrdinal = viewingOption => {
  const presentationTypeOrdinal = viewingOption.presentationType === 'hd'
    ? 0
    : 1;
  switch (viewingOption.monetizationType) {
    case 'flatrate':
      return [0, presentationTypeOrdinal, 0];
    case 'rent':
      return [1, presentationTypeOrdinal, viewingOption.price];
    case 'buy':
      return [2, presentationTypeOrdinal, viewingOption.price];
  }
};

const fetchJustWatchData = (imdbId, title, type, releaseDateTimestamp) => {
  const releaseDate = new Date(releaseDateTimestamp);
  const year = releaseDate.getFullYear();
  return fetchWithCache(
    'https://api.justwatch.com/titles/en_US/popular',
    {
      method: 'POST',
      body: JSON.stringify({
        content_types: [justwatchType(type)],
        query: title,
      }),
      headers: {
        Accept: 'application/json, text/plain, */*',
        'Content-Type': 'application/json',
      },
    },
    24 * 60 * 60
  ).then(json => {
    const possibleItem = findBestPossibleJustwatchResult(
      title,
      year,
      type,
      json.items
    );

    if (!possibleItem) {
      return { viewingOptions: null, ratings: null };
    }

    const item = possibleItem;

    const offers = item.offers || [];

    const viewingOptions = offers.map(offer => {
      const provider = justWatchProviders[offer.provider_id];
      return offerData({
        provider,
        url: offer.urls.standard_web,
        monetizationType: offer.monetization_type,
        presentationType: offer.presentation_type,
        price: offer.retail_price,
      });
    });

    const netflix = extractBestViewingOption('netflix', viewingOptions);
    const amazon = extractBestViewingOption('amazon', viewingOptions);
    const hbo = extractBestViewingOption('hbo', viewingOptions);
    const itunes = extractBestViewingOption('itunes', viewingOptions);

    const scoring = item.scoring;

    const rottenTomatoesMeter = scoring
      .filter(score => score.provider_type === 'tomato:meter')
      .map(score => score.value)[0];

    return {
      viewingOptions: {
        netflix,
        amazon,
        hbo,
        itunes,
      },
      ratings: {
        rottenTomatoesMeter,
      },
    };
  });
};

//
// We get Netflix urls from JustWatch which work for the U.S. Netflix.
// Those won't necessary work on the Icelandic Netflix. The movie
// seems to have the same ID though so we try to see if a localized
// url returns 200.
const checkIfMovieIsOnLocalNetflix = (imdbId, title) => {
  return fetchWithCache(
    `http://denmark.flixlist.co/autocomplete/titles?q=${encodeURIComponent(title)}`,
    {},
    24 * 60 * 60
  ).then(json => {
    if (!json.filter) {
      return { netflixUrl: null };
    }

    const possibleNetflixId = json
      .filter(result => {
        return result.title === title; // This missing a check for year but it still much better than nothing.
      })
      .map(result => {
        return result.url.replace('/titles/', '');
      })[0];

    if (!possibleNetflixId) {
      return { netflixUrl: null };
    }

    return doubleCheckIfMovieIsOnLocaleNetflix(
      imdbId,
      `https://www.netflix.com/title/${possibleNetflixId}`,
      'is'
    );
  });
};

const doubleCheckIfMovieIsOnLocaleNetflix = (imdbId, netflixUrl, locale) => {
  const cacheKey = `netflix:${imdbId}:${locale}`;

  const netflixUrlInLocale = netflixUrl.replace('/title/', `/${locale}/title/`);

  const promiseBuilder = () => {
    return new Promise(function(resolve, reject) {
      request(
        { method: 'GET', followRedirect: false, url: netflixUrl },
        (error, response, body) => {
          const locationHeader = response.headers['location'];
          console.log(
            `/api/netflix ${imdbId}: Netflix returned ${response.statusCode} on ${netflixUrl} with location ${locationHeader}`
          );

          resolve(
            response.statusCode == 200 || locationHeader === netflixUrlInLocale
              ? { netflixUrl: netflixUrlInLocale }
              : { netflixUrl: null }
          );
        }
      );
    });
  };

  return cachePromise(cacheKey, promiseBuilder, 24 * 60 * 60);
};

// process.env.PORT lets the port be set by Heroku
const port = process.env.PORT || 8080;

app.listen(port, () => {
  console.log(`App listening on port ${port}!`);
});
