describe('serviceFormController', function() {
  var $scope, $controller, $httpBackend, miqService;

  beforeEach(module('ManageIQ'));

  beforeEach(inject(function($rootScope, _$controller_, _$httpBackend_, _miqService_) {
    miqService = _miqService_;
    spyOn(miqService, 'showButtons');
    spyOn(miqService, 'hideButtons');
    spyOn(miqService, 'miqAjaxButton');
    spyOn(miqService, 'sparkleOn');
    spyOn(miqService, 'sparkleOff');
    $scope = $rootScope.$new();
    $httpBackend = _$httpBackend_;

    $controller = _$controller_('serviceFormController', {
      $scope: $scope,
      serviceFormId: 1000000000001,
      miqService: miqService
    });
  }));

  beforeEach(inject(function(_$controller_) {
    var serviceFormResponse = {
      name: 'serviceName',
      description: 'serviceDescription'
    };
    $httpBackend.whenGET('/service/service_form_fields/1000000000001').respond(serviceFormResponse);
    $httpBackend.flush();
  }));

  afterEach(function() {
    $httpBackend.verifyNoOutstandingExpectation();
    $httpBackend.verifyNoOutstandingRequest();
  });

  describe('initialization', function() {
    it('sets the service name to the value returned via the http request', function() {
      expect($scope.serviceModel.name).toEqual('serviceName');
      expect($scope.serviceModel.description).toEqual('serviceDescription');
    });
  });

  describe('#cancelClicked', function() {
    beforeEach(function() {
      $scope.angularForm = {
        $setPristine: function (value){}
      };
      $scope.cancelClicked();
    });

    it('turns the spinner on via the miqService', function() {
      expect(miqService.sparkleOn).toHaveBeenCalled();
    });

    it('delegates to miqService.miqAjaxButton', function() {
      expect(miqService.miqAjaxButton).toHaveBeenCalledWith('/service/service_edit/1000000000001?button=cancel', undefined);
    });
  });

  describe('#resetClicked', function() {
    beforeEach(function() {
      $scope.serviceModel.name = 'foo';
      $scope.angularForm = {
        $setPristine: function (value){},
        $setUntouched: function (value){},
      };
      $scope.resetClicked();
    });

    it('resets value of name field to initial value', function() {
      expect($scope.serviceModel.name).toEqual('serviceName');
    });
  });

  describe('#saveClicked', function() {
    beforeEach(function() {
      $scope.angularForm = {
        $setPristine: function (value){}
      };
      $scope.saveClicked();
    });

    it('turns the spinner on via the miqService', function() {
      expect(miqService.sparkleOn).toHaveBeenCalled();
    });

    it('delegates to miqService.miqAjaxButton', function() {
      expect(miqService.miqAjaxButton).toHaveBeenCalledWith('/service/service_edit/1000000000001?button=save', true);
    });
  });
});
