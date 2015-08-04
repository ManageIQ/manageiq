'use strict';

var log = require('./log');
var del = require('del');

/**
 * Delete all files in a given path
 * @param  {Array}   path - array of paths to delete
 * @param  {Function} done - callback when complete
 */
function clean(path, done) {
  log('Cleaning: ' + path);
  del(path, done);
}

module.exports = clean;
