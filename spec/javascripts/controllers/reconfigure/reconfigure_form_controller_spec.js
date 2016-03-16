describe('reconfigureFormController', function() {
  var $scope, $controller, $httpBackend, miqService;

  beforeEach(module('ManageIQ'));

  beforeEach(inject(function($rootScope, _$controller_, _$httpBackend_, _miqService_) {
    miqService = _miqService_;
    spyOn(miqService, 'miqFlash');
    spyOn(miqService, 'miqAjaxButton');
    spyOn(miqService, 'sparkleOn');
    spyOn(miqService, 'sparkleOff');
    $scope = $rootScope.$new();
    $scope.reconfigureModel = {memory:                 '0',
                               memory_type:            '',
                               socket_count:           '1',
                               socket_options:         [],
                               cores_per_socket_count: '1',
                               total_cpus:             '1'};
    $httpBackend = _$httpBackend_;
    $controller = _$controller_('reconfigureFormController', {
      $scope: $scope,
      reconfigureFormId: '1000000000003',
      cb_memory:              false,
      cb_cpu:                 false,
      objectIds: [1000000000001,1000000000002],
      miqService: miqService
    });
  }));

  beforeEach(inject(function(_$controller_) {
    var reconfigureFormResponse = {cb_memory:              'on',
                                   memory:                 '4196',
                                   memory_type:            'MB',
                                   cb_cpu:                 'on',
                                   socket_count:           '2',
                                   cores_per_socket_count: '3'};
    $httpBackend.whenGET('reconfigure_form_fields/1000000000003,1000000000001,1000000000002').respond(reconfigureFormResponse);
    $httpBackend.flush();
  }));

  afterEach(function() {
    $httpBackend.verifyNoOutstandingExpectation();
    $httpBackend.verifyNoOutstandingRequest();
  });

  describe('initialization', function() {
    it('sets the reconfigure memory value to the value returned with http request', function() {
      expect($scope.reconfigureModel.memory).toEqual('4196');
    });

    it('sets the reconfigure socket count to the value returned with http request', function() {
      expect($scope.reconfigureModel.socket_count).toEqual('2');
    });

    it('sets the reconfigure cores per socket count to the value returned with http request', function() {
      expect($scope.reconfigureModel.cores_per_socket_count).toEqual('3');
    });

    it('sets the total socket count to the value calculated from the http request data', function() {
      expect($scope.reconfigureModel.total_cpus).toEqual('6');
    });
  });

  describe('#cancelClicked', function() {
    beforeEach(function() {
      $scope.angularForm = {
        $setPristine: function(value) {}
      };
      $scope.cancelClicked();
    });

    it('turns the spinner on via the miqService', function() {
      expect(miqService.sparkleOn).toHaveBeenCalled();
    });

    it('delegates to miqService.miqAjaxButton', function() {
      expect(miqService.miqAjaxButton).toHaveBeenCalledWith('reconfigure_update?button=cancel');
    });
  });

  describe('#submitClicked', function() {
    beforeEach(function() {
      $scope.angularForm = {
        $setPristine: function (value){}
      };
      $scope.submitClicked();
    });

    it('turns the spinner on via the miqService', function() {
      expect(miqService.sparkleOn).toHaveBeenCalled();
    });

    it('delegates to miqService.miqAjaxButton', function() {
      var submitContent = {objectIds:              $scope.objectIds,
                           cb_memory:              $scope.cb_memory,
                           cb_cpu:                 $scope.cb_cpu,
                           memory:                 $scope.reconfigureModel.memory,
                           memory_type:            $scope.reconfigureModel.memory_type,
                           socket_count:           $scope.reconfigureModel.socket_count,
                           cores_per_socket_count: $scope.reconfigureModel.cores_per_socket_count};

      expect(miqService.miqAjaxButton).toHaveBeenCalledWith('reconfigure_update/1000000000003?button=submit', submitContent);
    });
  });
});
