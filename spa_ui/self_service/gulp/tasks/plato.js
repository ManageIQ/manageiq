'use strict';

var glob = require('glob');
var plato = require('plato');
var log = require('../utils/log');

module.exports = function(gulp, options) {
  var config = require('../config')[options.key || 'plato'];

  return task;

  function task(done) {
    var files = glob.sync(config.src);
    var outputDir = config.output;

    if (options.verbose) {
      log('Analyzing source with Plato');
      log('Browse to /report/plato/index.html to see Plato results');
    }

    plato.inspect(files, outputDir, config.options, platoCompleted);

    function platoCompleted(report) {
      var overview = plato.getOverviewReport(report);

      if (options.verbose) {
        log(overview.summary);
      }

      done();
    }
  }
};
