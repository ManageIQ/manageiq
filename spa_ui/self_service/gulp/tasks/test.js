'use strict';

var fork = require('child_process').fork;
var Server = require('karma').Server;
var log = require('../utils/log');

module.exports = function(gulp, options) {
  var config = require('../config')[options.key || 'test'];

  return task;

  function task(cb) {
    test(options.singleRun, cb);
  }

  /**
   * Start the tests using karma.
   * @param {boolean} singleRun - True means run once and end (CI), or keep running (dev)
   * @param {Function} done - Callback to fire when karma is done
   * @return {undefined}
   */
  function test(singleRun, done) {
    var child;
    var excludeFiles = [];
    var serverSpecs = config.serverIntegrationSpecs;

    if (options.startServers) {
      if (options.verbose) {
        log('Starting servers');
      }
      var savedEnv = process.env;
      savedEnv.NODE_ENV = config.serverEnv;
      savedEnv.PORT = config.serverPort;
      child = fork(config.serverApp);
    } else {
      if (serverSpecs && serverSpecs.length) {
        excludeFiles = serverSpecs;
      }
    }

    new Server({
      configFile: config.confFile,
      exclude: excludeFiles,
      singleRun: !!singleRun
    }, karmaCompleted).start();

    function karmaCompleted(karmaResult) {
      if (options.verbose) {
        log('Karma completed');
      }
      if (child) {
        log('shutting down the child process');
        child.kill();
      }
      if (karmaResult === 1) {
        done('karma: tests failed with code ' + karmaResult);
      } else {
        done();
      }
    }
  }
};
