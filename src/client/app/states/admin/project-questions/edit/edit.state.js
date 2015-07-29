(function() {
  'use strict';

  angular.module('app.states')
    .run(appRun);

  /** @ngInject */
  function appRun(routerHelper, navigationHelper) {
    routerHelper.configureStates(getStates());
    navigationHelper.navItems(navItems());
    navigationHelper.sidebarItems(sidebarItems());
  }

  function getStates() {
    return {
      'admin.project-questions.edit': {
        url: '/edit/:projectQuestionId',
        templateUrl: 'app/states/admin/project-questions/edit/edit.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Admin Project Question Edit',
        resolve: {
          projectQuestion: resolveProjetQuestion
        }
      }
    };
  }

  function navItems() {
    return {};
  }

  function sidebarItems() {
    return {};
  }

  /** @ngInject */
  function resolveProjetQuestion(ProjectQuestion, $stateParams) {
    return ProjectQuestion.get({id: $stateParams.projectQuestionId}).$promise;
  }

  /** @ngInject */
  function StateController(projectQuestion) {
    var vm = this;

    vm.title = 'Admin Project Question Edit';
    vm.activate = activate;

    activate();

    function activate() {
      vm.projectQuestion = projectQuestion;
    }
  }
})();
