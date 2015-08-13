/* jshint -W117, -W030 */
describe('error', function() {
  beforeEach(function() {
    bard.asyncModule('app.states');
  });

  describe('route', function() {
    var views = {
      error: 'app/states/error/error.html'
    };

    beforeEach(function() {
      bard.inject('$location', '$rootScope', '$state', '$templateCache');
    });

    it('should map /error route to http-error View template', function() {
      expect($state.get('error').templateUrl).to.equal(views.error);
    });

    it('should work with $state.go', function() {
      $state.go('error');
      $rootScope.$apply();
      expect($state.is('error'));
    });
  });
});
