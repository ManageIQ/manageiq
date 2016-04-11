describe('tenantQuotaFormController', function() {
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
    $controller = _$controller_('tenantQuotaFormController', {
      $scope: $scope,
      tenantQuotaFormId: 1000000000001,
      tenantType: '',
      miqService: miqService
    });
  }));

  beforeEach(inject(function(_$controller_) {
    var tenantQuotaFormResponse = {
      name: 'Test tenant',
      quotas: {
        cpu_allocated:{unit:'mhz', format: 'mhz', text_modifier: 'Mhz', description:'Allocated CPU in Mhz',value: 1024.0},
        mem_allocated:{unit: 'bytes', format: 'gigabytes_human', text_modifier: 'GB', description:'Allocated Memory in GB', value: 4096.0 * 1024 *1024 *1024},
        storage_allocated: {unit: 'bytes', format: "gigabytes_human", text_modifier: 'GB', description: 'Allocated Storage in GB', value: null}
        }
      };
      $httpBackend.whenGET('/ops/tenant_quotas_form_fields/1000000000001').respond(tenantQuotaFormResponse);
      $httpBackend.flush();
  }));

  afterEach(function() {
    $httpBackend.verifyNoOutstandingExpectation();
    $httpBackend.verifyNoOutstandingRequest();
  });

  describe('initialization', function() {
    it('sets the quotas to the values in the hash returned via the http request', function() {
      var quotas =  {
        cpu_allocated:{unit:'mhz', format: 'mhz', text_modifier: 'Mhz', description:'Allocated CPU in Mhz',value: 1024.0, enforced:true, valpattern:/^\s*(?=.*[1-9])\d*(?:\.\d{1,6})?\s*$/},
        mem_allocated:{unit: 'bytes', format: 'gigabytes_human', text_modifier: 'GB', description:'Allocated Memory in GB', value: 4096.0, enforced:true, valpattern:/^\s*(?=.*[1-9])\d*(?:\.\d{1,6})?\s*$/},
        storage_allocated: {unit: 'bytes', format: "gigabytes_human", text_modifier: 'GB', description: 'Allocated Storage in GB', value: null, enforced:false, valpattern:/^\s*(?=.*[1-9])\d*(?:\.\d{1,6})?\s*$/}
      };
      expect($scope.tenantQuotaModel.quotas).toEqual(quotas);
    });
    it('sets the tenant name to the value returned via the http request', function() {
      expect($scope.tenantQuotaModel.name).toEqual('Test tenant');
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
      expect(miqService.miqAjaxButton).toHaveBeenCalledWith('/ops/rbac_tenant_manage_quotas/1000000000001?button=cancel&divisible=', undefined);
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
      expect(miqService.miqAjaxButton).toHaveBeenCalledWith('/ops/rbac_tenant_manage_quotas/1000000000001?button=save&divisible=', { quotas: {
        cpu_allocated: {value: 1024},
        mem_allocated: {value: 4096*1024*1024*1024}
      }});
    });
  });
});
