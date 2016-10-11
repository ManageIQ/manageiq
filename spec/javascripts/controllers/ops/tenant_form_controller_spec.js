describe('tenantFormController', function() {
  var $scope, $controller, $httpBackend, tenantType, miqService;

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

    $httpBackend.whenGET('/ops/tenant_form_fields/new').respond();
    $controller = _$controller_('tenantFormController', {
      $scope: $scope,
      tenantFormId: 'new',
      tenantType: tenantType,
      miqService: miqService,
    });
  }));

  afterEach(function() {
    $httpBackend.verifyNoOutstandingExpectation();
    $httpBackend.verifyNoOutstandingRequest();
  });

  describe('initialization', function() {
    describe('when the tenantFormId is new', function() {
      it('sets newRecord to true', function() {
        expect($scope.newRecord).toBe(true);
      });

      it('sets afterGet', function() {
        expect($scope.afterGet).toBe(true);
      });
    });

    describe('when the tenantFormId is an id', function() {
      var tenantFormResponse = {
        tenant_name: 'tenantName',
        tenant_description: 'tenantDescription'
      };
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

    it('turns the spinner on once', function() {
      expect(miqService.sparkleOn.calls.count()).toBe(1);
    });

    it('delegates to miqService.miqAjaxButton', function() {
      expect(miqService.miqAjaxButton).toHaveBeenCalledWith('/ops/rbac_tenant_edit/new?button=cancel&divisible=' + tenantType);
    });
  });

  describe('#resetClicked', function() {
    beforeEach(function() {
      $scope.angularForm = {
        $setPristine: function (value){},
        $setUntouched: function (value){},
        filter_value: {
          $name:       'filter_value',
          $setViewValue: function (value){}
        }
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
      expect(miqService.miqAjaxButton).toHaveBeenCalledWith('/ops/rbac_tenant_edit/new?button=save&divisible=' + tenantType, true);
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
      expect(miqService.miqAjaxButton).toHaveBeenCalledWith('/ops/rbac_tenant_edit/new?button=save&divisible='+ tenantType, true);
    });
  });
});})
