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
      AuthenticationApi.login(vm.credentials.login, vm.credentials.password).then(handleSuccess);

      function handleSuccess() {
        var options = {expand: 'resources', filter: ['userid=' + vm.credentials.login]};

        CollectionsApi.query('users', options).then(handleUserInfo);
        $state.go('dashboard');

        function handleUserInfo(data) {
          if (!data.resources || 0 === data.resources.length) {
            return Session.currentUser({name: 'Unknown User', email: ''});
          }

          Session.currentUser({name: data.resources[0].name, email: data.resources[0].email});
        }
      }
    }
  }
})();
