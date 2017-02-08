import React from 'react';
import ReactDOM from 'react-dom';
import { Provider } from 'react-redux';

import { createStore, applyMiddleware } from 'redux';
import thunkMiddleware from 'redux-thunk';
import createLogger from 'redux-logger';

import App from './App';
import rootReducer from './reducers';
import { fetchWatchlistData } from './actions';
import './index.css';

import { IMDB_ID } from './constants';

const loggerMiddleware = createLogger();

let store = createStore(
  rootReducer,
  applyMiddleware(thunkMiddleware, loggerMiddleware)
);

ReactDOM.render(
  <Provider store={store}><App /></Provider>,
  document.getElementById('root')
);

store.dispatch(fetchWatchlistData(IMDB_ID));
