ManageIQ.angularApplication.config([ '$httpProvider', '$stateProvider', '$urlRouterProvider', '$locationProvider', function ($httpProvider, $stateProvider, $urlRouterProvider, $locationProvider) {
  $httpProvider.defaults.headers.common['X-CSRF-Token'] = jQuery('meta[name=csrf-token]').attr('content');

  /**
   * Routes and States for Repository
   */
  $stateProvider
    .state('new', {
      url: '/repository/new',
      templateUrl: 'repository/form.html',
      controller: 'repositoryFormController',
      resolve: {
        repositoryData: function (repositoryDataFactory) {
          return repositoryDataFactory.getRepositoryData();
        }
      }
    });
  $stateProvider
    .state('edit', {
      url: '/repository/edit/:repo_id',
      templateUrl: 'repository/form.html',
      controller: 'repositoryFormController',
      resolve: {
        repositoryData: function (repositoryDataFactory, $stateParams) {
          return repositoryDataFactory.getRepositoryData($stateParams.repo_id);
        }
      }
    });

  // default fall back route
  //$urlRouterProvider.otherwise('/');

  // enable HTML5 Mode for SEO
  $locationProvider.html5Mode({enabled: true,requireBase: false});
}]);

ManageIQ.angularApplication.run(['$rootScope', 'miqService', function($root, miqService) {
  $root.$on('$stateChangeStart', function() {
    miqService.sparkleOn();
  });

  $root.$on('$stateChangeSuccess', function() {
    miqService.sparkleOff();
  });

}]);
