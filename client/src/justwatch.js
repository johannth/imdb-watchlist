const JUSTWATCH_ITUNES_PROVIDER_ID = 2;
const JUSTWATCH_NETFLIX_PROVIDER_ID = 8;
const JUSTWATCH_AMAZON_PROVIDER_ID = 10;
const JUSTWATCH_HBO_PROVIDER_ID = 27;

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

const extractOffer = (justwatch, providerId) => {
  // eslint-disable-next-line no-mixed-operators
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

export const extractJustWatchDataFromResponse = response => {
  return {
    netflix: extractOffer(response, JUSTWATCH_NETFLIX_PROVIDER_ID),
    itunes: extractOffer(response, JUSTWATCH_ITUNES_PROVIDER_ID),
    amazon: extractOffer(response, JUSTWATCH_AMAZON_PROVIDER_ID),
    hbo: extractOffer(response, JUSTWATCH_HBO_PROVIDER_ID)
  };
};
