ManageIQ.angular.app.controller('mwAddJdbcDriverController', MwAddJdbcDriverController);

MwAddJdbcDriverController.$inject = ['$scope', '$http', 'miqService'];

function MwAddJdbcDriverController($scope, $http, miqService) {

  $scope.$on('mwAddJdbcDriverReset', function() {
    $scope.jdbcAddForm.$setPristine();
  });

  $scope.$on('mwAddJdbcDriverEvent', function(event, data) {

    var fd = new FormData();
    fd.append('file', data.filePath);
    fd.append('id', data.serverId);
    fd.append('driverJarName', data.driverJarName);
    fd.append('driverName', data.driverName);
    fd.append('moduleName', data.moduleName);
    fd.append('driverClass', data.driverClass);
    if (data.majorVersion) {
      fd.append('majorVersion', data.majorVersion);
    }
    if (data.minorVersion) {
      fd.append('minorVersion', data.minorVersion);
    }
    $http.post('/middleware_server/add_jdbc_driver', fd, {
      transformRequest: angular.identity,
      headers: {'Content-Type': undefined}
    })
      .then(
        function(result) { // success
          miqService.miqFlash(result.data.status, result.data.msg);
        },
        function() { // error
          miqService.miqFlash('error', 'Unable to add JDBC Driver "' + data.driverName + '" on this server.');
        })
      .finally(function() {
        angular.element("#modal_jdbc_div").modal('hide');
        miqService.sparkleOff();
      });
  });
}
