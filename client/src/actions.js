import { reduceListToMap, handleErrors, splitIntoBatches } from './utils';
import { extractJustWatchDataFromResponse } from './justwatch';

export const REQUEST_WATCHLIST_DATA = 'REQUEST_WATCHLIST_DATA';
const requestWatchlistData = userId => {
  return { type: REQUEST_WATCHLIST_DATA, userId };
};

export const RECEIVE_WATCHLIST_DATA = 'RECEIVE_WATCHLIST_DATA';
const receiveWatchlistData = (userId, list) => {
  return { type: RECEIVE_WATCHLIST_DATA, userId, list };
};

export const REQUEST_JUSTWATCH_BATCH_DATA = 'REQUEST_JUSTWATCH_BATCH_DATA';
const requestJustWatchBatchData = batch => {
  return { type: REQUEST_JUSTWATCH_BATCH_DATA, batch };
};

export const RECEIVE_JUSTWATCH_BATCH_DATA = 'RECEIVE_JUSTWATCH_BATCH_DATA';
const receiveJustWatchBatchData = batch => {
  return { type: RECEIVE_JUSTWATCH_BATCH_DATA, batch };
};

const performJustWatchApiRequest = (imdbId, title) => {
  return fetch('/api/justwatch', {
    method: 'POST',
    body: JSON.stringify({ imdbId, title }),
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
      return { imdbId: imdbId, justwatch: json.item };
    })
    .catch(error => {
      console.log(error);
      return { imdbId: imdbId, justwatch: null };
    });
};

export const REQUEST_BECHDEL_BATCH_DATA = 'REQUEST_BECHDEL_BATCH_DATA';
const requestBechdelBatchData = batch => {
  return { type: REQUEST_BECHDEL_BATCH_DATA, batch };
};

export const RECEIVE_BECHDEL_BATCH_DATA = 'RECEIVE_BECHDEL_BATCH_DATA';
const receiveBechdelBatchData = batch => {
  return { type: RECEIVE_BECHDEL_BATCH_DATA, batch };
};

const performBechdelApiRequest = imdbId => {
  return fetch('/api/bechdel', {
    method: 'POST',
    body: JSON.stringify({ imdbId }),
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
      return { imdbId: imdbId, bechdel: json.item };
    })
    .catch(error => {
      console.log(error);
      return { imdbId: imdbId, bechdel: null };
    });
};

export const REQUEST_CONFIRM_NETFLIX_BATCH_DATA = 'REQUEST_CONFIRM_NETFLIX_BATCH_DATA';
const requestConfirmNetflixBatchData = batch => {
  return { type: REQUEST_CONFIRM_NETFLIX_BATCH_DATA, batch };
};

export const RECEIVE_CONFIRM_NETFLIX_BATCH_DATA = 'RECEIVE_CONFIRM_NETFLIX_BATCH_DATA';
const receiveConfirmNetflixBatchData = batch => {
  return { type: RECEIVE_CONFIRM_NETFLIX_BATCH_DATA, batch };
};

const performConfirmNetflixApiRequest = (imdbId, netflix) => {
  return fetch('/api/netflix', {
    method: 'POST',
    body: JSON.stringify({ imdbId, netflix, locale: 'is' }),
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
      return { imdbId: imdbId, netflix: json.netflix };
    })
    .catch(error => {
      console.log(error);
      return { imdbId: imdbId, netflix: null };
    });
};

const fetchJustWatchDataForBatch = (dispatch, batch) => {
  dispatch(requestJustWatchBatchData(batch));
  return Promise
    .all(
      batch.map(
        movie => performJustWatchApiRequest(movie.id, movie.primary.title)
      )
    )
    .then(responses => {
      const cleanedResponses = responses.map(response => {
        return {
          id: response.imdbId,
          data: extractJustWatchDataFromResponse(response.justwatch)
        };
      });
      const justWatchDataForBatch = reduceListToMap(
        cleanedResponses,
        'id',
        'data'
      );

      dispatch(receiveJustWatchBatchData(justWatchDataForBatch));
      return justWatchDataForBatch;
    })
    .catch(reason => {
      console.log(reason);
    });
};

const fetchBechdelDataForBatch = (dispatch, batch) => {
  dispatch(requestBechdelBatchData(batch));
  return Promise
    .all(batch.map(movie => performBechdelApiRequest(movie.id)))
    .then(responses => {
      dispatch(
        receiveBechdelBatchData(reduceListToMap(responses, 'imdbId', 'bechdel'))
      );
    })
    .catch(reason => {
      console.log(reason);
    });
};

const fetchConfirmNetflixDataForBatch = (dispatch, justWatchDataForBatch) => {
  dispatch(requestConfirmNetflixBatchData(justWatchDataForBatch));
  return Promise
    .all(
      Object
        .entries(justWatchDataForBatch)
        .filter(
          ([ imdbId, justwatchData ]) => justwatchData.streamability.netflix
        )
        .map(
          ([ imdbId, justwatchData ]) =>
            performConfirmNetflixApiRequest(
              imdbId,
              justwatchData.streamability.netflix
            )
        )
    )
    .then(responses => {
      const cleanedResponses = responses.map(response => {
        return { id: response.imdbId, data: { netflix: response.netflix } };
      });
      const netflixDataForBatch = reduceListToMap(
        cleanedResponses,
        'id',
        'data'
      );

      dispatch(receiveConfirmNetflixBatchData(netflixDataForBatch));
      return netflixDataForBatch;
    })
    .catch(reason => {
      console.log(reason);
    });
};

export const fetchWatchlistData = userId => {
  return dispatch => {
    dispatch(requestWatchlistData(userId));

    fetch('/api/watchlist', {
      method: 'POST',
      body: JSON.stringify({ userId }),
      headers: {
        Accept: 'application/json, text/plain, */*',
        'Content-Type': 'application/json'
      }
    })
      .then(response => {
        return response.json();
      })
      .then(json => {
        dispatch(receiveWatchlistData(userId, json.list));

        const batches = splitIntoBatches(json.list.movies, 50);

        batches.forEach(batch => {
          fetchJustWatchDataForBatch(
            dispatch,
            batch
          ).then(justWatchDataForBatch => {
            fetchConfirmNetflixDataForBatch(dispatch, justWatchDataForBatch);
          });

          fetchBechdelDataForBatch(dispatch, batch).then(() => {
          });
        });
      });
  };
};
