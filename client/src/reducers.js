import { combineReducers } from 'redux';

import { reducer as sematableReducer } from 'sematable';

const JUSTWATCH_ITUNES_PROVIDER_ID = 2;
const JUSTWATCH_NETFLIX_PROVIDER_ID = 8;
const JUSTWATCH_AMAZON_PROVIDER_ID = 10;
const JUSTWATCH_HBO_PROVIDER_ID = 27;

import {
  RECEIVE_WATCHLIST_DATA,
  RECEIVE_JUSTWATCH_BATCH_DATA
} from './actions';

const extractRunTime = movie => {
  const runTimeInMinutes = (movie.metadata.runtime || 0) / 60;
  const numberOfEpisodes = movie.metadata.numberOfEpisodes || 1;
  return runTimeInMinutes * numberOfEpisodes;
};

const extractMetascore = movie => {
  return movie.ratings.metascore / 100 || 0;
};

const extractImdbRating = movie => {
  return movie.ratings.rating || 0;
};

const calculateJustwatchMultiplier = justwatch => {
  if (!justwatch) {
    return 1;
  }
  if (justwatch.netflix) {
    return 5;
  } else if (justwatch.hbo) {
    return 4;
  } else if (justwatch.itunes) {
    return 3;
  } else if (justwatch.amazon) {
    return 2;
  } else {
    return 0;
  }
};

const calculateShouldWatch = (movie, justwatch) => {
  const metascore = movie.metascore;
  const imdbRating = movie.imdbRating;
  const averageRating = 0.5 * metascore + 0.5 * imdbRating;
  const runTimeInMinutes = movie.runTime;
  const justwatchMultiplier = calculateJustwatchMultiplier(justwatch);
  if (runTimeInMinutes && runTimeInMinutes > 0) {
    return justwatchMultiplier * (averageRating / runTimeInMinutes * 100);
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

const mapMovieData = rawMovieData => {
  const movie = {
    id: rawMovieData.id,
    title: rawMovieData.primary.title,
    href: `http://www.imdb.com${rawMovieData.primary.href}`,
    runTime: extractRunTime(rawMovieData),
    metascore: extractMetascore(rawMovieData),
    imdbRating: extractImdbRating(rawMovieData)
  };
  return { ...movie, priority: calculateShouldWatch(movie, null) };
};

const dataReducer = (state = { list: null }, action) => {
  switch (action.type) {
    case RECEIVE_WATCHLIST_DATA:
      return { ...state, list: action.list.movies.map(mapMovieData) };

    case RECEIVE_JUSTWATCH_BATCH_DATA: {
      const list = state.list && state.list.map(movie => {
          const justwatchData = action.batch[movie.id];
          if (justwatchData) {
            const streamability = {
              netflix: extractOffer(
                justwatchData,
                JUSTWATCH_NETFLIX_PROVIDER_ID
              ),
              itunes: extractOffer(justwatchData, JUSTWATCH_ITUNES_PROVIDER_ID),
              amazon: extractOffer(justwatchData, JUSTWATCH_AMAZON_PROVIDER_ID),
              hbo: extractOffer(justwatchData, JUSTWATCH_HBO_PROVIDER_ID)
            };
            return {
              ...movie,
              ...streamability,
              priority: calculateShouldWatch(movie, streamability)
            };
          } else {
            return movie;
          }
        });
      return { ...state, list };
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
