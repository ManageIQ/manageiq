ManageIQ.angular.app.controller('mwAddDatasourceController', MwAddDatasourceCtrl);
'use strict';

var ADD_DATASOURCE_EVENT = 'mwAddDatasourceEvent';

MwAddDatasourceCtrl.$inject = ['$scope', '$rootScope', 'miqService', 'mwAddDatasourceService'];

function MwAddDatasourceCtrl($scope, $rootScope, miqService, mwAddDatasourceService) {
  var getPayload = function() {
    return {
      'id': angular.element('#server_id').val(),
      'xaDatasource': false,
      'datasourceName': $scope.step1DsModel.datasourceName,
      'jndiName': $scope.step1DsModel.jndiName,
      'driverName': $scope.step2DsModel.jdbcDriverName,
      'driverClass': $scope.step2DsModel.driverClass,
      'connectionUrl': $scope.step3DsModel.connectionUrl,
      'userName': $scope.step3DsModel.userName,
      'password': $scope.step3DsModel.password,
      'securityDomain': $scope.step3DsModel.securityDomain,
    };
  };

  $scope.dsModel = {};
  $scope.dsModel.step = 'CHOOSE_DS';

  $scope.chooseDsModel = {
    selectedDatasource: undefined,
    datasources: undefined,
  };

  $scope.step1DsModel = {
    datasourceName: '',
    jndiName: '',
  };

  $scope.step2DsModel = {
    jdbcDriverName: '',
    jdbcModuleName: '',
    driverClass: '',
    selectedJdbcDriver: '',
    existingJdbcDrivers: [],
    useExistingDriver: false,
  };

  $scope.step3DsModel = {
    validationRegex: /^jdbc:\S+$/,
    connectionUrl: '',
    userName: '',
    password: '',
    securityDomain: '',
  };

  $scope.chooseDsModel.datasources = mwAddDatasourceService.getDatasources();

  $scope.$on(ADD_DATASOURCE_EVENT, function(event, payload) {
    mwAddDatasourceService.sendAddDatasource(payload).then(
      function(result) { // success
        miqService.miqFlash(result.data.status, result.data.msg);
      },
      function(_error) { // error
        miqService.miqFlash('error', __('Unable to install the Datasource on this server.'));
      });
    angular.element('#modal_ds_div').modal('hide');
    miqService.sparkleOff();
  });

  // $scope.$watch('step2DsModel.existingJdbcDrivers', function(value) {
  //   console.log('step2DsModel.existingJdbcDrivers is: ' + value);
  //   console.dir(value);
  //   $scope.step2DsModel.useExistingDriver = value;
  // });

  $scope.addDatasourceChooseNext = function() {
    var dsSelection = $scope.chooseDsModel.selectedDatasource;
    $scope.dsModel.step = 'STEP1';
    $scope.step1DsModel.datasourceName = dsSelection.name;
    $scope.step1DsModel.jndiName = dsSelection.jndiName;
  };

  $scope.addDatasourceStep1Next = function() {
    var dsSelection = $scope.chooseDsModel.selectedDatasource;
    var serverId = angular.element('#server_id').val();
    $scope.dsModel.step = 'STEP2';

    $scope.step2DsModel.jdbcDriverName = dsSelection.driverName;
    $scope.step2DsModel.jdbcModuleName = dsSelection.driverModuleName;
    $scope.step2DsModel.driverClass = dsSelection.driverClass;

    mwAddDatasourceService.getExistingJdbcDrivers(serverId).then(function(result) {
      $scope.step2DsModel.existingJdbcDrivers = result;
    }).catch(function(errorMsg) {
      miqService.miqFlash(errorMsg.data.status, errorMsg.data.msg);
    });
  };

  $scope.addDatasourceStep1Back = function() {
    $scope.reset();
    $scope.dsModel.step = 'CHOOSE_DS';
  };

  $scope.addDatasourceStep2Next = function() {
    $scope.dsModel.step = 'STEP3';
    if ($scope.step2DsModel.useExistingDriver) {
      $scope.step3DsModel.connectionUrl = mwAddDatasourceService.determineConnectionUrlFromExisting($scope.step2DsModel.selectedJdbcDriver);
    } else {
      $scope.step3DsModel.connectionUrl = mwAddDatasourceService.determineConnectionUrl($scope.chooseDsModel.selectedDatasource);
    }
  };

  $scope.addDatasourceStep2Back = function() {
    $scope.dsModel.step = 'STEP1';
  };

  $scope.finishAddDatasource = function() {
    var payload = Object.assign({}, getPayload());
    $rootScope.$broadcast(ADD_DATASOURCE_EVENT, payload);
    $scope.reset();
  };

  $scope.finishAddDatasourceBack = function() {
    $scope.dsModel.step = 'STEP2';
  };

  $scope.reset = function() {
    angular.element('#modal_ds_div').modal('hide');
    $scope.dsAddForm.$setPristine();

    $scope.dsModel.step = 'CHOOSE_DS';

    $scope.chooseDsModel.selectedDatasource = '';

    $scope.step1DsModel.datasourceName = '';
    $scope.step1DsModel.jndiName = '';

    $scope.step2DsModel.jdbcDriverName = '';
    $scope.step2DsModel.jdbcModuleName = '';
    $scope.step2DsModel.driverClass = '';
    $scope.step2DsModel.useExistingDriver = false;
    $scope.step2DsModel.selectedJdbcDriver = '';

    $scope.step3DsModel.connectionUrl = '';
    $scope.step3DsModel.userName = '';
    $scope.step3DsModel.password = '';
    $scope.step3DsModel.securityDomain = '';
  };
}

