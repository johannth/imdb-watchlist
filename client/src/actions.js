export const REQUEST_WATCHLIST_DATA = 'REQUEST_WATCHLIST_DATA';
const requestWatchlistData = userId => {
  return { type: REQUEST_WATCHLIST_DATA, userId };
};

export const RECEIVE_WATCHLIST_DATA = 'RECEIVE_WATCHLIST_DATA';
const receiveWatchlistData = (userId, list) => {
  return { type: RECEIVE_WATCHLIST_DATA, userId, list };
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

        const batches = json.list.movies.reduce(
          (accumulator, movie) => {
            const latestPage = accumulator[accumulator.length - 1] || [];
            if (latestPage.length >= 50) {
              accumulator.push([ movie ]);
            } else {
              latestPage.push(movie);
            }
            return accumulator;
          },
          [ [] ]
        );

        batches.forEach(batch => {
          dispatch(requestJustWatchBatchData(batch));
          Promise
            .all(
              batch.map(
                movie =>
                  performJustWatchApiRequest(movie.id, movie.primary.title)
              )
            )
            .then(responses => {
              dispatch(
                receiveJustWatchBatchData(
                  responses.reduce(
                    (accumulator, item) => {
                      accumulator[item.imdbId] = item.justwatch;
                      return accumulator;
                    },
                    {}
                  )
                )
              );
            })
            .catch(reason => {
              console.log(reason);
            });
        });
      });
  };
};

export const REQUEST_JUSTWATCH_BATCH_DATA = 'REQUEST_JUSTWATCH_BATCH_DATA';
const requestJustWatchBatchData = batch => {
  return { type: REQUEST_JUSTWATCH_BATCH_DATA, batch };
};

export const RECEIVE_JUSTWATCH_BATCH_DATA = 'RECEIVE_JUSTWATCH_BATCH_DATA';
const receiveJustWatchBatchData = batch => {
  return { type: RECEIVE_JUSTWATCH_BATCH_DATA, batch };
};

const handleErrors = response => {
  if (!response.ok) {
    throw Error(response.statusText);
  }
  return response;
};

export const performJustWatchApiRequest = (imdbId, title) => {
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