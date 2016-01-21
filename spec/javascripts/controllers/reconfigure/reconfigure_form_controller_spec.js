describe('reconfigureFormController', function() {
  var $scope, $controller, $httpBackend, miqService;

  beforeEach(module('ManageIQ'));

  beforeEach(inject(function(_$httpBackend_, $rootScope, _$controller_, _miqService_) {
    miqService = _miqService_;
    spyOn(miqService, 'showButtons');
    spyOn(miqService, 'hideButtons');
    spyOn(miqService, 'miqAjaxButton');
    spyOn(miqService, 'sparkleOn');
    spyOn(miqService, 'sparkleOff');
    $scope = $rootScope.$new();

    $httpBackend = _$httpBackend_;
    $httpBackend.whenGET('/provider_foreman/provider_foreman_form_fields/new').respond();
    $controller = _$controller_('reconfigureFormController', {
      $scope: $scope,
      reconfigureFormId: 'new',
      miqService: miqService
    });
  }));

  afterEach(function() {
    $httpBackend.verifyNoOutstandingExpectation();
    $httpBackend.verifyNoOutstandingRequest();
  });

  describe('initialization', function() {
    describe('when the reconfigureFormId is new', function() {
    var reconfigureFormResponse = {
      name: '',
      url: '',
      verify_ssl: false,
      log_userid: ''
    };

    beforeEach(inject(function(_$controller_) {
      $httpBackend.whenGET('/reconfigure_form_fields').respond(reconfigureFormResponse);
      $controller = _$controller_('reconfigureFormController',
        {
          $scope: $scope,
          miqService: miqService
        });
    }));
    it('sets the name to blank', function () {
      expect($scope.reconfigureModel.name).toEqual('');
    });
    it('sets the url to blank', function () {
      expect($scope.reconfigureModel.url).toEqual('');
    });
    it('sets the verify_ssl to blank', function () {
      expect($scope.reconfigureModel.verify_ssl).toBeFalsy();
    });
    it('sets the log_userid to blank', function () {
      expect($scope.reconfigureModel.log_userid).toEqual('');
    });
    it('sets the log_password to blank', function () {
      expect($scope.reconfigureModel.log_password).toEqual('');
    });
    it('sets the log_verify to blank', function () {
      expect($scope.reconfigureModel.log_verify).toEqual('');
    });
  });

    describe('when the reconfigureFormId is an Id', function() {
      var reconfigureFormResponse = {
        name: 'Reconfigure Request',
        url: '10.10.10.10',
        verify_ssl: true,
        log_userid: 'admin'
      };

      beforeEach(inject(function(_$controller_) {
        $httpBackend.whenGET('/provider_foreman/provider_foreman_form_fields/12345').respond(reconfigureFormResponse);
        $controller = _$controller_('reconfigureFormController',
          {
            $scope: $scope,
            reconfigureFormId: '12345',
            miqService: miqService
          });
        $httpBackend.flush();
      }));

      it('sets the name to the value returned from http request', function () {
        expect($scope.reconfigureModel.name).toEqual('Reconfigure request');
      });
      it('sets the url to the value returned from http request', function () {
        expect($scope.reconfigureModel.url).toEqual('10.10.10.10');
      });
      it('sets the verify_ssl to the value returned from http request', function () {
        expect($scope.reconfigureModel.verify_ssl).toBeTruthy();
      });
      it('sets the log_userid to the value returned from http request', function () {
        expect($scope.reconfigureModel.log_userid).toEqual('admin');
      });
      it('sets the log_password to the value returned from http request', function () {
        expect($scope.reconfigureModel.log_password).toEqual(miqService.storedPasswordPlaceholder);
      });
      it('sets the log_verify to the value returned from http request', function () {
        expect($scope.reconfigureModel.log_verify).toEqual(miqService.storedPasswordPlaceholder);
      });
    });
  });

  describe('#resetClicked', function() {
    beforeEach(function() {
      $scope.angularForm = {
        $setPristine: function (value){},
        $setUntouched: function (value){},
      };
      $scope.resetClicked();
    });

    it('does not turn the spinner on', function() {
      expect(miqService.sparkleOn.calls.count()).toBe(0);
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

    it('turns the spinner on once', function() {
      expect(miqService.sparkleOn.calls.count()).toBe(1);
    });

    it('delegates to miqService.miqAjaxButton', function() {
      expect(miqService.miqAjaxButton).toHaveBeenCalledWith('/provider_foreman/edit/new?button=save', true);
    });
  });

  describe('#addClicked', function() {
    beforeEach(function() {
      $scope.angularForm = {
        $setPristine: function (value){}
      };
      $scope.addClicked();
    });

    it('turns the spinner on via the miqService', function() {
      expect(miqService.sparkleOn).toHaveBeenCalled();
    });

    it('delegates to miqService.miqAjaxButton', function() {
      expect(miqService.miqAjaxButton).toHaveBeenCalledWith('reconfigure/edit/new?button=save', true);
    });
  });

  describe('Checks for validateClicked in the scope', function() {
    it('contains validateClicked in the scope', function() {
      expect($scope.validateClicked).toBeDefined();
    });
  });
});
