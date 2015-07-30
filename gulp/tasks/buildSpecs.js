'use strict';

var wiredep = require('wiredep').stream;
var inject = require('../utils/inject');
var log = require('../utils/log');

module.exports = function(gulp, options) {
  var config = require('../config')[options.key || 'buildSpecs'];

  return task;

  function task() {
    if (options.verbose) {
      log('Building the spec runner');
    }

    var specs = config.specs;

    if (options.startServers) {
      specs = [].concat(specs, config.serverIntegrationSpecs);
    }

    return gulp.src(config.index)
      .pipe(wiredep(config.options))
      .pipe(inject(config.files, '', config.order))
      .pipe(inject(config.testLibraries, 'testlibraries'))
      .pipe(inject(config.specHelpers, 'spechelpers'))
      .pipe(inject(specs, 'specs', ['**/*']))
      .pipe(inject(config.templateCache, 'templates'))
      .pipe(gulp.dest(config.build));
  }
};
