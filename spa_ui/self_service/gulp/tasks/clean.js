'use strict';

var clean = require('../utils/clean');

module.exports = function(gulp, options) {
  var config = require('../config')[options.key || 'clean'];

  return task;

  function task(done) {
    clean(config.src, done);
  }
};
