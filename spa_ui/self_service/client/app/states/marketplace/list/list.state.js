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
      'marketplace.list': {
        url: '',
        templateUrl: 'app/states/marketplace/list/list.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Service Catalog',
        resolve: {
          serviceTemplates: resolveServiceTemplates
        }
      }
    };
  }

  /** @ngInject */
  function resolveServiceTemplates(CollectionsApi) {
    var attributes = ['picture', 'picture.image_href', 'service_template_catalog.name'];
    var options = {expand: 'resources', filter: ['display=true'], attributes: attributes};

    return CollectionsApi.query('service_templates', options);
  }

  /** @ngInject */
  function StateController($state, serviceTemplates, MarketplaceState) {
    var vm = this;

    vm.title = 'Service Catalog';
    vm.serviceTemplates = serviceTemplates.resources;
    vm.serviceTemplatesList = angular.copy(vm.serviceTemplates);

    vm.showDetails = showDetails;

    function showDetails(template) {
      $state.go('marketplace.details', {serviceTemplateId: template});
    }

    function addCategoryFilter(item) {
      if (angular.isDefined(item.service_template_catalog) 
        && angular.isDefined(item.service_template_catalog.name)
        && categoryNames.indexOf(item.service_template_catalog.name) === -1) {
        categoryNames.push(item.service_template_catalog.name); 
      }
    }

    var categoryNames = [];
    angular.forEach(vm.serviceTemplates, addCategoryFilter);

    vm.toolbarConfig = {
      filterConfig: {
        fields: [
          {
            id: 'template_name',
            title: 'Service Name',
            placeholder: 'Filter by Name',
            filterType: 'text'
          },
          {
            id: 'template_description',
            title: 'Service Description',
            placeholder: 'Filter by Description',
            filterType: 'text'
          },
          {
            id: 'catalog_name',
            title: 'Catalog Name',
            placeholder: 'Filter by Catalog Name',
            filterType: 'select',
            filterValues: categoryNames
          }
        ],
        resultsCount: vm.serviceTemplatesList.length,
        appliedFilters: MarketplaceState.getFilters(),
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
            id: 'catalog_name',
            title:  'Catalog Name',
            sortType: 'alpha'
          }
        ],
        onSortChange: sortChange,
        isAscending: MarketplaceState.getSort().isAscending,
        currentField: MarketplaceState.getSort().currentField
      }
    };

    /* Apply the filtering to the data list */
    filterChange(MarketplaceState.getFilters());

    function sortChange(sortId, isAscending) {
      vm.serviceTemplatesList.sort(compareFn);

      /* Keep track of the current sorting state */
      MarketplaceState.setSort(sortId, vm.toolbarConfig.sortConfig.isAscending);
    }

    function filterChange(filters) {
      vm.filtersText = '';
      angular.forEach(filters, filterTextFactory);

      function filterTextFactory(filter) {
        vm.filtersText += filter.title + ' : ' + filter.value + '\n';
      }

      applyFilters(filters);
      vm.toolbarConfig.filterConfig.resultsCount = vm.serviceTemplatesList.length;
    }

    function applyFilters(filters) {
      vm.serviceTemplatesList = [];
      if (filters && filters.length > 0) {
        angular.forEach(vm.serviceTemplates, filterChecker);
      } else {
        vm.serviceTemplatesList = vm.serviceTemplates;
      }

      /* Keep track of the current filtering state */
      MarketplaceState.setFilters(filters);

      /* Apply Default Sorting */
      vm.serviceTemplatesList.sort(compareFn);

      function filterChecker(item) {
        if (matchesFilters(item, filters)) {
          vm.serviceTemplatesList.push(item);
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
      var match = false;
      if (filter.id === 'template_name') {
        match = (String(item.name).toLowerCase().indexOf(String(filter.value).toLowerCase()) > -1 );
      } else if (filter.id === 'template_description') {
        match = (String(item.long_description).toLowerCase().indexOf(String(filter.value).toLowerCase()) > -1 );
      } else if (filter.id === 'catalog_name' && angular.isDefined(item.service_template_catalog) ) {
        match = item.service_template_catalog.name === filter.value;
      }

      return match;
    }

    function compareFn(item1, item2) {
      var compValue = 0;
      if (vm.toolbarConfig.sortConfig.currentField.id === 'name') {
        compValue = item1.name.localeCompare(item2.name);
      } else if (vm.toolbarConfig.sortConfig.currentField.id === 'catalog_name') {
        if ( !angular.isDefined(item1.service_template_catalog) 
           && angular.isDefined(item2.service_template_catalog) ) {
          compValue = 1;
        } else if ( angular.isDefined(item1.service_template_catalog) 
                && !angular.isDefined(item2.service_template_catalog) ) {
          compValue = -1;
        } else if ( !angular.isDefined(item1.service_template_catalog) 
                 && !angular.isDefined(item2.service_template_catalog) ) {
          compValue = 0;
        } else {
          compValue = item1.service_template_catalog.name.localeCompare(item2.service_template_catalog.name);
        }
      } 

      if (!vm.toolbarConfig.sortConfig.isAscending) {
        compValue = compValue * -1;
      }

      return compValue;
    }
  }
})();
