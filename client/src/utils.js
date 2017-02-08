export const handleErrors = response => {
  if (!response.ok) {
    throw Error(response.statusText);
  }
  return response;
};

export const reduceListToObject = (list, keyPath, itemPath) => {
  return list.reduce(
    (accumulator, item) => {
      accumulator[item[keyPath]] = item[itemPath];
      return accumulator;
    },
    {}
  );
};

export const splitIntoBatches = (list, pageSize) => {
  return list.reduce(
    (accumulator, item) => {
      const latestBatch = accumulator[accumulator.length - 1] || [];
      if (latestBatch.length >= pageSize) {
        accumulator.push([ item ]);
      } else {
        latestBatch.push(item);
      }
      return accumulator;
    },
    [ [] ]
  );
};
