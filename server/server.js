import express from 'express';

const app = express();

app.get('/api', (req, res) => {
  res.json({ testing: false });
});

app.listen(3001, () => {
  console.log('App listening on port 3001!');
});
// const initialStateRegex = /IMDbReactInitialState.push\((\{.+\})\)/;
// const $ = cheerio.load(text);
// console.log(text);
// const initialStateScript = $('span.ab_widget').length;
// console.log(initialStateScript);
// const initialStateText = initialStateScript.match(initialStateRegex);
// console.log(initialStateScript, initialStateText);
