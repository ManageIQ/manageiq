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
      'services.list': {
        url: '', // No url, this state is the index of projects
        templateUrl: 'app/states/services/list/list.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Services List',
        resolve: {
          services: resolveServices
        }
      }
    };
  }

  /** @ngInject */
  function resolveServices(CollectionsApi) {
    var options = {expand: 'resources'};

    return CollectionsApi.query('services', options);
  }

  /** @ngInject */
  function StateController($state, services) {
    /* jshint validthis: true */
    var vm = this;

    vm.title = 'Services List';
    vm.services = services.resources;

    vm.handleClick = handleClick;

    vm.config = {
      selectItems: false,
      multiSelect: false,
      dblClick: false,
      selectionMatchProp: 'name',
      selectedItems: [],
      showSelectBox: false,
      rowHeight: 36,
      onClick: vm.handleClick
    };

    function handleClick(item, e) {
      $state.go('services.details', {requestId: item.id});
    };
  }
})();
