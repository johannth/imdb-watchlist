import fetch from 'node-fetch';
import { handleErrors } from './utils';

export const fetchBechdel = imdbId => {
  const imdbIdWithoutPrefix = imdbId.replace('tt', '');

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
        return { rating: parseInt(json.rating), dubious: json.dubious === '1' };
      } else {
        return null;
      }
    });
};
