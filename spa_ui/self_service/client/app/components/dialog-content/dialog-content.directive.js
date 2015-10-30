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
    function DialogContentController(API_BASE, lodash) {
      var vm = this;
      vm.parsedOptions = {};
      vm.activate = activate;
      vm.dateOptions = {
        autoclose: true,
        todayBtn: 'linked',
        todayHighlight: true
      };
      vm.supportedDialog = true;
      vm.API_BASE = API_BASE;

      function activate() {
        if (vm.options) {
          angular.forEach(vm.options, parseOptions);
        }
        if (angular.isDefined(vm.dialog)) {
          vm.dialog.dialog_tabs.forEach(iterateBGroups);
        }
      }

      // Private functions
      function parseOptions(value, key) {
        vm.parsedOptions[key.replace('dialog_', '')] = value;
      }

      function iterateBGroups(item) {
        item.dialog_groups.forEach(iterateBFields);
      }

      function iterateBFields(item) {
        if (lodash.result(lodash.find(item.dialog_fields, {'dynamic': true}), 'name') ||
        lodash.result(lodash.find(item.dialog_fields, {'type': 'DialogFieldTagControl'}), 'name')) {
          vm.supportedDialog = false;
        }
      }
    }
  }
})();
