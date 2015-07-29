(function() {
  'use strict';

  angular.module('app.components')
    .directive('alertForm', AlertFormDirective);

  /** @ngInject */
  function AlertFormDirective() {
    var directive = {
      restrict: 'AE',
      scope: {
        alertRecord: '=?',
        heading: '@?',
        staffId: '@?',
        alertableId: '@?',
        alertableType: '@?',
        home: '=?',
        homeParams: '=?'
      },
      link: link,
      templateUrl: 'app/components/alert-form/alert-form.html',
      controller: AlertFormController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function AlertFormController($scope, $state, Toasts, Alert, lodash) {
      var vm = this;

      vm.showValidationMessages = false;
      vm.format = 'yyyy-MM-dd';
      vm.dateOptions = {
        formatYear: 'yy',
        startingDay: 0,
        showWeeks: false
      };

      vm.backToList = backToList;
      vm.showErrors = showErrors;
      vm.hasErrors = hasErrors;
      vm.onSubmit = onSubmit;
      vm.openStart = openStart;
      vm.openEnd = openEnd;
      vm.openAnswerDate = openAnswerDate;

      vm.activate = activate;
      activate();

      function activate() {
      }

      function backToList() {
        $state.go(vm.home, vm.homeParams);
      }

      function showErrors() {
        return vm.showValidationMessages;
      }

      function hasErrors(field) {
        if (angular.isUndefined(field)) {
          return vm.showValidationMessages && vm.form.$invalid;
        }

        return vm.showValidationMessages && vm.form[field].$invalid;
      }

      function onSubmit() {
        vm.showValidationMessages = true;
        // This is so errors can be displayed for 'untouched' angular-schema-form fields
        $scope.$broadcast('schemaFormValidate');
        if (vm.form.$valid) {
          vm.alertRecord.alertable_type = vm.alertableType;
          vm.alertRecord.alertable_id = vm.alertableId;
          // If editing update rather than save
          if (vm.alertRecord.id) {
            for (var prop in vm.alertRecord) {
              if (vm.alertRecord[prop] === null) {
                delete vm.alertRecord[prop];
              }
            }

            Alert.update(vm.alertRecord).$promise.then(saveSuccess, saveFailure);

            return false;
          } else {
            Alert.save(vm.alertRecord).$promise.then(saveSuccess, saveFailure);

            return false;
          }
        }

        function saveSuccess() {
          Toasts.toast('Alert saved.');
          backToList();
        }

        function saveFailure() {
          Toasts.error('Server returned an error while saving.');
        }
      }

      function openStart($event) {
        $event.preventDefault();
        $event.stopPropagation();
        vm.openedStart = true;
      }

      function openEnd($event) {
        $event.preventDefault();
        $event.stopPropagation();
        vm.openedEnd = true;
      }

      function openAnswerDate($event, index) {
        $event.preventDefault();
        $event.stopPropagation();
        vm.startDateOpened = false;
        vm.endDateOpened = false;
        vm.answerDateOpened = [];
        vm.answerDateOpened[index] = true;
      }
    }
  }
})();
