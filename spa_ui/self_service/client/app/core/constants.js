/* global toastr:false, moment:false, _:false, $:false */
(function() {
  'use strict';

  angular.module('app.core')
    .constant('lodash', _)
    .constant('jQuery', $)
    .constant('toastr', toastr)
    .constant('moment', moment);
})();
