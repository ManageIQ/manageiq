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
      'projects.create': {
        url: '/create/:projectId',
        params: {
          projectId: null
        },
        templateUrl: 'app/states/projects/create/create.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Project Create'
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
  function StateController(logger, ProjectQuestion, $stateParams, Project, lodash) {
    var vm = this;

    vm.projectId = $stateParams.projectId;
    vm.activate = activate;

    activate();

    function activate() {
      logger.info('Activated Project Create View');
      resolveProjects();
    }

    function resolveProjects() {
      vm.project = {};
      vm.project.project_answers = [];
      resolveProjectQuestions();
    }

    function resolveProjectQuestions() {
      ProjectQuestion.query().$promise.then(function(result) {
        vm.projectQuestions = result;

        lodash.each(vm.projectQuestions, function(question) {
          vm.existingAnswer = lodash.find(vm.project.project_answers, function(answer) {
            return answer.project_question_id === question.id;
          });
          if (vm.existingAnswer === undefined) {
            vm.project.project_answers.push({
              project_question_id: question.id,
              project_question: question,
              project_question_name: 'project_question_' + question.id
            });
          }
        });
      });
    }
  }
})();
