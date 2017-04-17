import fetch from 'node-fetch';
import leven from 'leven';
import { viewingOptionData } from './models';
import { handleErrors } from './utils';

const findBestPossibleJustwatchResult = (title, year, type, results) => {
  if (!results) {
    return null;
  }

  return results.filter((result) => {
    const titleMatch = leven(result.title.toLowerCase(), title.toLowerCase());
    const titleAndYearMatch = titleMatch === 0 && result.original_release_year === year;
    const fuzzyTitleAndYearMatch = titleMatch <= 5 && result.original_release_year === year;
    const titleMatchesForSeries = titleMatch === 0 && type === 'series';
    return titleAndYearMatch || fuzzyTitleAndYearMatch || titleMatchesForSeries;
  })[0];
};

const justwatchType = (itemType) => {
  switch (itemType) {
    case 'film':
      return 'movie';
    case 'series':
      return 'show';
  }
};

const justWatchProviders = {
  2: 'itunes',
  8: 'netflix',
  10: 'amazon',
  27: 'hbo',
};

const extractBestViewingOption = (provider, viewingOptions) => {
  const viewingOptionsByProvider = viewingOptions.filter(
    viewingOption => viewingOption.provider === provider,
  );

  viewingOptionsByProvider.sort((viewingOptionA, viewingOptionB) => {
    const ordinalA = viewingOptionOrdinal(viewingOptionA);
    const ordinalB = viewingOptionOrdinal(viewingOptionB);

    for (var i = 0; i !== ordinalA.length; i++) {
      const result = ordinalA[i] - ordinalB[i];
      if (result !== 0) {
        return result;
      }
    }
    return 0;
  });

  return viewingOptionsByProvider[0] || null;
};

const viewingOptionOrdinal = (viewingOption) => {
  const presentationTypeOrdinal = viewingOption.presentationType === 'hd' ? 0 : 1;
  switch (viewingOption.monetizationType) {
    case 'flatrate':
      return [0, presentationTypeOrdinal, 0];
    case 'rent':
      return [1, presentationTypeOrdinal, viewingOption.price];
    case 'buy':
      return [2, presentationTypeOrdinal, viewingOption.price];
  }
};

export const fetchJustWatchData = (imdbId, title, type, releaseDateTimestamp) => {
  const releaseDate = new Date(releaseDateTimestamp);
  const year = releaseDate.getFullYear();
  return fetch('https://api.justwatch.com/titles/en_US/popular', {
    method: 'POST',
    body: JSON.stringify({
      content_types: [justwatchType(type)],
      query: title,
    }),
    headers: {
      Accept: 'application/json, text/plain, */*',
      'Content-Type': 'application/json',
    },
  })
    .then(handleErrors)
    .then(response => response.json())
    .then((json) => {
      const possibleItem = findBestPossibleJustwatchResult(title, year, type, json.items);

      if (!possibleItem) {
        throw Error(`${imdbId}: ${title} was not found at JustWatch`);
      }

      const item = possibleItem;

      const offers = item.offers || [];

      const viewingOptions = offers.map((offer) => {
        const provider = justWatchProviders[offer.provider_id];
        return viewingOptionData({
          provider,
          url: offer.urls.standard_web,
          monetizationType: offer.monetization_type,
          presentationType: offer.presentation_type,
          price: offer.retail_price,
        });
      });

      const netflix = extractBestViewingOption('netflix', viewingOptions);
      const amazon = extractBestViewingOption('amazon', viewingOptions);
      const hbo = extractBestViewingOption('hbo', viewingOptions);
      const itunes = extractBestViewingOption('itunes', viewingOptions);

      const scoring = item.scoring;

      const rottenTomatoesMeter = scoring
        .filter(score => score.provider_type === 'tomato:meter')
        .map(score => score.value)[0];

      return {
        viewingOptions: {
          netflix,
          amazon,
          hbo,
          itunes,
        },
        ratings: {
          rottenTomatoesMeter,
        },
      };
    });
};
