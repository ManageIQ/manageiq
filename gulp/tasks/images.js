'use strict';

var log = require('../utils/log');
var imagemin = require('gulp-imagemin');
var gIf = require('gulp-if');

module.exports = function(gulp, options) {
  var config = require('../config')[options.key || 'images'];

  return task;

  function task() {
    if (options.verbose) {
      log('Compressing, caching, and copying images');
    }

    return gulp.src(config.src)
      .pipe(gIf(options.minify, imagemin(config.options)))
      .pipe(gulp.dest(config.build));
  }
};
