import { combineReducers } from 'redux';

import { reducer as sematableReducer } from 'sematable';

import { RECEIVE_WATCHLIST_DATA } from './actions';

const extractRunTime = movie => {
  const runTimeInMinutes = movie.metadata.runtime / 60;
  const numberOfEpisodes = movie.metadata.numberOfEpisodes || 1;
  return runTimeInMinutes * numberOfEpisodes;
};

const extractMetascore = movie => {
  return movie.ratings.metascore / 100 || 0;
};

const extractImdbRating = movie => {
  return movie.ratings.rating || 0;
};

const calculateShouldWatch = movie => {
  const metascore = extractMetascore(movie);
  const imdbRating = extractImdbRating(movie);
  const averageRating = 0.5 * metascore + 0.5 * imdbRating;
  const runTimeInMinutes = extractRunTime(movie);
  if (runTimeInMinutes && runTimeInMinutes > 0) {
    return averageRating / runTimeInMinutes * 100;
  } else {
    return 0;
  }
};

const mapMovieData = movie => {
  return {
    id: movie.id,
    title: movie.primary.title,
    href: `http://www.imdb.com${movie.primary.href}`,
    runTime: extractRunTime(movie),
    metascore: extractMetascore(movie),
    imdbRating: extractImdbRating(movie),
    priority: calculateShouldWatch(movie)
  };
};

const dataReducer = (state = { list: null }, action) => {
  switch (action.type) {
    case RECEIVE_WATCHLIST_DATA:
      return { ...state, list: action.list.movies.map(mapMovieData) };
    default:
      return state;
  }
};

export const rootReducer = combineReducers({
  sematable: sematableReducer,
  data: dataReducer
});
export default rootReducer;
