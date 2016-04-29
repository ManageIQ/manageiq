miqHttpInject(angular.module('middleware.provider', ['miQStaticAssets', 'ui.bootstrap', 'ui.router', 'patternfly.select', 'ui.bootstrap.tabs', 'patternfly.views', 'ngAnimate']))
.config(function($stateProvider, $locationProvider, $urlRouterProvider) {
  $stateProvider.state('list_providers', {
    url: '/ems_middleware/show_list',
    templateUrl: '/static/middleware/list_providers.html',
    controller: 'miqListProvidersController as vm'
  })
  .state('list_providers.list', {
    url: '/list',
    templateUrl: '/static/middleware/list_providers/list_view.html'
  })
  .state('list_providers.tile', {
    url: '/tile',
    templateUrl: '/static/middleware/list_providers/tile_view.html'
  })
  .state('list_providers.grid', {
    url: '/grid',
    templateUrl: '/static/middleware/list_providers/grid_view.html'
  })
  .state('new_provider', {
      url: '/ems_middleware/new',
      templateUrl: '/static/middleware/new_provider.html',
      controller: 'miqNewProviderController as mwNew'
  });

  $locationProvider.html5Mode({
    enabled: true,
    requireBase: false
  });
  $urlRouterProvider.otherwise('/ems_middleware/show_list/list');
  // $urlRouterProvider.otherwise('/ems_middleware/show_list');
  $urlRouterProvider.otherwise(function ($injector, $location) {
    if ($location.hash().length != 0) {
      return $location.path() +
        ($location.hash().indexOf('/') !== 0 ? '/' + $location.hash() : $location.hash());
    } else {
      return '/ems_middleware/show_list/list';
    }
  });
})
.config(function(MiQDataAccessServiceProvider, MiQFormValidatorServiceProvider, MiQDataTableServiceProvider) {
  MiQDataAccessServiceProvider.setUrlPrefix('/ems_middleware');
  MiQDataTableServiceProvider.endpoints = {
    list: '/list_providers'
  };
  MiQFormValidatorServiceProvider.endpoints = {
    validate: '/validate_provider',
    create: '/new_provider'
  }
});
