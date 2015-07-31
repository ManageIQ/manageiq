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
      'admin.wizard-questions': {
        url: '/wizard-questions',
        redirectTo: 'admin.wizard-questions.list',
        template: '<ui-view></ui-view>'
      }
    };
  }

  function navItems() {
    return {};
  }

  function sidebarItems() {
    return {
      'admin.alerts': {
        type: 'state',
        state: 'admin.wizard-questions',
        label: 'Wizard Questions',
        order: 9
      }
    };
  }
})();
