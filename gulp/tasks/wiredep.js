'use strict';

var wiredep = require('wiredep').stream;
var log = require('../utils/log');
var inject = require('../utils/inject');

module.exports = function(gulp, options) {
  var config = require('../config')[options.key || 'wiredep'];

  return task;

  function task() {
    if (options.verbose) {
      log('Wiring the bower dependencies into the html');
    }

    return gulp.src(config.index)
      .pipe(wiredep(config.options))
      .pipe(inject(config.files, '', config.order))
      .pipe(gulp.dest(config.build));
  }
};
