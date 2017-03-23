import fetch from 'node-fetch';
import { handleErrors } from './utils';
import { movieData } from './models';

export const fetchImdbWatchList = userId => {
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
        .then(handleErrors)
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

const imdbMovieTypes = {
  featureFilm: 'film',
  series: 'series',
  episode: 'series',
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

const calculateMovieRunTime = imdbMovieData => {
  const numberOfEpisodes = imdbMovieData.metadata.numberOfEpisodes || 1;
  const runTimeInSeconds = imdbMovieData.metadata.runtime;
  return runTimeInSeconds ? runTimeInSeconds * numberOfEpisodes / 60 : null;
};
