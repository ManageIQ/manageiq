describe('CredentialsController', function() {
  var $scope, $controller, $httpBackend, miqService;

  beforeEach(module('ManageIQ'));

  beforeEach(inject(function(_$httpBackend_, $rootScope, _$controller_, _miqService_) {
    miqService = _miqService_;
    $scope = $rootScope.$new();
    $httpBackend = _$httpBackend_;
    $scope.model = "hostModel";
    $controller = _$controller_('CredentialsController',
      {$http: $httpBackend, $scope: $scope, miqService: miqService});
  }));

  afterEach(function() {
    $httpBackend.verifyNoOutstandingExpectation();
    $httpBackend.verifyNoOutstandingRequest();
  });

  describe('when formId is new', function() {
    beforeEach(inject(function(_$httpBackend_, $rootScope, _$controller_) {
      $scope.formId = 'new';
      $controller = _$controller_('CredentialsController',
        {$http: $httpBackend, $scope: $scope, miqService: miqService});
    }));
    it('initializes stored password state flags for new records', function() {
      expect($scope.newRecord).toBeTruthy();
      expect($scope.bChangeStoredPassword).toBeUndefined();
      expect($scope.bCancelPasswordChange).toBeUndefined();
    });
  });

  describe('when formId is not new', function() {
    beforeEach(inject(function(_$httpBackend_, $rootScope, _$controller_) {
      $scope.formId = '12345';
      $controller = _$controller_('CredentialsController',
        {$http: $httpBackend, $scope: $scope, miqService: miqService});
    }));
    it('initializes stored password state flags for existing records', function() {
      expect($scope.newRecord).toBeFalsy();
      expect($scope.bChangeStoredPassword).toBeFalsy();
      expect($scope.bCancelPasswordChange).toBeFalsy();
    });
  });

  it('sets proper values when Change Stored Password is clicked', function() {
    $scope.changeStoredPassword();
    expect($scope.bChangeStoredPassword).toBeTruthy();
    expect($scope.bCancelPasswordChange).toBeFalsy();
  });

  it('sets proper values when Cancel Password change is clicked', function() {
    $scope.changeStoredPassword();
    $scope.cancelPasswordChange();
    expect($scope.bChangeStoredPassword).toBeFalsy();
    expect($scope.bCancelPasswordChange).toBeTruthy();
  });

  it('shows Verify Password field when record is new', function() {
    $scope.newRecord = true;
    expect($scope.showVerify('default_userid')).toBeTruthy();
  });

  it('shows Verify Password field only after Change Stored Password is clicked', function() {
    $scope.hostModel = {'default_userid': 'abc', 'default_password': '********', 'default_verify': '********'};
    $scope.modelCopy = angular.copy( $scope.hostModel );
    expect($scope.showVerify('default_userid')).toBeFalsy();
    $scope.changeStoredPassword();
    expect($scope.showVerify('default_userid')).toBeTruthy();
  });

  it('shows Verify Password field when record is not new, userid does not exist', function() {
    $scope.newRecord = false;
    $scope.hostModel = {'default_userid': '', 'default_password': '', 'default_verify': ''};
    $scope.modelCopy = angular.copy( $scope.hostModel );
    expect($scope.showVerify('default_userid')).toBeTruthy();
  });

  it('shows password change links when record is not new and userid exists', function() {
    $scope.newRecord = false;
    $scope.hostModel = {'default_userid': 'abc', 'default_password': '********', 'default_verify': '********'};
    $scope.modelCopy = angular.copy( $scope.hostModel );
    expect($scope.showChangePasswordLinks('default_userid')).toBeTruthy();
  });

  it('does not show password change links when record is not new and userid does not exist', function() {
    $scope.newRecord = false;
    $scope.hostModel = {'default_userid': '', 'default_password': '', 'default_verify': ''};
    $scope.modelCopy = angular.copy( $scope.hostModel );
    expect($scope.showChangePasswordLinks('default_userid')).toBeFalsy();
  });

  it('does not show password change links when record is not new, userid did not exist before but is now filled in by the user', function() {
    $scope.newRecord = false;
    $scope.hostModel = {'default_userid': '', 'default_password': '', 'default_verify': ''};
    $scope.modelCopy = angular.copy( $scope.hostModel );
    $scope.hostModel.default_userid = 'xyz';
    expect($scope.showChangePasswordLinks('default_userid')).toBeFalsy();
  });

  it('restores the flag values to original state when reset is clicked after Change stored password link was clicked', function() {
    $scope.changeStoredPassword();
    $scope.resetClicked();
    expect($scope.bCancelPasswordChange).toBeTruthy();
    expect($scope.bChangeStoredPassword).toBeFalsy();
  });

  it('restores the flag values to original state when reset is clicked before Change stored password link was clicked', function() {
    $scope.resetClicked();
    expect($scope.bCancelPasswordChange).toBeFalsy();
    expect($scope.bChangeStoredPassword).toBeFalsy();
  });
});
