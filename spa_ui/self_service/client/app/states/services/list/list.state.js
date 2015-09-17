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
        title: 'Service List',
        resolve: {
          services: resolveServices
        }
      }
    };
  }

  /** @ngInject */
  function resolveServices(CollectionsApi) {
    var options = {expand: 'resources', attributes: ['picture', 'picture.image_href']};

    return CollectionsApi.query('services', options);
  }

  /** @ngInject */
  function StateController($state, services) {
    /* jshint validthis: true */
    var vm = this;

    vm.title = 'Service List';
    vm.services = services.resources;
    vm.servicesList = angular.copy(vm.services);

    vm.listConfig = {
      selectItems: false,
      showSelectBox: false,
      selectionMatchProp: 'service_status',
      onClick: handleClick
    };

    vm.toolbarConfig = {
      filterConfig: {
        fields: [
          {
            id: 'name',
            title: 'Service Name',
            placeholder: 'Filter by Service Name',
            filterType: 'text'
          },
          {
            id: 'id',
            title: 'Service Id',
            placeholder: 'Filter by Service ID',
            filterType: 'text'
          }
        ],
        resultsCount: vm.servicesList.length,
        appliedFilters: [],
        onFilterChange: filterChange
      }
    };

    function handleClick(item, e) {
      $state.go('services.details', {serviceId: item.id});
    }

    function filterChange(filters) {
      vm.filtersText = '';
      angular.forEach(filters, filterTextFactory);

      function filterTextFactory(filter) {
        vm.filtersText += filter.title + ' : ' + filter.value + '\n';
      }

      applyFilters(filters);
      vm.toolbarConfig.filterConfig.resultsCount = vm.servicesList.length;
    }

    function applyFilters(filters) {
      vm.servicesList = [];
      if (filters && filters.length > 0) {
        angular.forEach(vm.services, filterChecker);
      } else {
        vm.servicesList = vm.services;
      }

      function filterChecker(item) {
        if (matchesFilters(item, filters)) {
          vm.servicesList.push(item);
        }
      }
    }

    function matchesFilters(item, filters) {
      var matches = true;
      angular.forEach(filters, filterMatcher);

      function filterMatcher(filter) {
        if (!matchesFilter(item, filter)) {
          matches = false;

          return false;
        }
      }

      return matches;
    }

    function matchesFilter(item, filter) {
      if ('name' === filter.id) {
        return item.name.toLowerCase().indexOf(filter.value.toLowerCase()) !== -1;
      } else if ('id' === filter.id) {
        return Number(item.id) === Number(filter.value);
      }

      return false;
    }
  }
})();
