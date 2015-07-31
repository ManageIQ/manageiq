'use strict';

var byteDiffFormatter = require('../utils/byteDiffFormatter');
var bytediff = require('gulp-bytediff');
var minifyHtml = require('gulp-minify-html');
var angularTemplatecache = require('gulp-angular-templatecache');
var gIf = require('gulp-if');
var log = require('../utils/log');

module.exports = function(gulp, options) {
  var config = require('../config')[options.key || 'templatecache'];

  return task;

  function task() {
    if (options.verbose) {
      log('Creating an AngularJS $templateCache');
    }

    return gulp.src(config.src)
      .pipe(gIf(options.verbose, bytediff.start()))
      .pipe(minifyHtml(config.minifyOptions))
      .pipe(gIf(options.verbose, bytediff.stop(byteDiffFormatter)))
      .pipe(angularTemplatecache(config.output, config.templateOptions))
      .pipe(gulp.dest(config.build));
  }
};
