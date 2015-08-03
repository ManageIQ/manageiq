'use strict';

var gIf = require('gulp-if');
var order = require('gulp-order');
var gulp = require('gulp');

/**
 * Order a stream
 * @param   {Stream} src   The gulp.src stream
 * @param   {Array} ordering Glob array pattern
 * @returns {Stream} The ordered stream
 */
module.exports = function(src, ordering) {
  return gulp.src(src)
    .pipe(gIf(ordering, order(ordering)));
};
