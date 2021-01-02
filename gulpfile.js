const fs = require('fs');
const path = require('path');

const { series } = require('gulp');
const webpack = require('webpack');
const archiver = require('archiver');

const config = require('./webpack.config.js');

function build(mode) {
  return async function build() {
    return new Promise((resolve) => {
      webpack({ ...config, mode })
        .run((err, stats) => {
          if (err) {
            throw new Error(err);
          }
          console.info(stats.toString({ colors: true }));
          resolve();
        });
    });
  }
}

async function archive() {
  const zip = archiver('zip', {
    zlib: { level: 6 }, // Sets the compression level.
  });
  zip.directory('dist/', false);
  zip.finalize();
  const manifest = fs.readFileSync(path.resolve(__dirname, 'dist/manifest.json'));
  const { version } = JSON.parse(manifest);
  const output = fs.createWriteStream(path.resolve(__dirname, `zips/v${version}.zip`));
  return new Promise((resolve) => {
    output.on('close', resolve);
    zip.pipe(output);
  });
}

const dev = series(
  build('development'),
);

const prd = series(
  build('production'),
  archive,
);

exports.prd = prd;
exports.default = dev;
