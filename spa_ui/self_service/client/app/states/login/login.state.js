(function() {
  'use strict';

  angular.module('app.states')
    .run(appRun);

  /** @ngInject */
  function appRun(routerHelper) {
    routerHelper.configureStates(getStates());
  }

  function getStates() {
    return {
      'login': {
        parent: 'blank',
        url: '/login',
        templateUrl: 'app/states/login/login.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Login',
        data: {
          layout: 'blank'
        }
      }
    };
  }

  /** @ngInject */
  function StateController($state, Text, API_LOGIN, API_PASSWORD, AuthenticationApi, CollectionsApi, Session) {
    var vm = this;

    vm.title = 'Login';
    vm.text = Text.login;

    vm.credentials = {
      login: API_LOGIN,
      password: API_PASSWORD
    };

    vm.onSubmit = onSubmit;

    function onSubmit() {
      return AuthenticationApi.login(vm.credentials.login, vm.credentials.password)
        .then(Session.loadUser)
        .then(function() {
          $state.go('dashboard');
        });
    }
  }
})();
