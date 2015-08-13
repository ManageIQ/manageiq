'use strict';

var useref = require('gulp-useref');
var filter = require('gulp-filter');
var plumber = require('gulp-plumber');
var csso = require('gulp-csso');
var ngAnnotate = require('gulp-ng-annotate');
var uglify = require('gulp-uglify');
var rev = require('gulp-rev');
var revReplace = require('gulp-rev-replace');
var getHeader = require('../utils/getHeader');
var inject = require('../utils/inject');
var log = require('../utils/log');

module.exports = function(gulp, options) {
  var config = require('../config')[options.key || 'optimize'];

  return task;

  function task() {
    if (options.verbose) {
      log('Optimizing the js, css, and html');
    }

    var assets = useref.assets({searchPath: './'});

    // Filters are named for the gulp-useref path
    var cssFilter = filter(config.cssFilter);
    var jsAppFilter = filter(config.appJsFilter);
    var jslibFilter = filter(config.libJsFilter);

    return gulp.src(config.index)
      .pipe(plumber())
      .pipe(inject(config.templateCache, 'templates'))
      .pipe(assets) // Gather all assets from the html with useref
      // Get the css
      .pipe(cssFilter)
      .pipe(csso())
      .pipe(cssFilter.restore())
      // Get the custom javascript
      .pipe(jsAppFilter)
      .pipe(ngAnnotate(config.ngAnnotateOptions))
      .pipe(uglify())
      .pipe(getHeader())
      .pipe(jsAppFilter.restore())
      // Get the vendor javascript
      .pipe(jslibFilter)
      .pipe(uglify()) // another option is to override wiredep to use min files
      .pipe(jslibFilter.restore())
      // Take inventory of the file names for future rev numbers
      .pipe(rev())
      // Apply the concat and file replacement with useref
      .pipe(assets.restore())
      .pipe(useref())
      // Replace the file names in the html with rev numbers
      .pipe(revReplace())
      .pipe(gulp.dest(config.build));
  }
};
