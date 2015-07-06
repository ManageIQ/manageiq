describe('diagnosticsDatabaseFormController', function() {
  var $scope, $controller, $httpBackend, miqService;

  beforeEach(module('miqAngularApplication'));

  beforeEach(inject(function(_$httpBackend_, $rootScope, _$controller_, _miqService_) {

  miqService = _miqService_;
  spyOn(miqService, 'miqFlash');
  spyOn(miqService, 'miqAjaxButton');
  spyOn(miqService, 'sparkleOn');
  spyOn(miqService, 'sparkleOff');
  $scope = $rootScope.$new();
  $scope.diagnosticsDatabaseModel = { depot_name:   '',
                                      uri:          '',
                                      uri_prefix:   '',
                                      log_userid:   '',
                                      log_password: '',
                                      log_verify:   ''
                                    };

  $httpBackend = _$httpBackend_;

  $controller = _$controller_('diagnosticsDatabaseFormController',
                              {$scope: $scope,
                               $attrs: {'dbBackupFormFieldChangedUrl': '/ops/db_backup_form_field_changed/'},
                               miqService: miqService
                              });
  }));

  afterEach(function() {
    $httpBackend.verifyNoOutstandingExpectation();
    $httpBackend.verifyNoOutstandingRequest();
  });

  describe('when the diagnostics database form loads', function() {
    it('sets the depot_name to blank', function () {
      expect($scope.diagnosticsDatabaseModel.depot_name).toEqual('');
    });

    it('sets the uri to blank', function () {
      expect($scope.diagnosticsDatabaseModel.uri).toEqual('');
    });

    it('sets the uri_prefix to blank', function () {
      expect($scope.diagnosticsDatabaseModel.uri_prefix).toEqual('');
    });

    it('sets the log_userid to blank', function () {
      expect($scope.diagnosticsDatabaseModel.log_userid).toEqual('');
    });

    it('sets the log_password to blank', function () {
      expect($scope.diagnosticsDatabaseModel.log_verify).toEqual('');
    });

    it('sets the log_password to blank', function () {
      expect($scope.diagnosticsDatabaseModel.log_verify).toEqual('');
    });
  });

  describe('when user selects a nfs backup db schedule from dropdown', function() {
    var diagnosticsDBFormResponse = {
      depot_name:   'my_nfs_depot',
      uri:          'nfs://nfs_location',
      uri_prefix:   'nfs',
      log_userid:   null,
      log_password: null,
      log_verify:   null
    };

    beforeEach(inject(function() {
      $httpBackend.whenPOST('/ops/db_backup_form_field_changed/12345').respond(200, diagnosticsDBFormResponse);
      $scope.diagnosticsDatabaseModel.backup_schedule_type = '12345';
      $scope.backupScheduleTypeChanged();
      $httpBackend.flush();
    }));

    it('sets the depot_name to the value returned from the http request', function () {
      expect($scope.diagnosticsDatabaseModel.depot_name).toEqual('my_nfs_depot');
    });

    it('sets the uri to the value returned from the http request', function () {
      expect($scope.diagnosticsDatabaseModel.uri).toEqual('nfs://nfs_location');
    });

    it('sets the uri_prefix to the value returned from the http request', function () {
      expect($scope.diagnosticsDatabaseModel.uri_prefix).toEqual('nfs');
    });

    it('sets the log_userid to the value returned from the http request', function () {
      expect($scope.diagnosticsDatabaseModel.log_userid).toBeNull();
    });

    it('sets the log_password to the value returned from the http request', function () {
      expect($scope.diagnosticsDatabaseModel.log_password).toBeNull();
    });

    it('sets the log_verify to the value returned from the http request', function () {
      expect($scope.diagnosticsDatabaseModel.log_verify).toBeNull();
    });
  });

  describe('when user selects a samba backup db schedule from dropdown', function() {
    var diagnosticsDBFormResponse = {
      depot_name:   'my_samba_depot',
      uri:          'smb://smb_location',
      uri_prefix:   'smb',
      log_userid:   'admin',
      log_password: 'smartvm',
      log_verify:   'smartvm'
    };

    beforeEach(inject(function() {
      $httpBackend.whenPOST('/ops/db_backup_form_field_changed/123456').respond(200, diagnosticsDBFormResponse);
      $scope.diagnosticsDatabaseModel.backup_schedule_type = '123456';
      $scope.backupScheduleTypeChanged();
      $httpBackend.flush();
    }));

    it('sets the depot_name to the value returned from the http request', function () {
      expect($scope.diagnosticsDatabaseModel.depot_name).toEqual('my_samba_depot');
    });

    it('sets the uri to the value returned from the http request', function () {
      expect($scope.diagnosticsDatabaseModel.uri).toEqual('smb://smb_location');
    });

    it('sets the uri_prefix to the value returned from the http request', function () {
      expect($scope.diagnosticsDatabaseModel.uri_prefix).toEqual('smb');
    });

    it('sets the log_userid to the value returned from the http request', function () {
      expect($scope.diagnosticsDatabaseModel.log_userid).toEqual('admin');
    });

    it('sets the log_password to the value returned from the http request', function () {
      expect($scope.diagnosticsDatabaseModel.log_password).toEqual('smartvm');
    });

    it('sets the log_verify to the value returned from the http request', function () {
      expect($scope.diagnosticsDatabaseModel.log_verify).toEqual('smartvm');
    });
  });
});
