ManageIQ.angular.app.controller('mwAddDatasourceController', MwAddDatasourceCtrl);

DATASOURCE_EVENT = 'mwAddDatasourceEvent';

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
  };

  $scope.step3DsModel = {
    validationRegex: /^jdbc:\S+$/,
    connectionUrl: '',
    userName: '',
    password: '',
    securityDomain: '',
  };

  $scope.chooseDsModel.datasources = mwAddDatasourceService.getDatasources();

  $scope.$on(DATASOURCE_EVENT, function(event, payload) {
    mwAddDatasourceService.sendAddDatasource(payload);
    angular.element('#modal_ds_div').modal('hide');
    miqService.sparkleOff();
  });

  $scope.addDatasourceChooseNext = function() {
    var dsSelection = $scope.chooseDsModel.selectedDatasource;
    $scope.dsModel.step = 'STEP1';
    $scope.step1DsModel.datasourceName = dsSelection.name;
    $scope.step1DsModel.jndiName = dsSelection.jndiName;
  };

  $scope.addDatasourceStep1Next = function() {
    var dsSelection = $scope.chooseDsModel.selectedDatasource;
    $scope.dsModel.step = 'STEP2';

    $scope.step2DsModel.jdbcDriverName = dsSelection.driverName;
    $scope.step2DsModel.jdbcModuleName = dsSelection.driverModuleName;
    $scope.step2DsModel.driverClass = dsSelection.driverClass;
  };

  $scope.addDatasourceStep1Back = function() {
    $scope.dsModel.step = 'CHOOSE_DS';
  };

  $scope.addDatasourceStep2Next = function() {
    var dsSelection = $scope.chooseDsModel.selectedDatasource;
    $scope.dsModel.step = 'STEP3';
    $scope.step3DsModel.connectionUrl = mwAddDatasourceService.determineConnectionUrl(dsSelection);
  };

  $scope.addDatasourceStep2Back = function() {
    $scope.dsModel.step = 'STEP1';
  };

  $scope.finishAddDatasource = function() {
    var payload = Object.assign({}, getPayload());
    $rootScope.$broadcast(DATASOURCE_EVENT, payload);
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
    $scope.step3DsModel.connectionUrl = '';
    $scope.step3DsModel.userName = '';
    $scope.step3DsModel.password = '';
    $scope.step3DsModel.securityDomain = '';
  };
}

