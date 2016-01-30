'use strict';

var log = require('../utils/log');

module.exports = function(gulp, options) {
  var config = require('../config')[options.key || 'gettextCopy'];

  return task;

  function task() {
    if (options.verbose) {
      log('Copying gettext JSON files to build dir');
    }

    return gulp.src(config.inputs)
      .pipe(gulp.dest(config.outputDir));
  }
};
