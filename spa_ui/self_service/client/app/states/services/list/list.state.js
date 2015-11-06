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
    var options = {expand: 'resources', attributes: ['picture', 'picture.image_href', 'evm_owner.name', 'v_total_vms']};

    return CollectionsApi.query('services', options);
  }

  /** @ngInject */
  function StateController($state, services, ServicesState, $filter) {
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
            title: 'Name',
            placeholder: 'Filter by Name',
            filterType: 'text'
          },
          {
            id: 'retirement',
            title: 'Retirement Date',
            placeholder: 'Filter by Retirement Date',
            filterType: 'select',
            filterValues: ['Current', 'Soon', 'Retired']
          },
          {
            id: 'vms',
            title: 'Number of VMs',
            placeholder: 'Filter by VMs',
            filterType: 'text'
          },
          {
            id: 'owner',
            title: 'Owner',
            placeholder: 'Filter by Owner',
            filterType: 'text'
          },
          {
            id: 'created',
            title: 'Created',
            placeholder: 'Filter by Created On',
            filterType: 'text'
          }
        ],
        resultsCount: vm.servicesList.length,
        appliedFilters: ServicesState.getFilters(),
        onFilterChange: filterChange
      },
      sortConfig: {
        fields: [
          {
            id: 'name',
            title:  'Name',
            sortType: 'alpha'
          },
          {
            id: 'retires',
            title:  'Retirement Date',
            sortType: 'numeric'
          },
          {
            id: 'vms',
            title:  'Number of VMs',
            sortType: 'numeric'
          },
          {
            id: 'owner',
            title:  'Owner',
            sortType: 'alpha'
          },
          {
            id: 'created',
            title:  'Created',
            sortType: 'numeric'
          }
        ],
        onSortChange: sortChange,
        isAscending: ServicesState.getSort().isAscending,
        currentField: ServicesState.getSort().currentField
      }
    };

    /* Apply the filtering to the data list */
    filterChange(ServicesState.getFilters());

    function handleClick(item, e) {
      $state.go('services.details', {serviceId: item.id});
    }

    function sortChange(sortId, isAscending) {
      vm.servicesList.sort(compareFn);

      /* Keep track of the current sorting state */
      ServicesState.setSort(sortId, vm.toolbarConfig.sortConfig.isAscending);
    }
    
    function compareFn(item1, item2) {
      var compValue = 0;
      if (vm.toolbarConfig.sortConfig.currentField.id === 'name') {
        compValue = item1.name.localeCompare(item2.name);
      } else if (vm.toolbarConfig.sortConfig.currentField.id === 'vms') {
        compValue = item1.v_total_vms - item2.v_total_vms;
      } else if (vm.toolbarConfig.sortConfig.currentField.id === 'owner') {
        if ( !angular.isDefined(item1.evm_owner) 
           && angular.isDefined(item2.evm_owner) ) {
          compValue = 1;
        } else if ( angular.isDefined(item1.evm_owner) 
                && !angular.isDefined(item2.evm_owner) ) {
          compValue = -1;
        } else if ( !angular.isDefined(item1.evm_owner) 
                 && !angular.isDefined(item2.evm_owner) ) {
          compValue = 0;
        } else {
          compValue = item1.evm_owner.name.localeCompare(item2.evm_owner.name);
        }
      } else if (vm.toolbarConfig.sortConfig.currentField.id === 'created') {
        compValue = new Date(item1.created_at) - new Date(item2.created_at);
      } else if (vm.toolbarConfig.sortConfig.currentField.id === 'retires') {
        compValue = getRetirementDate(item1.retires_on) - getRetirementDate(item2.retires_on);
      } 

      if (!vm.toolbarConfig.sortConfig.isAscending) {
        compValue = compValue * -1;
      }

      return compValue;
    }

    /* Date 10 years into the future */
    var neverRetires = new Date();
    neverRetires.setDate(neverRetires.getYear() + 10);

    function getRetirementDate(value) {
      if (angular.isDefined(value)) {
        return new Date(value);
      } else {
        return neverRetires;
      }
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

      /* Keep track of the current filtering state */
      ServicesState.setFilters(filters);

      /* Make sure sorting direction is maintained */
      sortChange(ServicesState.getSort().currentField, ServicesState.getSort().isAscending);

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
      } else if ('vms' === filter.id) {
        return String(item.v_total_vms).toLowerCase().indexOf(filter.value.toLowerCase()) !== -1;
      } else if ('owner' === filter.id && angular.isDefined(item.evm_owner)) {
        return item.evm_owner.name.toLowerCase().indexOf(filter.value.toLowerCase()) !== -1;
      } else if ('retirement' === filter.id) {
        return checkRetirementDate(item, filter.value.toLowerCase());
      } else if ('created' === filter.id) {
        return $filter('date')(item.created_at).toLowerCase().indexOf(filter.value.toLowerCase()) !== -1;
      }

      return false;
    }

    function checkRetirementDate(item, filterValue) {
      var currentDate = new Date();

      if (filterValue === 'retired' && angular.isDefined(item.retires_on)) {
        return new Date(item.retires_on) < currentDate;
      } else if (filterValue === 'current') {
        return !angular.isDefined(item.retires_on) || new Date(item.retires_on) >= currentDate;
      } else if (filterValue === 'soon' && angular.isDefined(item.retires_on)) {
        return new Date(item.retires_on) >= currentDate 
          && new Date(item.retires_on) <= currentDate.setDate(currentDate.getDate() + 30);
      }

      return false;
    }
  }
})();
