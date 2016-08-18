ManageIQ.angular.app.controller('mwServerController', MwServerController);

MwServerController.$inject = ['$scope', 'miqService' ];

/**
 * MwServerController - since there can be only one controller per page due to:
 * 'ManageIQ.angular.scope = $scope;' since this is needed by miqCallAngular to
 * showListener via ManageIQ.angular.scope.$apply.
 * This is the parent controller for the page that is bootstrapped,
 * interacting with the page via $scope and then $broadcast events down to the sub
 * controllers to handle them in isolation.
 *
 * Controller Hierarchy is:
 * - MwServerController
 * -- MwServerOpsController
 * -- MwAddDeploymentController
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

  /////////////////////////////////////////////////////////////////////////
  // Server Ops
  /////////////////////////////////////////////////////////////////////////

  $scope.showServerOpsListener = function (args) {
    var operation = args.split(':')[1]; // format is 'operation:resume'

    $scope.paramsModel = {};
    if (operation) {
      $scope.paramsModel.serverId = angular.element('#mw_param_server_id').val();
      $scope.paramsModel.operation = operation;
      $scope.paramsModel.operationTitle = makeOperationDisplayName(operation) + ' ' + _('Server');
      $scope.paramsModel.operationButtonName = makeOperationDisplayName(operation);
    }
    $scope.paramsModel.timeout = 10; // default timeout value
  };

  $scope.runOperation = function () {
    $scope.$broadcast('mwSeverOpsEvent', $scope.paramsModel);
  };

  var makeOperationDisplayName = function (operation) {
    return _.capitalize(operation);
  };

  /////////////////////////////////////////////////////////////////////////
  // Add Deployment
  /////////////////////////////////////////////////////////////////////////

  $scope.deployAddModel = {};
  $scope.deployAddModel.enableDeployment = true;
  $scope.deployAddModel.serverId = angular.element('#server_id').val();

  $scope.showDeployListener = function () {
    $scope.deployAddModel.showDeployModal = true;
    $scope.resetDeployForm();
  };

  $scope.resetDeployForm = function () {
    $scope.enableDeployment = true;
    $scope.runtimeName = undefined;
    $scope.filePath = undefined;
    angular.element('#deploy_div :file#upload_file').val('');
    angular.element('#deploy_div input[type="text"]:disabled').val('');
  };

  $scope.$watch('filePath', function(newValue) {
    if (newValue) {
      $scope.deployAddModel.runtimeName = newValue.name;
    }
  });

  $scope.addDeployment = function () {
    miqService.sparkleOn();
    $scope.$broadcast('mwAddDeploymentEvent', $scope.deployAddModel);
  };
}

ManageIQ.angular.app.controller('mwServerOpsController', MwServerOpsController);

MwServerOpsController.$inject = ['$scope', 'miqService', 'serverOpsService'];

function MwServerOpsController($scope, miqService, serverOpsService) {

  $scope.$on('mwSeverOpsEvent', function(event, data) {
    miqService.sparkleOn();

    serverOpsService.runOperation(data.serverId, data.operation, data.timeout)
      .then(function (response) {
          miqService.miqFlash('success', response);
        },
        function (error) {
          miqService.miqFlash('error', error);

        }).finally(function () {

      miqService.sparkleOff();
    });
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

