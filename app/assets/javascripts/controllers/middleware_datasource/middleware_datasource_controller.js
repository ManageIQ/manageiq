ManageIQ.angular.app.controller('mwAddDataSourceController', MwAddDataSourceCtrl);

MwAddDataSourceCtrl.$inject = ['$scope', '$http', '$q', 'miqService'];

function MwAddDataSourceCtrl($scope, $http, $q, miqService) {

  $scope.dsModel = {};
  $scope.dsModel.step = 'CHOOSE_DS';

  $scope.chooseDsModel = {};
  $scope.chooseDsModel.selectedDatasource = undefined;
  $scope.chooseDsModel.datasources = [
    {id: 'H2', label: 'H2', name: 'H2DS', jndiName: 'java:/H2DS',
      driverName: 'h2', driverModuleName: 'com.h2database.h2', driverClass: 'org.h2.Driver'},
    {id : 'POSTGRES', label: 'Postgres', name: 'PostgresDS', jndiName: 'java:/PostgresDS',
      driverName: 'postresql', driverModuleName: 'org.postgresql', driverClass: 'org.postgresql.Driver'},
    {id: 'MSSQL', label: 'Microsoft SQL Server', name: 'MSSQLDS', jndiName: 'java:/MSSQLDS',
      driverName: 'sqlserver', driverModuleName: 'com.microsoft',
      driverClass: 'com.microsoft.sqlserver.jdbc.SQLServerDriver'},
    {id: 'ORACLE', label: 'Oracle', name: 'OracleDS', jndiName: 'java:/OracleDS',
      driverName: 'oracle', driverModuleName: 'com.oracle', driverClass: 'oracle.jdbc.driver.OracleDriver'},
    {id: 'DB2', label: 'IBM DB2', name: 'DB2DS', jndiName: 'java:/DB2DS',
      driverName: 'ibmdb2', driverModuleName: 'com.ibm', driverClass: 'COM.ibm.db2.jdbc.app.DB2Driver'},
    {id: 'SYBASE', label: 'Sybase', name: 'SybaseDS', jndiName: 'java:/SybaseDB',
      driverName: 'sybase', driverModuleName: 'com.sybase', driverClass: 'com.sybase.jdbc.SybDriver'},
    {id: 'MYSQL', label: 'MySql', name: 'MySqlDS', jndiName: 'java:/MySqlDS',
      driverName: 'mysql', driverModuleName: 'com.mysql', driverClass: 'com.mysql.jdbc.Driver'}
    ];

  $scope.step1DsModel = {};
  $scope.step1DsModel.datasourceName = '';
  $scope.step1DsModel.jndiName = '';

  $scope.step2DsModel = {};
  $scope.step2DsModel.jdbcDriverName = '';
  $scope.step2DsModel.jdbcModuleName = '';
  $scope.step2DsModel.driverClass = '';
  $scope.step2DsModel.majorVersion = 0;
  $scope.step2DsModel.minorVersion = 0;

  $scope.step3DsModel = {};
  $scope.step3DsModel.connectionUrl = '';
  $scope.step3DsModel.userName = '';
  $scope.step3DsModel.password = '';
  $scope.step3DsModel.securityDomain = '';

  $scope.addDatasourceChooseNext = function() {
    $scope.dsModel.step = 'STEP1';
  };

  $scope.addDatasourceStep1Next = function() {
    $scope.dsModel.step = 'STEP2';
  };

  $scope.addDatasourceStep1Back = function() {
    $scope.dsModel.step = 'CHOOSE_DS';
  };

  $scope.addDatasourceStep2Next = function() {
    $scope.dsModel.step = 'STEP3';
  };

  $scope.addDatasourceStep2Back = function() {
    $scope.dsModel.step = 'STEP1';
  };

  $scope.finishAddDatasource = function () {
    submitJson();
    miqService.sparkleOff();
  };

  $scope.finishAddDatasourceBack = function () {
    $scope.dsModel.step = 'STEP2';
  };

  $scope.reset = function() {
    $scope.dsModel.step = 'CHOOSE_DS';

    $scope.chooseDsModel.selectedDatasource = '';

    $scope.step1DsModel.datasourceName = '';
    $scope.step1DsModel.jndiName = '';

    $scope.step2DsModel.jdbcDriverName = '';
    $scope.step2DsModel.jdbcModuleName = '';
    $scope.step2DsModel.driverClass = '';
    $scope.step2DsModel.majorVersion = 0;
    $scope.step2DsModel.minorVersion = 0;

    $scope.step3DsModel.connectionUrl = '';
    $scope.step3DsModel.userName = '';
    $scope.step3DsModel.password = '';
    $scope.step3DsModel.securityDomain = '';
  };

  var submitJson = function submitJson() {
    var errorMsg = _('Error running add_datasource on this server.');
    var deferred = $q.defer();
    var payload = {
      'id': angular.element('#server_id').val(),
      'xaDatasource': false,
      'datasourceName': $scope.step1DsModel.datasourceName,
      'jndiName': $scope.step1DsModel.jndiName,
      'driverName': $scope.step2DsModel.jdbcDriverName,
      'driverClass': $scope.step2DsModel.driverClass,
      'connectionUrl': $scope.step3DsModel.connectionUrl,
      'userName': $scope.step3DsModel.userName,
      'password': $scope.step3DsModel.password,
      'securityDomain': $scope.step3DsModel.securityDomain
    };

    $http.post('/middleware_server/add_datasource', angular.toJson(payload))
      .then(
        function (response) { // success
          var data = response.data;

          if (data.status === 'ok') {
            deferred.resolve(data.msg);
          } else {
            deferred.reject(data.msg);
          }
        })
      .catch(function () {
        deferred.reject(errorMsg);
      })
      .finally(function () {
        angular.element("#modal_ds_div").modal('hide');
        // we should already be resolved and promises can only fire once
        deferred.resolve(data.msg);
      });
    return deferred.promise;
  }
}
