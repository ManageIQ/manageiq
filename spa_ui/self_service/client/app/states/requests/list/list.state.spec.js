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
    var controller, notificationSpy;
    var requests = {
      name: 'service_requests',
      count: 1,
      subcount: 1,
      resources: []
    };

    beforeEach(function() {
      bard.inject('$controller', '$log', '$state', '$rootScope', 'Notifications');

      notificationSpy = sinon.spy(Notifications, 'success');
    });

    describe('when the api response exists', function() {
      beforeEach(function() {
        var controllerResolves = {requests: requests, apiResponse: {message: 'api message'}};

        controller = $controller($state.get('requests.list').controller, controllerResolves);
        $rootScope.$apply();
      });

      it('should be created successfully', function() {
        expect(controller).to.be.defined;
      });

      it('should have title of Request List', function() {
        expect(controller.title).to.equal('Request List');
      });

      it('shows a success notification', function() {
        expect(notificationSpy).to.have.been.calledWith('api message');
      });
    });

    describe('when the api response does not exist', function() {
      beforeEach(function() {
        var controllerResolves = {requests: requests, apiResponse: null};

        controller = $controller($state.get('requests.list').controller, controllerResolves);
        $rootScope.$apply();
      });

      it('should be created successfully', function() {
        expect(controller).to.be.defined;
      });

      it('should have title of Request List', function() {
        expect(controller.title).to.equal('Request List');
      });

      it('does not show a success notification', function() {
        expect(notificationSpy).not.to.have.been.called;
      });
    });
  });

  describe('#resolveApiResponse', function() {
    beforeEach(function() {
      bard.inject('$state', '$stateParams');

      $stateParams.apiResponse = 'the api response';
    });

    it('resolves the apiResponse', function() {
      expect($state.get('requests.list').resolve.apiResponse($stateParams)).to.equal('the api response');
    });
  });
});
