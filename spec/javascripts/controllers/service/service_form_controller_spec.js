describe('serviceFormController', function() {
  var $scope, $controller, $httpBackend, miqService, postService;

  beforeEach(module('ManageIQ'));

  beforeEach(inject(function($rootScope, _$controller_, _$httpBackend_, _miqService_, _postService_) {
    miqService = _miqService_;
    postService = _postService_;
    spyOn(miqService, 'showButtons');
    spyOn(miqService, 'hideButtons');
    spyOn(miqService, 'miqAjaxButton');
    spyOn(miqService, 'sparkleOn');
    spyOn(miqService, 'sparkleOff');
    spyOn(postService, 'cancelOperation');
    spyOn(postService, 'saveRecord');
    $scope = $rootScope.$new();
    $httpBackend = _$httpBackend_;

    var serviceData = {name:        'serviceName',
                       description: 'serviceDescription'};

    $controller = _$controller_('serviceFormController', {
      $scope: $scope,
      serviceFormId: 1000000000001,
      miqService: miqService,
      serviceData: serviceData
    });
  }));

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

    it('delegates to postService.cancelOperation', function() {
      var msg = "Edit of Service serviceDescription was cancelled by the user";
      expect(postService.cancelOperation).toHaveBeenCalledWith('/service/explorer', msg);
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

    it('delegates to postService.saveRecord', function() {
      expect(postService.saveRecord).toHaveBeenCalledWith(
        '/api/services/1000000000001',
        '/service/explorer',
        Object({ name: 'serviceName', description: 'serviceDescription' }),
        'Service serviceName was saved');
    });
  });
});
