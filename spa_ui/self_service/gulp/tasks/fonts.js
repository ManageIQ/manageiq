'use strict';

var log = require('../utils/log');

module.exports = function(gulp, options) {
  var config = require('../config')[options.key || 'fonts'];

  return task;

  function task() {
    if (options.verbose) {
      log('Copying fonts');
    }

    return gulp.src(config.src)
      .pipe(gulp.dest(config.build));
  }
};
