'use strict';

var gettext = require('gulp-angular-gettext');
var log = require('../utils/log');

module.exports = function(gulp, options) {
  var config = require('../config')[options.key || 'gettextExtract'];

  return task;

  function task() {
    if (options.verbose) {
      log('Extracting gettext translations (* -> po)');
    }

    return gulp.src(config.inputs)
      .pipe(gettext.extract(config.potFile, config.extractorOptions))
      .pipe(gulp.dest(config.outputDir));
  }
};
