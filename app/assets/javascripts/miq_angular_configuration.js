ManageIQ.angularApplication.config([ '$httpProvider', '$stateProvider', '$urlRouterProvider', '$locationProvider', function ($httpProvider, $stateProvider, $urlRouterProvider, $locationProvider) {
  $httpProvider.defaults.headers.common['X-CSRF-Token'] = jQuery('meta[name=csrf-token]').attr('content');

  /**
   * Routes and States for Repository
   */
  $stateProvider
    .state('new', {
      url: '/repository/new',
      templateUrl: 'new.html',
      controller: 'repositoryFormController',
      repositoryFormId: "new"
    });

  // default fall back route
  //$urlRouterProvider.otherwise('/');

  // enable HTML5 Mode for SEO
  $locationProvider.html5Mode({enabled: true,requireBase: false});
}]);
