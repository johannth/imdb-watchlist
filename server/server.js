import express from 'express';
import fetch from 'node-fetch';
import cheerio from 'cheerio';
import bodyParser from 'body-parser';

const app = express();

app.use(bodyParser.json());

app.post('/api', (req, res) => {
  fetch(`http://www.imdb.com/user/${req.body.userId}/watchlist?view=detail`)
    .then(response => response.text())
    .then(text => {
      const initialStateRegex = /IMDbReactInitialState\.push\((\{.+\})\);/g;
      const matches = initialStateRegex.exec(text);
      const initialStateText = matches[1];

      const watchlistData = JSON.parse(initialStateText);

      const list = { id: watchlistData.list.id, name: watchlistData.list.name };

      const movieIds = watchlistData.list.items.map(i => i.const);

      return fetch(
        `http://www.imdb.com/title/data?ids=${movieIds.join(
          ','
        )}&pageId=${list.id}&pageType=list&subpageType=watchlist`
      )
        .then(response => response.json())
        .then(movieData => {
          const movies = movieIds.map(movieId => movieData[movieId]);

          res.json({ list, movies });
        });
    });
});

app.listen(3001, () => {
  console.log('App listening on port 3001!');
});
