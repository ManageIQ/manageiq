

ManageIQ.angular.app.controller('middlewareServerController', MiddlewareServerController);

MiddlewareServerController.$inject = ['$scope', '$http', 'miqService'];

function MiddlewareServerController($scope, $http, miqService) {
  ManageIQ.angular.scope = $scope;

  $scope.showListener = function (args) {
    var operation = args[0].split(':')[1]; // format is 'operation:XXXXX'

    $scope.paramsModel = {};
    if(operation){
      $scope.paramsModel.operation = operation;
      $scope.paramsModel.operationTitle = makeOperationDisplayName(operation) + ' ' +_('Server');
      $scope.paramsModel.operationButtonName = makeOperationDisplayName(operation);
    }
    $scope.paramsModel.timeout = 10; // default timeout value
  };

  $scope.runOperation = function (operation) {
    miqService.sparkleOn();

    var payload =  {
      'id': angular.element('#mw_param_server_id').val(),
      'timeout': $scope.paramsModel.timeout,
      'operation': $scope.paramsModel.operation,
    };

    $http.post('/middleware_server/run_operation', angular.toJson(payload))
      .then(
        function(response) { // success
          var data = response.data;

          if(data.status === 'ok'){
            miqService.miqFlash('success', data.msg);
          }else {
            $log.error(data);
            miqService.miqFlash('error', data.msg);
          }
        },
        function() { // error
          miqService.miqFlash('error', _('Error running operation on this server.'));
        })
      .finally(function() {
        angular.element("#modal_param_div").modal('hide');
        miqService.sparkleOff();
      });
  };

  var makeOperationDisplayName = function(operation){
    return  _.capitalize(operation);
  }
  
}
