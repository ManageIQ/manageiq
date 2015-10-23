(function() {
  'use strict';

  angular.module('app.components')
    .directive('dialogContent', DialogContentDirective);

  /** @ngInject */
  function DialogContentDirective() {
    var directive = {
      restrict: 'AE',
      replace: true,
      scope: {
        dialog: '=',
        options: '=?',
        inputDisabled: '=?'
      },
      link: link,
      templateUrl: 'app/components/dialog-content/dialog-content.html',
      controller: DialogContentController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function DialogContentController() {
      var vm = this;
      vm.parsedOptions = {};
      vm.activate = activate;
      vm.dateOptions = {
        autoclose: true,
        todayBtn: 'linked',
        todayHighlight: true
      };

      function activate() {
        if (vm.options) {
          angular.forEach(vm.options, parseOptions);
        }
        function parseOptions(value, key) {
          vm.parsedOptions[key.replace('dialog_', '')] = value;
        }
      }
    }
  }
})();
