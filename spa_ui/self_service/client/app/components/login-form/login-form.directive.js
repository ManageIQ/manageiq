(function() {
  'use strict';

  angular.module('app.components')
    .directive('loginForm', LoginFormDirective);

  /** @ngInject */
  function LoginFormDirective() {
    var directive = {
      restrict: 'AE',
      scope: {},
      link: link,
      templateUrl: 'app/components/login-form/login-form.html',
      controller: LoginFormController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function LoginFormController(Toasts, $state, AuthenticationService) {
      var vm = this;

      var showValidationMessages = false;
      var dashboard = 'dashboard';

      vm.email = '';
      vm.password = '';

      vm.activate = activate;
      vm.showErrors = showErrors;
      vm.hasErrors = hasErrors;
      vm.onSubmit = onSubmit;

      function activate() {
      }

      function showErrors() {
        return showValidationMessages;
      }

      function hasErrors(field) {
        if (angular.isUndefined(field)) {
          return showValidationMessages && vm.form.$invalid;
        }

        return showValidationMessages && vm.form[field].$invalid;
      }

      function onSubmit() {
        showValidationMessages = true;

        if (vm.form.$valid) {
          AuthenticationService.login(vm.email, vm.password)
            .success(loginSuccess)
            .error(loginError);
        }

        function loginSuccess() {
          Toasts.toast('You have successfully logged in.');
          $state.go(dashboard);
        }

        function loginError() {
          Toasts.error('Invalid login credentials entered, please reenter and try again.');
        }
      }
    }
  }
})();
