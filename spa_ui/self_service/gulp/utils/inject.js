'use strict';

var inject = require('gulp-inject');
var order = require('./order');

/**
 * Inject files in a sorted sequence at a specified inject label
 * @param   {Array} src   glob pattern for source files
 * @param   {String} [label]   The label name
 * @param   {Array} [order]   glob pattern for sort order of the files
 * @returns {Stream}   The stream
 */
module.exports = function(src, label, ordering) {
  var options = {
    read: false
  };

  if (label) {
    options.name = 'inject:' + label;
  }

  return inject(order(src, ordering), options);
};
