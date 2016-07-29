ManageIQ.angular.app.service('postService', function(miqService, $timeout, $window) {

  this.saveRecord = function(apiURL, redirectURL, updateObject, successMsg) {
    miqService.sparkleOn();
    return API.post(apiURL,
      angular.toJson({
        action: "edit",
        resource: updateObject
      })).then(handleSuccess, handleFailure);

    function handleSuccess(response) {
      $timeout(function () {
        $window.location.href = redirectURL + '&flash_msg=' + successMsg;
        miqService.sparkleOff();
        miqService.miqFlash("success", successMsg);
      });
    }

    function handleFailure(response) {
      var msg = sprintf(__("Error during Save: [%s - %s]"), response.status, response.responseText);
      $timeout(function () {
        $window.location.href = redirectURL + '&flash_msg=' + msg + '&flash_error=true';
        miqService.sparkleOff();
        miqService.miqFlash("error", msg);
      });
    }
  };

  this.createRecord = function(apiURL, redirectURL, createObject, successMsg) {
    miqService.sparkleOn();
    return API.post(apiURL,
      angular.toJson({
        action: "create",
        resource: createObject
      })).then(handleSuccess, handleFailure);

    function handleSuccess(response) {
      $timeout(function () {
        $window.location.href = redirectURL + '&flash_msg=' + successMsg;
        miqService.sparkleOff();
        miqService.miqFlash("success", successMsg);
      });
    }

    function handleFailure(response) {
      var msg = sprintf(__("Error during Add: [%s - %s]"), response.status, response.responseText);
      $timeout(function () {
        $window.location.href = redirectURL + '&flash_msg=' + msg + '&flash_error=true';
        miqService.sparkleOff();
        miqService.miqFlash("error", msg);
      });
    }
  };

  this.cancelOperation = function(redirectURL, msg) {
    $timeout(function () {
      $window.location.href = redirectURL + '&flash_msg=' + msg;
      miqService.sparkleOff();
      miqService.miqFlash("success", msg);
    });
  };
});

