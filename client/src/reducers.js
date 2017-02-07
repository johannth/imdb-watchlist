import { combineReducers } from 'redux';

import { reducer as sematableReducer } from 'sematable';

const appReducer = (state = {}, action) => {
  return state;
};

export const rootReducer = combineReducers({
  sematable: sematableReducer,
  appReducer
});
export default rootReducer;
