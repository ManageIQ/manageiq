(function() {
  'use strict';

  angular.module('app.services')
    .factory('Polling', PollingFactory);

  /** @ngInject */
  function PollingFactory($interval, lodash) {
    var service = {
      start: start,
      stop: stop,
      stopAll: stopAll
    };

    var polls = {};

    return service;

    function start(key, func, interval, limit) {
      var poll;

      if (!polls[key]) {
        poll = $interval(func, interval, limit);
        polls[key] = poll;
      }
    }

    function stop(key) {
      if (polls[key]) {
        $interval.cancel(polls[key]);
        delete polls[key];
      }
    }

    function stopAll() {
      angular.forEach(lodash.keys(polls), stop);
    }
  }
})();
