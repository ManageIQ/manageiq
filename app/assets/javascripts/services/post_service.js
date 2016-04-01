ManageIQ.angular.app.service('postService', function(miqService, $timeout, $window) {

  this.saveRecord = function(apiURL, redirectURL, object, successMsg, newRecord) {
    miqService.sparkleOn();
    if (newRecord) {
      return API.post(apiURL,
        angular.toJson({
          resource: object
        })).then(handleSuccess, handleFailure);
    } else {
      return API.post(apiURL,
        angular.toJson({
          action: "edit",
          resource: object
        })).then(handleSuccess, handleFailure);
    }

    function handleSuccess(response) {
      $timeout(function () {
        $window.location.href = redirectURL + '?flash_msg=' + successMsg;
        miqService.sparkleOff();
        miqService.miqFlash("success", successMsg);
      });
    }

    function handleFailure(response) {
      var msg = sprintf(__("Error during 'Service Edit': [%s - %s]"), response.status, response.responseText);
      $timeout(function () {
        $window.location.href = redirectURL + '?flash_msg=' + msg + '&flash_error=true';
        miqService.sparkleOff();
        miqService.miqFlash("error", msg);
      });
    }
  };

  this.cancelOperation = function(redirectURL, msg) {
    $timeout(function () {
      $window.location.href = redirectURL + '?flash_msg=' + msg;
      miqService.sparkleOff();
      miqService.miqFlash("success", msg);
    });
  };
});
