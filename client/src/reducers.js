import { combineReducers } from 'redux';

import { reducer as sematableReducer } from 'sematable';

import {
  RECEIVE_WATCHLIST_DATA,
  RECEIVE_JUSTWATCH_BATCH_DATA,
  RECEIVE_BECHDEL_BATCH_DATA
} from './actions';

const JUSTWATCH_ITUNES_PROVIDER_ID = 2;
const JUSTWATCH_NETFLIX_PROVIDER_ID = 8;
const JUSTWATCH_AMAZON_PROVIDER_ID = 10;
const JUSTWATCH_HBO_PROVIDER_ID = 27;

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

const extractOffer = (justwatch, providerId) => {
  const allOffers = justwatch && justwatch.offers || [];
  const possibleOffers = allOffers
    .filter(offer => offer.provider_id === providerId)
    .sort(compareOptions);

  if (possibleOffers.length > 0) {
    return possibleOffers[0].urls.standard_web;
  } else {
    return null;
  }
};

const monetizationTypeOrder = monetizationType => {
  switch (monetizationType) {
    case 'flatrate':
      return 0;
    case 'rent':
      return 1;
    case 'buy':
      return 2;
    default:
      return 3;

  }
};

const presentationTypeOrder = presentationType => {
  switch (presentationType) {
    case 'hd':
      return 0;
    case 'sd':
      return 1;
    default:
      return 2;
  }
};

const compareOptions = (offerA, offerB) => {
  const sortCriteria_A = [
    monetizationTypeOrder(offerA.monetization_type),
    presentationTypeOrder(offerA.presentation_type),
    offerA.retail_price || 0
  ];
  const sortCriteria_B = [
    monetizationTypeOrder(offerB.monetization_type),
    presentationTypeOrder(offerB.presentation_type),
    offerB.retail_price || 0
  ];

  var comparator = 0;
  var i = 0;
  while (comparator === 0 && i !== sortCriteria_A.length) {
    comparator = sortCriteria_A[i] - sortCriteria_B[i];
    i++;
  }

  return comparator;
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
  const streamability = {
    netflix: extractOffer(justwatchData, JUSTWATCH_NETFLIX_PROVIDER_ID),
    itunes: extractOffer(justwatchData, JUSTWATCH_ITUNES_PROVIDER_ID),
    amazon: extractOffer(justwatchData, JUSTWATCH_AMAZON_PROVIDER_ID),
    hbo: extractOffer(justwatchData, JUSTWATCH_HBO_PROVIDER_ID)
  };
  return { ...movie, ...streamability };
};

const updateMovieFromBechdelData = (movie, bechdelData) => {
  return { ...movie, bechdel: bechdelData.rating };
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
    default:
      return state;
  }
};

export const rootReducer = combineReducers({
  sematable: sematableReducer,
  data: dataReducer
});
export default rootReducer;
