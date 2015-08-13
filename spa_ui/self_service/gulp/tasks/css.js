'use strict';

var minifyCss = require('gulp-minify-css');
var byteDiffFormatter = require('../utils/byteDiffFormatter');
var bytediff = require('gulp-bytediff');
var concat = require('gulp-concat');
var noop = require('gulp-util').noop;

module.exports = function(gulp, options) {
  var config = require('../config')[options.key || 'css'];

  return task;

  function task() {
    return gulp.src(config.src)
      .pipe(concat(config.output))
      .pipe(options.verbose ? bytediff.start() : noop())
      .pipe(minifyCss({}))
      .pipe(options.verbose ? bytediff.stop(byteDiffFormatter) : noop())
      .pipe(gulp.dest(config.build));
  }
};
