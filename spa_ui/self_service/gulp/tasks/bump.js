'use strict';

var print = require('gulp-print');
var bump = require('gulp-bump');
var log = require('../utils/log');

module.exports = function(gulp, options) {
  var config = require('../config')[options.key || 'bump'];

  return task;

  function task() {
    var msg = 'Bumping versions';
    var type = options.type;
    var version = options.version;
    var bumpOptions = {};

    if (version) {
      bumpOptions.version = version;
      msg += ' to ' + version;
    } else {
      bumpOptions.type = type;
      msg += ' for a ' + type;
    }

    if (options.verbose) {
      log(msg);
    }

    return gulp.src(config.packages)
      .pipe(print())
      .pipe(bump(bumpOptions))
      .pipe(gulp.dest(config.root));
  }
};
