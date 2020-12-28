const path = require('path');
const webpack = require('webpack');

// const MODE = 'development';

module.exports = {
  // mode: MODE,
  entry: {
    popup: './src/popup',
    script: './src/script',
    background: './src/background',
    app: './src/main',
  },
  output: {
    filename: '[name].js',
    path: path.resolve(__dirname, 'dist'),
  },
  module: {
    rules: [
      {
        test: /\.coffee$/,
        loader: 'coffee-loader',
      },
    ],
  },
  resolve: {
    extensions: ['.js', '.coffee'],
  },
  plugins: [
    new webpack.ProvidePlugin({
      $: 'jquery',
      jQuery: 'jquery',
    })
  ],
  cache: true,
};
