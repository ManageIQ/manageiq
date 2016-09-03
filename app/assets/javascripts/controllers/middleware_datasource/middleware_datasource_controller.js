ManageIQ.angular.app.controller('mwAddDataSourceController', MwAddDataSourceCtrl);

MwAddDataSourceCtrl.$inject = ['$scope', 'miqService'];

function MwAddDataSourceCtrl($scope, miqService) {

  $scope.dsModel = {};
  $scope.dsModel.step = 'CHOOSE_DS';

  $scope.chooseDsModel = {};
  $scope.chooseDsModel.selectedDatasource;
  $scope.chooseDsModel.datasources = [
    {id : 'POSTGRES', label: 'Postgres'},
    {id: 'ORACLE', label: 'Oracle'},
    {id: 'MSSQL', label: 'Microsoft SQL Server'},
    {id: 'DB2', label: 'IBM DB2'},
    {id: 'SYBASE', label: 'Sybase'},
    {id: 'MYSQL', label: 'MySql'}
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
    miqService.sparkleOn();
    console.log('Calling Add New Datasource');
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

  }

}
