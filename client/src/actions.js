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
        json.list.movies.forEach(
          movie => dispatch(fetchJustWatchData(movie.id, movie.primary.title))
        );
      });
  };
};

export const REQUEST_JUSTWATCH_DATA = 'REQUEST_JUSTWATCH_DATA';
const requestJustWatchData = (imdbId, title) => {
  return { type: REQUEST_JUSTWATCH_DATA, imdbId, title };
};

export const RECEIVE_JUSTWATCH_DATA = 'RECEIVE_JUSTWATCH_DATA';
const receiveJustWatchData = (imdbId, title, data) => {
  return { type: RECEIVE_JUSTWATCH_DATA, imdbId, title, data };
};

export const fetchJustWatchData = (imdbId, title) => {
  return dispatch => {
    dispatch(requestJustWatchData(imdbId, title));

    fetch('/api/justwatch', {
      method: 'POST',
      body: JSON.stringify({ imdbId, title }),
      headers: {
        Accept: 'application/json, text/plain, */*',
        'Content-Type': 'application/json'
      }
    })
      .then(response => {
        return response.json();
      })
      .then(json => {
        dispatch(receiveJustWatchData(imdbId, title, json.item));
      });
  };
};
