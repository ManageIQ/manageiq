/* jshint -W117, -W030 */
describe('Dashboard', function() {
  beforeEach(function() {
    module('app.states', 'app.config', bard.fakeToastr);
    bard.inject('$location', '$rootScope', '$state', '$templateCache', 'Session');
  });

  describe('route', function() {
    var views = {
      list: 'app/states/requests/list/list.html'
    };

    beforeEach(function() {
      bard.inject('$location', '$rootScope', '$state', '$templateCache');
    });

    it('should work with $state.go', function() {
      $state.go('requests.list');
      $rootScope.$apply();
      expect($state.is('requests.list'));
    });
  });

  describe('controller', function() {
    var controller;
    var requests = {
      name: 'service_requests',
      count: 1,
      subcount: 1,
      resources: []
    };

    beforeEach(function() {
      bard.inject('$controller', '$log', '$state', '$rootScope', 'Notifications');

      controller = $controller($state.get('requests.list').controller, {requests: requests});
      $rootScope.$apply();
    });

    it('should be created successfully', function() {
      expect(controller).to.be.defined;
    });

    it('should have title of Request List', function() {
      expect(controller.title).to.equal('Request List');
    });
  });
});
