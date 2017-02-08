import { combineReducers } from 'redux';

import { reducer as sematableReducer } from 'sematable';

import {
  RECEIVE_WATCHLIST_DATA,
  RECEIVE_JUSTWATCH_BATCH_DATA,
  RECEIVE_BECHDEL_BATCH_DATA,
  RECEIVE_CONFIRM_NETFLIX_BATCH_DATA
} from './actions';

const extractRunTime = movie => {
  const runTimeInMinutes = (movie.metadata.runtime || 0) / 60;
  const numberOfEpisodes = movie.metadata.numberOfEpisodes || 1;
  return runTimeInMinutes * numberOfEpisodes;
};

const extractMetascore = movie => {
  return movie.ratings.metascore / 10 || 0;
};

const extractImdbRating = movie => {
  return movie.ratings.rating || 0;
};

const calculateJustwatchMultiplier = movie => {
  if (movie.netflix) {
    return 5;
  } else if (movie.hbo) {
    return 4;
  } else if (movie.itunes) {
    return 3;
  } else if (movie.amazon) {
    return 2;
  } else {
    return 0.5;
  }
};

const calculatePriority = movie => {
  const metascore = movie.metascore;
  const imdbRating = movie.imdbRating;
  const averageRating = 0.5 * metascore + 0.5 * imdbRating;
  const runTimeInMinutes = movie.runTime;
  const justwatchMultiplier = calculateJustwatchMultiplier(movie);
  const bechdelMultiplier = (movie.bechdel || 0) + 0.5;
  if (runTimeInMinutes && runTimeInMinutes > 0) {
    return bechdelMultiplier *
      justwatchMultiplier *
      (averageRating / runTimeInMinutes * 100);
  } else {
    return 0;
  }
};

const createInitialMovieData = rawMovieData => {
  return {
    id: rawMovieData.id,
    title: rawMovieData.primary.title,
    href: `http://www.imdb.com${rawMovieData.primary.href}`,
    runTime: extractRunTime(rawMovieData),
    metascore: extractMetascore(rawMovieData),
    imdbRating: extractImdbRating(rawMovieData),
    netflix: null,
    itunes: null,
    amazon: null,
    hbo: null,
    bechdel: null,
    priority: null
  };
};

const updateMovieFromJustwatchData = (movie, justwatchData) => {
  return { ...movie, ...justwatchData };
};

const updateMovieFromBechdelData = (movie, bechdelData) => {
  return { ...movie, bechdel: bechdelData.rating };
};

const updateMovieFromNetflixData = (movie, netflixData) => {
  return { ...movie, netflix: netflixData.netflix };
};

const updateMoviesWithPriority = list => {
  return list.map(movie => {
    return { ...movie, priority: calculatePriority(movie) };
  });
};

const dataReducer = (state = { list: null }, action) => {
  switch (action.type) {
    case RECEIVE_WATCHLIST_DATA: {
      const list = action.list.movies.map(createInitialMovieData);
      return { ...state, list: updateMoviesWithPriority(list) };
    }
    case RECEIVE_JUSTWATCH_BATCH_DATA: {
      const list = state.list && state.list.map(movie => {
          const justwatchData = action.batch[movie.id];
          if (justwatchData) {
            return updateMovieFromJustwatchData(movie, justwatchData);
          } else {
            return movie;
          }
        });
      return { ...state, list: updateMoviesWithPriority(list) };
    }

    case RECEIVE_BECHDEL_BATCH_DATA: {
      const list = state.list && state.list.map(movie => {
          const bechdelData = action.batch[movie.id];
          if (bechdelData) {
            return updateMovieFromBechdelData(movie, bechdelData);
          } else {
            return movie;
          }
        });
      return { ...state, list: updateMoviesWithPriority(list) };
    }

    case RECEIVE_CONFIRM_NETFLIX_BATCH_DATA: {
      const list = state.list && state.list.map(movie => {
          const netflixData = action.batch[movie.id];
          if (netflixData) {
            return updateMovieFromNetflixData(movie, netflixData);
          } else {
            return movie;
          }
        });
      return { ...state, list: updateMoviesWithPriority(list) };
    }
    default:
      return state;
  }
};

export const rootReducer = combineReducers({
  sematable: sematableReducer,
  data: dataReducer
});
export default rootReducer;
