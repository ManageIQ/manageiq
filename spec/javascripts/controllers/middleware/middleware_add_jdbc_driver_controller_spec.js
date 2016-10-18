describe('middlewareAddJdbcDriverController', function () {

  var $scope, $controller, $httpBackend, miqService;

  beforeEach(module('ManageIQ'));

  beforeEach(inject(function(_$httpBackend_, $rootScope, _$controller_, _miqService_) {
    miqService = _miqService_;
    $scope = $rootScope.$new();
    $httpBackend = _$httpBackend_;

    $controller = _$controller_('mwAddJdbcDriverController', {
      $scope: $scope,
      miqService: miqService
    });

    spyOn(miqService, 'miqFlash');
    spyOn(miqService, 'sparkleOff');
  }));

  afterEach(function() {
    $httpBackend.verifyNoOutstandingExpectation();
    $httpBackend.verifyNoOutstandingRequest();
  });

  describe('Test Add JDBC Driver Controller', function() {
    it('should generate a proper POST request with FormData', function () {
      var eventData = {
        filePath: '/tmp/custom-jdbc-driver.jar',
        serverId: '99',
        driverJarName: 'custom-jdbc-driver.jar',
        driverName: 'Custom',
        moduleName: 'org.custom',
        driverClass: 'org.custom.',
        majorVersion: '99',
        minorVersion: '11'
      };

      $scope.$broadcast('mwAddJdbcDriverEvent', eventData);

      var addJDBCDriverResponse = {
        'status':'success','msg':'JDBC Driver ' + eventData.driverName + ' has been installed on this server.'};
      $httpBackend.expectPOST('/middleware_server/add_jdbc_driver', function(formData) {
        expect(formData instanceof FormData).toBe(true);

        /* PhantomJS doesn't support this formData.get() API, should be present in v2.5.0
        expect(formData.get('file')).toBe(eventData.filePath);
        expect(formData.get('id')).toBe(eventData.serverId);
        expect(formData.get('driverJarName')).toBe(eventData.driverJarName);
        expect(formData.get('moduleName')).toBe(eventData.moduleName);
        expect(formData.get('driverClass')).toBe(eventData.driverClass);
        expect(formData.get('majorVersion')).toBe(eventData.majorVersion);
        expect(formData.get('minorVersion')).toBe(eventData.minorVersion);
        */

        return true;
      }).respond(200, addJDBCDriverResponse);
      $httpBackend.flush();

      expect(miqService.miqFlash).toHaveBeenCalledWith(addJDBCDriverResponse.status, addJDBCDriverResponse.msg);
      expect(miqService.sparkleOff).toHaveBeenCalled();
    });
  });


});