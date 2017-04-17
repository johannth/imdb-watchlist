import fetch from 'node-fetch';
import request from 'request';
import PromiseThrottle from 'promise-throttle';
import { handleErrors } from './utils';

const promiseThrottle = new PromiseThrottle({
  requestsPerSecond: 10,
  promiseImplementation: Promise,
});

export const checkIfMovieIsOnLocalNetflix = (imdbId, title, locale) => {
  const locales = {
    is: 'denmark',
    de: 'germany',
  };

  const startRequest = () =>
    fetch(
      `http://${locales[locale]}.flixlist.co/autocomplete/titles?q=${encodeURIComponent(title)}`,
    )
      .then(handleErrors)
      .then(response => response.json())
      .then((json) => {
        if (!json.filter) {
          throw Error(`${imdbId}: ${title} was not found on '${locale}' Netflix`);
        }

        const possibleNetflixId = json
          .filter(
            result => result.title === title, // This missing a check for year but it still much better than nothing.
          )
          .map(result => result.url.replace('/titles/', ''))[0];

        if (!possibleNetflixId) {
          throw Error(`${imdbId}: ${title} was not found on '${locale}' Netflix`);
        }

        return doubleCheckIfMovieIsOnLocaleNetflix(
          imdbId,
          `https://www.netflix.com/title/${possibleNetflixId}`,
          locale,
        ).then((netflixUrl) => {
          if (!netflixUrl) {
            throw Error(`${imdbId}: ${title} was not found on '${locale}' Netflix`);
          }
          return { netflixUrl };
        });
      });

  return promiseThrottle.add(startRequest);
};

const doubleCheckIfMovieIsOnLocaleNetflix = (imdbId, netflixUrl, locale) => {
  const netflixUrlInLocale = netflixUrl.replace('/title/', `/${locale}/title/`);
  const netflixUrlInLocaleAlternative = netflixUrl.replace('/title/', `/${locale}-en/title/`);

  return new Promise((resolve, reject) => {
    request({ method: 'GET', followRedirect: false, url: netflixUrl }, (error, response, body) => {
      const locationHeader = response.headers.location;
      console.log(
        `/api/netflix ${imdbId}: Netflix returned ${response.statusCode} on ${netflixUrl} with location ${locationHeader}`,
      );

      resolve(
        response.statusCode == 200 ||
          locationHeader === netflixUrlInLocale ||
          locationHeader === netflixUrlInLocaleAlternative
          ? netflixUrlInLocale
          : null,
      );
    });
  });
};
