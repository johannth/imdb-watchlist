export const REQUEST_WATCHLIST_DATA = 'REQUEST_WATCHLIST_DATA';
const requestWatchlistData = userId => {
  return { type: REQUEST_WATCHLIST_DATA, userId };
};

export const RECEIVE_WATCHLIST_DATA = 'RECEIVE_WATCHLIST_DATA';
const receiveWatchlistData = (userId, movies) => {
  return { type: RECEIVE_WATCHLIST_DATA, userId, movies };
};

export const fetchWatchlistData = userId => {
  return dispatch => {
    dispatch(requestWatchlistData(userId));

    fetch('/api', {
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
        dispatch(receiveWatchlistData(userId, []));
      });
  };
};
