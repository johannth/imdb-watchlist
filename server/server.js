import newrelic from 'newrelic';
import express from 'express';
import fetch from 'node-fetch';
import cheerio from 'cheerio';
import bodyParser from 'body-parser';

import cors from 'cors';
import expressWs from 'express-ws';
import { createCache } from './cache';
import { fetchImdbWatchList } from './imdb';
import { fetchBechdel } from './bechdel';
import { fetchJustWatchData } from './justwatch';
import { checkIfMovieIsOnLocalNetflix } from './netflix';
import { movieData, viewingOptionData } from './models';

const app = express();
expressWs(app);

const cachePromise = createCache({
  url: process.env.REDIS_URL,
  writeOnly: process.env.DISABLE_CACHE,
});
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
        fetchImdbWatchList(userId).then(list => {
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
    }
  });
});

const fetchMovieDetails = movie => {
  return Promise.all([
    fetchBechdelWithCache(movie.id).catch(error => {
      console.log('Bechdel', error);
      return null;
    }),
    fetchJustWatchDataWithCache(
      movie.id,
      movie.title,
      movie.type,
      movie.releaseDate
    ).catch(error => {
      console.log('JustWatch', error);
      return { viewingOptions: null, ratings: null };
    }),
    checkIfMovieIsOnLocalNetflixWithCache(
      movie.id,
      movie.title,
      'is'
    ).catch(error => {
      console.log('Netflix', error);
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
        ? viewingOptionData({
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

const fetchBechdelWithCache = imdbId => {
  const cacheKey = `bechdel:${imdbId}`;
  return cachePromise(cacheKey, () => fetchBechdel(imdbId), 30 * 24 * 60 * 60);
};

const fetchJustWatchDataWithCache = (
  imdbId,
  title,
  type,
  releaseDateTimestamp
) => {
  const cacheKey = `justwatch:${imdbId}`;
  return cachePromise(
    cacheKey,
    () => fetchJustWatchData(imdbId, title, type, releaseDateTimestamp),
    24 * 60 * 60
  );
};

const checkIfMovieIsOnLocalNetflixWithCache = (imdbId, title, locale) => {
  const cacheKey = `netflix:${imdbId}:${locale}`;
  return cachePromise(
    cacheKey,
    () => checkIfMovieIsOnLocalNetflix(imdbId, title, locale),
    24 * 60 * 60
  );
};

// process.env.PORT lets the port be set by Heroku
const port = process.env.PORT || 8080;

app.listen(port, () => {
  console.log(`App listening on port ${port}!`);
});
