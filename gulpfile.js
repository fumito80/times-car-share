const fs = require('fs');
const path = require('path');

const { series } = require('gulp');
const webpack = require('webpack');
const archiver = require('archiver');

const config = require('./webpack.config.js');

async function build(mode) {
  return new Promise((resolve) => {
    webpack({ ...config, mode })
      .run((err, stats) => {
        if (err) {
          throw new Error(err);
        }
        console.log(stats.toString({ colors: true }));
        resolve();
      });
  });
}

async function archive() {
  const zip = archiver('zip', {
    zlib: { level: 6 }, // Sets the compression level.
  });
  zip.directory('dist/', false);
  zip.finalize();
  const output = fs.createWriteStream(path.resolve(__dirname, 'times.zip'));
  return new Promise((resolve) => {
    output.on('close', resolve);
    zip.pipe(output);
  });
}

function dev() {
  return build('development');
}

function production() {
  return build('production');
}

const prd = series(
  production,
  archive,
);

exports.archive = archive;
exports.prd = prd;
exports.default = dev;
