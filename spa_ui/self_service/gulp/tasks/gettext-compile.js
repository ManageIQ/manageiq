'use strict';

var gettext = require('gulp-angular-gettext');
var log = require('../utils/log');

module.exports = function(gulp, options) {
  var config = require('../config')[options.key || 'gettextCompile'];

  return task;

  function task() {
    if (options.verbose) {
      log('Compiling gettext translations (po -> js)');
    }

    return gulp.src(config.inputs)
      .pipe(gettext.compile(config.compilerOptions))
      .pipe(gulp.dest(config.outputDir));
  }
};
