'use strict';

var notifier = require('node-notifier');
var _ = require('lodash');

/**
 * Show OS level notification using node-notifier
 */
module.exports = function(options) {
  var notifyOptions = {
    sound: 'Bottle',
    contentImage: 'gulp.png',
    icon: 'gulp.png'
  };
  _.assign(notifyOptions, options);
  notifier.notify(notifyOptions);
};
