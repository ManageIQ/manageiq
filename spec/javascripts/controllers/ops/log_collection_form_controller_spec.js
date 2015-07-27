describe('logCollectionFormController', function() {
  var $scope, $controller, $httpBackend, miqService;

  beforeEach(module('ManageIQ.angularApplication'));

  beforeEach(inject(function(_$httpBackend_, $rootScope, _$controller_, _miqService_) {

  miqService = _miqService_;
  spyOn(miqService, 'miqFlash');
  spyOn(miqService, 'miqAjaxButton');
  spyOn(miqService, 'sparkleOn');
  spyOn(miqService, 'sparkleOff');
  $scope = $rootScope.$new();
  $scope.logCollectionModel = { depot_name:   '',
                                uri:          '',
                                uri_prefix:   '',
                                log_userid:   '',
                                log_password: '',
                                log_verify:   '',
                                log_protocol: ''
                              };

  $httpBackend = _$httpBackend_;

  $controller = _$controller_('logCollectionFormController',
                              {$scope: $scope,
                               $attrs: {'logCollectionFormFieldsUrl': '/ops/log_collection_form_fields/'},
                               miqService: miqService,
                               serverId: 123456
                              });
  }));

  afterEach(function() {
    $httpBackend.verifyNoOutstandingExpectation();
    $httpBackend.verifyNoOutstandingRequest();
  });

  describe('when the log collection form loads a Samba File Depot', function() {
    var logCollectionFormResponse = {
      depot_name:   'my_samba_depot',
      uri:          'smb://smb_location',
      uri_prefix:   'smb',
      log_userid:   'admin',
      log_password: 'smartvm',
      log_verify:   'smartvm',
      log_protocol: 'Samba'
    };

    beforeEach(inject(function() {
      $httpBackend.whenGET('/ops/log_collection_form_fields/123456').respond(200, logCollectionFormResponse);
      $httpBackend.flush();
    }));

    it('sets the depot_name to the value returned from the http request', function () {
      expect($scope.logCollectionModel.depot_name).toEqual('my_samba_depot');
    });

    it('sets the uri to the value returned from the http request', function () {
      expect($scope.logCollectionModel.uri).toEqual('smb://smb_location');
    });

    it('sets the uri_prefix to the value returned from the http request', function () {
      expect($scope.logCollectionModel.uri_prefix).toEqual('smb');
    });

    it('sets the log_userid to the value returned from the http request', function () {
      expect($scope.logCollectionModel.log_userid).toEqual('admin');
    });

    it('sets the log_password to the value returned from the http request', function () {
      expect($scope.logCollectionModel.log_password).toEqual('smartvm');
    });

    it('sets the log_verify to the value returned from the http request', function () {
      expect($scope.logCollectionModel.log_verify).toEqual('smartvm');
    });

    it('sets the log_protocol to the value returned from the http request', function () {
      expect($scope.logCollectionModel.log_protocol).toEqual('Samba');
    });
  });
});
