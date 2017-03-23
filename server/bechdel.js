import fetch from 'node-fetch';
import PromiseThrottle from 'promise-throttle';

import { handleErrors } from './utils';

const promiseThrottle = new PromiseThrottle({
  requestsPerSecond: 10,
  promiseImplementation: Promise,
});

export const fetchBechdel = imdbId => {
  const imdbIdWithoutPrefix = imdbId.replace('tt', '');

  const startRequest = () => {
    return fetch(
      `http://bechdeltest.com/api/v1/getMovieByImdbId?imdbid=${imdbIdWithoutPrefix}`,
      {
        method: 'GET',
        headers: {
          Accept: 'application/json, text/plain, */*',
          'Content-Type': 'application/json',
        },
      }
    )
      .then(handleErrors)
      .then(response => response.json())
      .then(json => {
        if (!json.status) {
          return {
            rating: parseInt(json.rating),
            dubious: json.dubious === '1',
          };
        } else {
          return null;
        }
      });
  };

  return promiseThrottle.add(startRequest);
};
