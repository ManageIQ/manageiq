'use strict';

var jshint = require('gulp-jshint');
var log = require('../utils/log');

module.exports = function(gulp, options) {
  var config = require('../config')[options.key || 'jshint'];

  return task;

  function task() {
    if (options.verbose) {
      log('Running JSHint');
    }

    return gulp.src(config.src)
      .pipe(jshint(config.rcFile))
      .pipe(jshint.reporter(config.reporter, config.options))
      .pipe(jshint.reporter('fail'));
  }
};
