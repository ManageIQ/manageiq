'use strict';

var jscs = require('gulp-jscs');
var log = require('../utils/log');

module.exports = function(gulp, options) {
  var config = require('../config')[options.key || 'jscs'];

  return task;

  function task() {
    if (options.verbose) {
      log('Running JSCS');
    }

    return gulp.src(config.src)
      .pipe(jscs(config.rcFile));
  }
};
