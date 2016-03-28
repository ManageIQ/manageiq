describe('emsCommonFormController', function() {
  var $scope, $controller, $httpBackend, miqService, compile;

  beforeEach(module('ManageIQ'));

  beforeEach(inject(function(_$httpBackend_, $rootScope, _$controller_, _miqService_, _$compile_) {
    miqService = _miqService_;
    compile = _$compile_;
    spyOn(miqService, 'miqAjaxButton');
    spyOn(miqService, 'restAjaxButton');
    spyOn(miqService, 'sparkleOn');
    spyOn(miqService, 'sparkleOff');
    $scope = $rootScope.$new();

    var emsCommonFormResponse = {
      name: '',
      emstype: '',
      zone: 'default',
      emstype_vm: false,
      openstack_infra_providers_exist: false,
      api_port: '5000',
      api_version: 'v2'
    };
    $httpBackend = _$httpBackend_;
    $httpBackend.whenGET('/ems_cloud/ems_cloud_form_fields/new').respond(emsCommonFormResponse);
    $controller = _$controller_('emsCommonFormController',
      {$scope: $scope,
        $attrs: {'formFieldsUrl': '/ems_cloud/ems_cloud_form_fields/',
          'createUrl': '/ems_cloud',
          'updateUrl': '/ems_cloud/12345'},
        emsCommonFormId: 'new',
        miqService: miqService
      });
  }));

  afterEach(function() {
    $httpBackend.verifyNoOutstandingExpectation();
    $httpBackend.verifyNoOutstandingRequest();
  });

  describe('when the emsCommonFormId is new', function() {
    beforeEach(inject(function() {
      $httpBackend.flush();
    }));

    it('sets the name to blank', function () {
      expect($scope.emsCommonModel.name).toEqual('');
    });

    it('sets the type to blank', function () {
      expect($scope.emsCommonModel.emstype).toEqual('');
    });

    it('sets the zone to default', function() {
      expect($scope.emsCommonModel.zone).toEqual('default');
    });

    it('sets the emstype_vm to false', function() {
      expect($scope.emsCommonModel.emstype_vm).toEqual(false);
    });

    it('sets the openstack_infra_providers_exist to false', function() {
      expect($scope.emsCommonModel.openstack_infra_providers_exist).toEqual(false);
    });

    it('sets the default_api_port to 5000', function() {
      expect($scope.emsCommonModel.default_api_port).toEqual(5000);
    });

    it('sets the amqp_api_port to 5672', function() {
      expect($scope.emsCommonModel.amqp_api_port).toEqual(5672);
    });

    it('sets the api_version to v2', function() {
      expect($scope.emsCommonModel.api_version).toEqual('v2');
    });
  });

  describe('when the emsCommonFormId is an Amazon Id', function() {
    var emsCommonFormResponse = {
      id: 12345,
      name: 'amz',
      emstype: 'ec2',
      zone: 'default',
      emstype_vm: false,
      provider_id: 111,
      openstack_infra_providers_exist: false,
      provider_region: "ap-southeast-2",
      default_userid: "default_user"
    };

    beforeEach(inject(function(_$controller_) {
      $httpBackend.whenGET('/ems_cloud/ems_cloud_form_fields/12345').respond(emsCommonFormResponse);

      $controller = _$controller_('emsCommonFormController',
        {$scope: $scope,
          $attrs: {'formFieldsUrl': '/ems_cloud/ems_cloud_form_fields/',
            'createUrl': '/ems_cloud',
            'updateUrl': '/ems_cloud/12345'},
          emsCommonFormId: 12345,
          miqService: miqService
        });
      $httpBackend.flush();
    }));

    it('sets the name to the Amazon EC2 Cloud Provider', function () {
      expect($scope.emsCommonModel.name).toEqual('amz');
    });

    it('sets the type to ec2', function () {
      expect($scope.emsCommonModel.emstype).toEqual('ec2');
    });

    it('sets the zone to default', function() {
      expect($scope.emsCommonModel.zone).toEqual('default');
    });

    it('sets the emstype_vm to false', function() {
      expect($scope.emsCommonModel.emstype_vm).toEqual(false);
    });

    it('sets the openstack_infra_providers_exist to false', function() {
      expect($scope.emsCommonModel.openstack_infra_providers_exist).toEqual(false);
    });

    it('sets the provider_region', function() {
      expect($scope.emsCommonModel.provider_region).toEqual("ap-southeast-2");
    });

    it('sets the default_userid', function() {
      expect($scope.emsCommonModel.default_userid).toEqual("default_user");
    });

    it('sets the default_password', function() {
      expect($scope.emsCommonModel.default_password).toEqual(miqService.storedPasswordPlaceholder);
    });

    it('sets the default_verify', function() {
      expect($scope.emsCommonModel.default_verify).toEqual(miqService.storedPasswordPlaceholder);
    });
  });

  describe('when the emsCommonFormId is an Openstack Id', function() {
    var emsCommonFormResponse = {
      id: 12345,
      name: 'myOpenstack',
      default_hostname: '10.22.33.44',
      amqp_hostname: '10.20.30.40',
      emstype: 'openstack',
      zone: 'default',
      emstype_vm: false,
      provider_id: 111,
      openstack_infra_providers_exist: false,
      default_userid: "default_user"
    };

    beforeEach(inject(function(_$controller_) {
      $httpBackend.whenGET('/ems_cloud/ems_cloud_form_fields/12345').respond(emsCommonFormResponse);

      $controller = _$controller_('emsCommonFormController',
        {$scope: $scope,
          $attrs: {'formFieldsUrl': '/ems_cloud/ems_cloud_form_fields/',
            'createUrl': '/ems_cloud',
            'updateUrl': '/ems_cloud/update/'},
          emsCommonFormId: 12345,
          miqService: miqService
        });
      $httpBackend.flush();
    }));

    it('sets the name to the Openstack Cloud Provider', function () {
      expect($scope.emsCommonModel.name).toEqual('myOpenstack');
    });

    it('sets the type to openstack', function () {
      expect($scope.emsCommonModel.emstype).toEqual('openstack');
    });

    it('sets the default hostname', function () {
      expect($scope.emsCommonModel.default_hostname).toEqual('10.22.33.44');
    });

    it('sets the amqp hostname', function () {
      expect($scope.emsCommonModel.amqp_hostname).toEqual('10.20.30.40');
    });

    it('sets the zone to default', function() {
      expect($scope.emsCommonModel.zone).toEqual('default');
    });

    it('sets the emstype_vm to false', function() {
      expect($scope.emsCommonModel.emstype_vm).toEqual(false);
    });

    it('sets the openstack_infra_providers_exist to false', function() {
      expect($scope.emsCommonModel.openstack_infra_providers_exist).toEqual(false);
    });

    it('sets the default_userid', function() {
      expect($scope.emsCommonModel.default_userid).toEqual("default_user");
    });

    it('sets the default_password', function() {
      expect($scope.emsCommonModel.default_password).toEqual(miqService.storedPasswordPlaceholder);
    });

    it('sets the default_verify', function() {
      expect($scope.emsCommonModel.default_verify).toEqual(miqService.storedPasswordPlaceholder);
    });
  });

  describe('when the emsCommonFormId is an Azure Id', function() {
    var emsCommonFormResponse = {
      id: 12345,
      name: 'Azure',
      azure_tenant_id: '10.22.33.44',
      subscription: '12345659-1234-41a4-a7ad-3ce6d1091234',
      emstype: 'azure',
      zone: 'default',
      emstype_vm: false,
      provider_id: 111,
      openstack_infra_providers_exist: false,
      default_userid: "default_user"
    };

    beforeEach(inject(function(_$controller_) {
      $httpBackend.whenGET('/ems_cloud/ems_cloud_form_fields/12345').respond(emsCommonFormResponse);

      $controller = _$controller_('emsCommonFormController',
        {$scope: $scope,
          $attrs: {'formFieldsUrl': '/ems_cloud/ems_cloud_form_fields/',
            'createUrl': '/ems_cloud',
            'updateUrl': '/ems_cloud/update/'},
          emsCommonFormId: 12345,
          miqService: miqService
        });
      $httpBackend.flush();
    }));

    it('sets the name to the Azure Cloud Provider', function () {
      expect($scope.emsCommonModel.name).toEqual('Azure');
    });

    it('sets the type to azure', function () {
      expect($scope.emsCommonModel.emstype).toEqual('azure');
    });

    it('sets the azure_tenant_id', function () {
      expect($scope.emsCommonModel.azure_tenant_id).toEqual('10.22.33.44');
    })

    it('sets the subscription', function () {
      expect($scope.emsCommonModel.subscription).toEqual('12345659-1234-41a4-a7ad-3ce6d1091234');
    });

    it('sets the zone to default', function() {
      expect($scope.emsCommonModel.zone).toEqual('default');
    });

    it('sets the emstype_vm to false', function() {
      expect($scope.emsCommonModel.emstype_vm).toEqual(false);
    });

    it('sets the openstack_infra_providers_exist to false', function() {
      expect($scope.emsCommonModel.openstack_infra_providers_exist).toEqual(false);
    });

    it('sets the default_userid', function() {
      expect($scope.emsCommonModel.default_userid).toEqual("default_user");
    });

    it('sets the default_password', function() {
      expect($scope.emsCommonModel.default_password).toEqual(miqService.storedPasswordPlaceholder);
    });

    it('sets the default_verify', function() {
      expect($scope.emsCommonModel.default_verify).toEqual(miqService.storedPasswordPlaceholder);
    });
  });

  describe('#resetClicked', function() {
    beforeEach(function() {
      $httpBackend.flush();
      $scope.angularForm = {
        $setPristine: function (value){},
        $setUntouched: function (value){}
      };
      $scope.resetClicked();
    });

    it('sets total spinner count to be 1', function() {
      expect(miqService.sparkleOn.calls.count()).toBe(1);
    });
  });

  describe('#saveClicked', function() {
    beforeEach(function() {
      $httpBackend.flush();
      $scope.angularForm = {
        $setPristine: function (value){}
      };
      $scope.saveClicked($.Event, true);
    });

    it('turns the spinner on via the miqService', function() {
      expect(miqService.sparkleOn).toHaveBeenCalled();
    });

    it('sets total spinner count to be 2', function() {
      expect(miqService.sparkleOn.calls.count()).toBe(2);
    });

    it('delegates to miqService.restAjaxButton', function() {
      expect(miqService.restAjaxButton).toHaveBeenCalledWith('/ems_cloud/12345?button=save', $.Event.target);
    });
  });

  describe('#addClicked', function() {
    beforeEach(function() {
      $httpBackend.flush();
      $scope.angularForm = {
        $setPristine: function (value){}
      };
      $scope.addClicked($.Event, true);
    });

    it('turns the spinner on via the miqService', function() {
      expect(miqService.sparkleOn).toHaveBeenCalled();
    });

    it('delegates to miqService.restAjaxButton', function() {
      expect(miqService.restAjaxButton).toHaveBeenCalledWith('/ems_cloud?button=add', $.Event.target);
    });
  });

  describe('#cancelClicked', function() {
    beforeEach(function() {
      $httpBackend.flush();
      $scope.angularForm = {
        $setPristine: function (value){}
      };
      $scope.cancelClicked($.Event);
    });

    it('turns the spinner on via the miqService', function() {
      expect(miqService.sparkleOn).toHaveBeenCalled();
    });

    it('delegates to miqService.restAjaxButton', function() {
      expect(miqService.restAjaxButton).toHaveBeenCalledWith('/ems_cloud?button=cancel', $.Event.target);
    });
  });

  describe('Validates credential fields', function() {
    beforeEach(function() {
      $httpBackend.flush();
      var angularForm;
      var element = angular.element(
        '<form name="angularForm">' +
        '<input ng-model="emsCommonModel.hostname" name="hostname" required text />' +
        '<input ng-model="emsCommonModel.default_userid" name="default_userid" required text />' +
        '<input ng-model="emsCommonModel.default_password" name="default_password" required text />' +
        '<input ng-model="emsCommonModel.default_verify" name="default_verify" required text />' +
        '</form>'
      );

      compile(element)($scope);
      $scope.$digest();
      angularForm = $scope.angularForm;

      $scope.angularForm.hostname.$setViewValue('abchost');
      $scope.angularForm.default_userid.$setViewValue('abcuser');
      $scope.angularForm.default_password.$setViewValue('abcpassword');
      $scope.angularForm.default_verify.$setViewValue('abcpassword');
      $scope.currentTab = "default";
      $scope.emsCommonModel.emstype = "ec2";
    });

    it('returns true if all the Validation fields are filled in', function() {
      expect($scope.canValidateBasicInfo()).toBe(true);
    });
  });
});

describe('emsCommonFormController in the context of ems infra provider', function() {
  var $scope, $controller, $httpBackend, miqService, compile;

  beforeEach(module('ManageIQ'));

  beforeEach(inject(function (_$httpBackend_, $rootScope, _$controller_, _miqService_, _$compile_) {
    miqService = _miqService_;
    compile = _$compile_;
    spyOn(miqService, 'miqAjaxButton');
    spyOn(miqService, 'restAjaxButton');
    spyOn(miqService, 'sparkleOn');
    spyOn(miqService, 'sparkleOff');
    $scope = $rootScope.$new();

    var emsCommonFormResponse = {
      name: '',
      emstype: '',
      zone: 'default',
      emstype_vm: false,
      openstack_infra_providers_exist: false,
      api_port: '5000',
      api_version: 'v2'
    };
    $httpBackend = _$httpBackend_;
    $httpBackend.whenGET('/ems_infra/ems_infra_form_fields/new').respond(emsCommonFormResponse);
    $controller = _$controller_('emsCommonFormController',
      {
        $scope: $scope,
        $attrs: {
          'formFieldsUrl': '/ems_infra/ems_infra_form_fields/',
          'createUrl': '/ems_infra',
          'updateUrl': '/ems_infra/12345'
        },
        emsCommonFormId: 'new',
        miqService: miqService
      });
  }));

  afterEach(function () {
    $httpBackend.verifyNoOutstandingExpectation();
    $httpBackend.verifyNoOutstandingRequest();
  });

  describe('when the emsCommonFormId is new', function () {
    beforeEach(inject(function () {
      $httpBackend.flush();
    }));

    it('sets the name to blank', function () {
      expect($scope.emsCommonModel.name).toEqual('');
    });

    it('sets the type to blank', function () {
      expect($scope.emsCommonModel.emstype).toEqual('');
    });

    it('sets the zone to default', function () {
      expect($scope.emsCommonModel.zone).toEqual('default');
    });

    it('sets the api_port to 5000', function () {
      expect($scope.emsCommonModel.api_port).toEqual(5000);
    });

    it('sets the api_version to v2', function () {
      expect($scope.emsCommonModel.api_version).toEqual('v2');
    });
  });

  describe('when the emsCommonFormId is an SCVMM Id', function () {
    var emsCommonFormResponse = {
      id: 12345,
      name: 'msft',
      emstype: 'scvmm',
      zone: 'default',
      security_protocol: "ssl",
      default_userid: "default_user"
    };

    beforeEach(inject(function (_$controller_) {
      $httpBackend.whenGET('/ems_infra/ems_infra_form_fields/12345').respond(emsCommonFormResponse);

      $controller = _$controller_('emsCommonFormController',
        {
          $scope: $scope,
          $attrs: {
            'formFieldsUrl': '/ems_infra/ems_infra_form_fields/',
            'createUrl': '/ems_infra',
            'updateUrl': '/ems_infra/12345'
          },
          emsCommonFormId: 12345,
          miqService: miqService
        });
      $httpBackend.flush();
    }));

    it('sets the name to the SCVMM Infra Provider', function () {
      expect($scope.emsCommonModel.name).toEqual('msft');
    });

    it('sets the type to scvmm', function () {
      expect($scope.emsCommonModel.emstype).toEqual('scvmm');
    });

    it('sets the zone to default', function () {
      expect($scope.emsCommonModel.zone).toEqual('default');
    });

    it('sets the security protocol to ssl', function () {
      expect($scope.emsCommonModel.security_protocol).toEqual('ssl');
    });

    it('sets the default_userid', function () {
      expect($scope.emsCommonModel.default_userid).toEqual("default_user");
    });

    it('sets the default_password', function () {
      expect($scope.emsCommonModel.default_password).toEqual(miqService.storedPasswordPlaceholder);
    });

    it('sets the default_verify', function () {
      expect($scope.emsCommonModel.default_verify).toEqual(miqService.storedPasswordPlaceholder);
    });
  });

  describe('when the emsCommonFormId is an Openstack Id', function () {
    var emsCommonFormResponse = {
      id: 12345,
      name: 'myOpenstack',
      hostname: '10.22.33.44',
      emstype: 'openstack_infra',
      security_protocol: 'ssl',
      zone: 'default',
      api_port: '5000',
      api_version: 'v2',
      default_userid: "default_user",
      amqp_userid: "amqp_user",
      ssh_keypair_userid: "ssh_keypair_user"
    };

    beforeEach(inject(function (_$controller_) {
      $httpBackend.whenGET('/ems_infra/ems_infra_form_fields/12345').respond(emsCommonFormResponse);

      $controller = _$controller_('emsCommonFormController',
        {
          $scope: $scope,
          $attrs: {
            'formFieldsUrl': '/ems_infra/ems_infra_form_fields/',
            'createUrl': '/ems_infra',
            'updateUrl': '/ems_infra/update/'
          },
          emsCommonFormId: 12345,
          miqService: miqService
        });
      $httpBackend.flush();
    }));

    it('sets the name to the Openstack Infra Provider', function () {
      expect($scope.emsCommonModel.name).toEqual('myOpenstack');
    });

    it('sets the type to openstack', function () {
      expect($scope.emsCommonModel.emstype).toEqual('openstack_infra');
    });

    it('sets the hostname', function () {
      expect($scope.emsCommonModel.hostname).toEqual('10.22.33.44');
    });

    it('sets the zone to default', function () {
      expect($scope.emsCommonModel.zone).toEqual('default');
    });

    it('sets the default_userid', function () {
      expect($scope.emsCommonModel.default_userid).toEqual("default_user");
    });

    it('sets the default_password', function () {
      expect($scope.emsCommonModel.default_password).toEqual(miqService.storedPasswordPlaceholder);
    });

    it('sets the default_verify', function () {
      expect($scope.emsCommonModel.default_verify).toEqual(miqService.storedPasswordPlaceholder);
    });

    it('sets the amqp_userid', function () {
      expect($scope.emsCommonModel.amqp_userid).toEqual("amqp_user");
    });

    it('sets the amqp_password', function () {
      expect($scope.emsCommonModel.amqp_password).toEqual(miqService.storedPasswordPlaceholder);
    });

    it('sets the amqp_verify', function () {
      expect($scope.emsCommonModel.amqp_verify).toEqual(miqService.storedPasswordPlaceholder);
    });

    it('sets the ssh_keypair_userid', function () {
      expect($scope.emsCommonModel.ssh_keypair_userid).toEqual("ssh_keypair_user");
    });

    it('sets the ssh_keypair_password', function () {
      expect($scope.emsCommonModel.ssh_keypair_password).toEqual(miqService.storedPasswordPlaceholder);
    });

    it('sets the ssh_keypair_verify', function () {
      expect($scope.emsCommonModel.ssh_keypair_verify).toEqual(miqService.storedPasswordPlaceholder);
    });
  });
});
