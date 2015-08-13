/* jshint -W117, -W030 */
describe('Dashboard', function() {
  describe('route', function() {
    var views = {
      dashboard: 'app/states/dashboard/dashboard.html'
    };

    beforeEach(function() {
      module('app.states');
      bard.inject('$location', '$rootScope', '$state', '$templateCache');
    });

    it('should work with $state.go', function() {
      $state.go('dashboard');
      $rootScope.$apply();
      expect($state.is('dashboard'));
    });
  });

  describe('navigation', function() {
    beforeEach(function() {
      module('app.states', bard.fakeToastr);
      bard.inject('navigationHelper', '$rootScope');
    });

    it('should exist in the sidebar', function() {
      expect(navigationHelper.sidebarItems('dashboard')).to.be.defined;
    });

    it('should add profile to the navigation', function() {
      expect(navigationHelper.navItems('profile')).to.be.defined;
    });
  });

  describe('controller', function() {
    var controller;

    beforeEach(function() {
      module('app.states', bard.fakeToastr);
      bard.inject('$controller', '$log', '$state', '$rootScope');
      controller = $controller($state.get('dashboard').controller);
      $rootScope.$apply();
    });

    it('should be created successfully', function() {
      expect(controller).to.be.defined;
    });

    describe('after activate', function() {
      it('should have title of Dashboard', function() {
        expect(controller.title).to.equal('Dashboard');
      });

      it('should have logged "Activated Dashboard"', function() {
        expect($log.info.logs).to.match(/Activated Dashboard/);
      });
    });
  });
});
