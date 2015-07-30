(function() {
  'use strict';

  angular.module('app.components')
    .directive('footer', FooterDirective);

  /** @ngInject */
  function FooterDirective() {
    var directive = {
      restrict: 'AE',
      templateUrl: 'app/components/footer/footer.html'
    };

    return directive;
  }
})();
