'use strict';

var inject = require('../utils/inject');
var log = require('../utils/log');

module.exports = function(gulp, options) {
  var config = require('../config')[options.key || 'inject'];

  return task;

  function task() {
    if (options.verbose) {
      log('Wire up css into the html, after files are ready');
    }

    return gulp.src(config.index)
      .pipe(inject(config.css))
      .pipe(gulp.dest(config.build));
  }
};
