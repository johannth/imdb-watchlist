var path = require('path');
var webpack = require('webpack');
var merge = require('webpack-merge');
var HtmlWebpackPlugin = require('html-webpack-plugin');
var ExtractTextPlugin = require('extract-text-webpack-plugin');
var child_process = require('child_process');

var TIER = process.env.TIER || "development";

let gitVersion = child_process.execSync('git rev-parse HEAD', {encoding: 'utf8'});

var commonConfig = {
  output: {
    path: path.resolve(__dirname, 'dist/'),
    filename: '[hash].js',
  },

  resolve: {
    modulesDirectories: ['node_modules'],
    extensions: ['', '.js', '.elm']
  },

  plugins: [
    new HtmlWebpackPlugin({
      template: 'src/static/index.html',
      inject: 'body',
      filename: 'index.html'
    }),
    new webpack.DefinePlugin({
        BUILD_TIME: JSON.stringify(new Date()),
        BUILD_VERSION: JSON.stringify(gitVersion),
        BUILD_TIER: JSON.stringify(TIER),
    })
  ],

  postcss: [
    require('autoprefixer')
  ],
}

if (TIER === 'development') {
  console.log('Serving locally...');

  module.exports = merge(commonConfig, {
    entry: [
      'webpack-dev-server/client?http://localhost:8080',
      path.join( __dirname, 'src/static/index.js' )
    ],

    devServer: {
      inline: true,
      progress: true
    },

    module: {
      loaders: [
        {
          test: /\.elm$/,
          exclude: [/elm-stuff/, /node_modules/],
          loader: 'elm-hot!elm-webpack?verbose=true&warn=true&debug=true'
        },
        {
          test: /\.css$/,
          loaders: [
            'style-loader',
            'css-loader',
            'postcss-loader'
          ]
        }
      ]
    }
  });
}

if (TIER === "production") {
  module.exports = merge(commonConfig, {
    entry: [
      path.join( __dirname, 'src/static/index.js' )
    ],

    module: {
      loaders: [
        {
          test: /\.elm$/,
          exclude: [/elm-stuff/, /node_modules/],
          loader: 'elm-webpack'
        },
        {
          test: /\.css$/,
          loader: ExtractTextPlugin.extract('style-loader', [
            'css-loader',
            'postcss-loader'
          ])
        }
      ]
    },

    plugins: [
      new ExtractTextPlugin('./[hash].css'),

      new webpack.optimize.OccurrenceOrderPlugin(),

      new webpack.optimize.UglifyJsPlugin({
          minimize:   true,
          compressor: { warnings: false }
      })
    ]
  });
}
