ManageIQ.angular.app.controller('middlewareServerController', MiddlewareServerController);

MiddlewareServerController.$inject = ['$scope', 'miqService', 'serverOpsService'];

function MiddlewareServerController($scope, miqService, serverOpsService) {
  ManageIQ.angular.scope = $scope;

  $scope.showListener = function (args) {
    var operation = args.split(':')[1]; // format is 'operation:resume'

    $scope.paramsModel = {};
    if (operation) {
      $scope.paramsModel.operation = operation;
      $scope.paramsModel.operationTitle = makeOperationDisplayName(operation) + ' ' + _('Server');
      $scope.paramsModel.operationButtonName = makeOperationDisplayName(operation);
    }
    $scope.paramsModel.timeout = 10; // default timeout value
  };

  $scope.runOperation = function () {
    miqService.sparkleOn();

    serverOpsService.runOperation(angular.element('#mw_param_server_id').val(),
      $scope.paramsModel.operation,
      $scope.paramsModel.timeout)
      .then(function (response) {
          miqService.miqFlash('success', response);
        },
        function (error) {
          miqService.miqFlash('error', error);

        }).finally(function () {

      miqService.sparkleOff();
    });

  };

  var makeOperationDisplayName = function (operation) {
    return _.capitalize(operation);
  }

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
        },
        function () { // error
          deferred.reject(errorMsg);
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

