/* jshint -W117, -W030 */
describe('404', function() {
  beforeEach(function() {
    bard.asyncModule('app.states');
  });

  describe('route', function() {
    var views = {
      four0four: 'app/states/404/404.html'
    };

    beforeEach(function() {
      bard.inject('$location', '$rootScope', '$state', '$templateCache');
    });

    it('should map /404 route to 404 View template', function() {
      expect($state.get('404').templateUrl).to.equal(views.four0four);
    });

    it('should work with $state.go', function() {
      $state.go('404');
      $rootScope.$apply();
      expect($state.is('404'));
    });

    it('should route /invalid to the otherwise (404) route', function() {
      $location.path('/invalid');
      $rootScope.$apply();
      expect($state.current.templateUrl).to.equal(views.four0four);
    });
  });
});
