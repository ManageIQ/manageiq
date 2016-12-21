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

    spyOn(miqService, 'replacePartials');
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

      var addJDBCDriverResponse = {"explorer":"flash",
        "replacePartials":{
        "flash_msg_div":"\u003cdiv id='flash_msg_div' " +
        "style=''\u003e\n\u003cdiv id='flash_text_div'\u003e\n\u003cdiv " +
        "class='alert alert-success alert-dismissable'\u003e\n\u003cbutton class='close' " +
        "data-dismiss='alert'\u003e\n\u003cspan class='pficon pficon-close'\u003e\u003c/span\u003e\n\u003c/" +
        "button\u003e\n\u003cspan class='pficon pficon-ok'\u003e\u003c/span\u003e\n\u003cstrong\u003eJDBC Driver " +
        "\u0026quot;Custom\u0026quot; has been installed on this server.\u003c/strong\u003e\n\u003c/div\u003e\n\u003c" +
        "/div\u003e\n\u003c/div\u003e\n"}}

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

      expect(miqService.replacePartials).toHaveBeenCalledWith(addJDBCDriverResponse);
      expect(miqService.sparkleOff).toHaveBeenCalled();
    });
  });


});