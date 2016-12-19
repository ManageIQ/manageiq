ManageIQ.angular.app.controller('mwServerController', MwServerController);

MwServerController.$inject = ['$scope', 'miqService' ];

/**
 * MwServerController - since there can be only one controller per page due to:
 * 'ManageIQ.angular.scope = $scope;'
 * We are now using Rx.js Observables instead of miqCallAngular, for sending configurable
 * data from miq buttons.
 * This is the parent controller for the page that is bootstrapped,
 * interacting with the page via $scope and then 'sendDataWithRx' events down to the sub
 * controllers to handle them in isolation.
 *
 * Controller Hierarchy is:
 * - MwServerController
 * -- MwServerOpsController
 * -- MwAddDeploymentController
 * -- MwAddDatasourceController
 * -- *Any other controllers (more coming...)
 *
 * This is certainly not ideal, but allows us to use multiple controllers on a page.
 * And provides loose coupling of controllers via events instead of depending on
 * parent/child controller relationships.
 * @param $scope
 * @param miqService
 * @constructor
 */
function MwServerController($scope, miqService) {
  ManageIQ.angular.scope = $scope;

  listenToRx(function(event) {
    var eventType = event.type,
        operation = event.operation,
        timeout = event.timeout;

    $scope.paramsModel = $scope.paramsModel || {};
    if (eventType == 'mwServerOps'  && operation) {
      $scope.paramsModel.serverId = angular.element('#mw_param_server_id').val();
      $scope.paramsModel.operation = operation;
      $scope.paramsModel.operationTitle = formatOpDisplayName(operation) + ' ' + _('Server');
      $scope.paramsModel.operationButtonName = formatOpDisplayName(operation);
      $scope.paramsModel.timeout = timeout;
      $scope.$apply();
    }
  });

  /////////////////////////////////////////////////////////////////////////
  // Server Ops
  /////////////////////////////////////////////////////////////////////////

  $scope.runOperation = function () {
    //$scope.$broadcast('mwSeverOpsEvent', $scope.paramsModel);
    var newMwServerOpsEvent = {},
      mwServerTypePart = {type: 'mwSeverOpsEvent'};
    angular.extend(newMwServerOpsEvent, mwServerTypePart, $scope.paramsModel);
    sendDataWithRx(newMwServerOpsEvent);
  };

  var formatOpDisplayName = function (operation) {
    return _.capitalize(operation);
  };

  /////////////////////////////////////////////////////////////////////////
  // Add Deployment
  /////////////////////////////////////////////////////////////////////////

  $scope.deployAddModel = {};
  $scope.deployAddModel.enableDeployment = true;
  $scope.deployAddModel.forceDeploy = false;
  $scope.deployAddModel.serverId = angular.element('#server_id').val();

  $scope.showDeployListener = function () {
    $scope.deployAddModel.showDeployModal = true;
    $scope.resetDeployForm();
  };

  $scope.showDatasourceListener = function () {
    // just here to 'Button not implemented'
  };

  $scope.resetDeployForm = function () {
    $scope.deployAddModel.enableDeployment = true;
    $scope.deployAddModel.forceDeploy = false;
    $scope.deployAddModel.runtimeName = undefined;
    $scope.deployAddModel.filePath = undefined;
    angular.element('#deploy_div :file#upload_file').val('');
    angular.element('#deploy_div input[type="text"]:disabled').val('');
  };

  $scope.$watch('deployAddModel.filePath', function(newValue) {
    if (newValue) {
      $scope.deployAddModel.runtimeName = newValue.name;
    }
  });

  $scope.addDeployment = function () {
    miqService.sparkleOn();
    $scope.$broadcast('mwAddDeploymentEvent', $scope.deployAddModel);
  };

  /////////////////////////////////////////////////////////////////////////
  // Add JDBC Driver
  /////////////////////////////////////////////////////////////////////////

  $scope.showJdbcDriverListener = function () {
    $scope.resetJdbcDriverForm();
    $scope.jdbcDriverModel.showDeployModal = true;
  };

  $scope.resetJdbcDriverForm = function () {
    $scope.jdbcDriverModel = {};
    $scope.jdbcDriverModel.serverId = angular.element('#server_id').val();
    angular.element('#jdbc_add_div :file#jdbc_driver_file').val('');
    angular.element('#jdbc_add_div input[type="text"]:disabled').val('');
    $scope.$broadcast('mwAddJdbcDriverReset');
  };

  $scope.$watch('jdbcDriverModel.filePath', function(newValue) {
    if (newValue) {
      $scope.jdbcDriverModel.driverJarName = newValue.name;
    }
  });

  $scope.addJdbcDriver = function () {
    miqService.sparkleOn();
    $scope.$broadcast('mwAddJdbcDriverEvent', $scope.jdbcDriverModel);
  };
}

ManageIQ.angular.app.controller('mwServerOpsController', MwServerOpsController);

MwServerOpsController.$inject = ['miqService', 'serverOpsService'];

/**
 * Angular MwServerOpsController to respond to Rx Observable events of type: mwSeverOpsEvent
 * @param miqService
 * @param serverOpsService
 * @constructor
 */
function MwServerOpsController( miqService, serverOpsService) {

    listenToRx(function(event) {

      if(event.type == 'mwSeverOpsEvent') {
        miqService.sparkleOn();

        serverOpsService.runOperation(event.serverId, event.operation, event.timeout)
          .then(function (response) {
              miqService.miqFlash('success', response);
            },
            function (error) {
              miqService.miqFlash('error', error);

            }).finally(function () {

          miqService.sparkleOff();
        });
      }
  });
}

ManageIQ.angular.app.service('serverOpsService', ServerOpsService);

ServerOpsService.$inject = ['$http', '$q'];

function ServerOpsService($http, $q) {
  this.runOperation = function runOperation(id, operation, timeout) {
    var errorMsg = _('Error running operation on this server.');
    var deferred = $q.defer();
    var payload = {
      'id': id,
      'operation': operation,
      'timeout': timeout
    };

    $http.post('/middleware_server/run_operation', angular.toJson(payload))
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
        angular.element("#modal_param_div").modal('hide');
        // we should already be resolved and promises can only fire once
        deferred.resolve(data.msg);
      });
    return deferred.promise;
  }
}

