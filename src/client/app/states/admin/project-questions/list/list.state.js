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
      'admin.project-questions.list': {
        url: '', // No url, this state is the index of admin.project-questions
        templateUrl: 'app/states/admin/project-questions/list/list.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Project Questions',
        resolve: {
          projectQuestions: resolveProjectQuestions
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
  function resolveProjectQuestions(ProjectQuestion) {
    return ProjectQuestion.query().$promise;
  }

  /** @ngInject */
  function StateController(jQuery, logger, Toasts, projectQuestions, $timeout) {
    var vm = this;

    vm.title = 'Project Questions';
    vm.projectQuestions = projectQuestions;
    vm.currentSort = [];
    vm.sortableOptions = {
      axis: 'y',
      cursor: 'move',
      handle: '.project-questions-table__handle',
      helper: sortableHelper,
      opacity: 0.9,
      placeholder: 'project-questions-table__placeholder',
      stop: sortableStop
    };

    vm.activate = activate;
    vm.deleteQuestion = deleteQuestion;

    activate();

    function activate() {
      logger.info('Activated Project Questions View');
    }

    function deleteQuestion(index) {
      var projectQuestion = vm.projectQuestions[index];

      projectQuestion.$delete(deleteSuccess, deleteFailure);

      function deleteSuccess() {
        vm.projectQuestions.splice(index, 1);
        Toasts.toast('Project Question deleted.');
      }

      function deleteFailure() {
        Toasts.error('Server returned an error while deleting.');
      }
    }

    // Private

    function sortableHelper(event, element) {
      var $originals = element.children();
      var $helper = element.clone();
      $helper.children().each(setCloneWidth);

      return $helper;

      function setCloneWidth(index, element) {
        // Set helper cell sizes to match the original sizes
        jQuery(element).width($originals.eq(index).width());
      }
    }

    function sortableStop(event, ui) {
      var projectQuestion = angular.element(ui.item).scope().row;
      var sortableList = ui.item.parent().children().map(function(row) {
        return vm.projectQuestions[row].id;
      }).toArray();

      projectQuestion.position = sortableList;
      projectQuestion.$sort(updateSuccess, updateFailure);

      function updateSuccess() {
        Toasts.toast('Project Question order saved.');
      }

      function updateFailure() {
        Toasts.error('Server returned an error while saving.');
      }
    }
  }
})();
