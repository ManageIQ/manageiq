'use strict';

describe('middlewareAddDatasourceController', function() {
  var rootScope;
  var $scope;
  var miqService;
  var $controller;

  beforeEach(module('ManageIQ'));

  beforeEach(inject(function(_$httpBackend_, _$rootScope_, _$controller_, _miqService_) {
    miqService = _miqService_;
    rootScope = _$rootScope_;
    $scope = rootScope.$new();
    $httpBackend = _$httpBackend_;

    $controller = _$controller_('mwAddDatasourceController', {
      $scope: $scope,
      miqService: miqService,
    });

    $scope.dsAddForm = {
      $setPristine: function(value) {}
    };

    spyOn(rootScope, '$broadcast');
  }));

  describe('Test Add Datasource Controller', function() {
    it('should have first wizard step defined ', function() {
      expect($controller.dsModel.step).toBeDefined();
      expect($controller.dsModel.step).toBe('CHOOSE_DS');
    });

    it('should have datasources populated ', function() {
      expect($controller.chooseDsModel.datasources).toBeDefined();
      expect($controller.chooseDsModel.datasources.length).toBeGreaterThan(1);
    });

    it('should submit fire mwAddDatasourceEvent on finishAddDatasource step', function() {
      $controller.finishAddDatasource();
      expect(rootScope.$broadcast).toHaveBeenCalled();
    });
  });
}
);
