'use strict';

var del = require('del');
var log = require('../utils/log');
var notify = require('../utils/notify');

module.exports = function(gulp, options) {
  var config = require('../config')[options.key || 'build'];

  return task;

  function task() {
    log('Building everything');

    var msg = {
      title: 'gulp build',
      subtitle: 'Deployed to the build folder',
      message: 'Application built successfully'
    };
    del(config.clean);
    log(msg);
    notify(msg);
  }
};
