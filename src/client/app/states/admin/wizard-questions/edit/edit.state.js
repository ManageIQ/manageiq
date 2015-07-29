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
      'admin.wizard-questions.edit': {
        url: '/edit/:questionId',
        templateUrl: 'app/states/admin/wizard-questions/edit/edit.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Edit Wizard Question',
        resolve: {
          wizardQuestion: resolveWizardQuestion
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
  function resolveWizardQuestion(WizardQuestion, $stateParams) {
    return WizardQuestion.get({id: $stateParams.questionId}).$promise;
  }

  /** @ngInject */
  function StateController(logger, wizardQuestion) {
    var vm = this;

    vm.title = 'Edit Wizard Question';
    vm.question = wizardQuestion;

    vm.activate = activate;

    activate();

    function activate() {
      logger.info('Activated Edit Wizard Question View');
    }
  }
})();
