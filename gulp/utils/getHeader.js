'use strict';

var header = require('gulp-header');

/**
 * Format and return the header for files
 * @return {String}           Formatted file header
 */
module.exports = function() {
  var pkg = require('../../package.json');
  var template = [
    '/**',
    ' * <%= pkg.name %> - <%= pkg.description %>',
    ' * @authors <%= pkg.authors %>',
    ' * @version v<%= pkg.version %>',
    ' * @link <%= pkg.homepage %>',
    ' * @license <%= pkg.license %>',
    ' */',
    ''
  ].join('\n');

  return header(template, {
    pkg: pkg
  });
};
