ManageIQ.angular.app.controller('pglogicalReplicationFormController',['$http', '$scope', 'pglogicalReplicationFormId', 'miqService', function($http, $scope, pglogicalReplicationFormId, miqService) {
  var init = function() {
    $scope.pglogicalReplicationModel = {
      replication_type:'none',
      subscriptions:[],
      addEnabled: false,
      updateEnabled: false
    };
    $scope.formId = pglogicalReplicationFormId;
    $scope.afterGet = false;
    $scope.modelCopy = angular.copy( $scope.pglogicalReplicationModel );

    ManageIQ.angular.scope = $scope;
    $scope.newRecord = false;
    miqService.sparkleOn();
    $http.get('/ops/pglogical_subscriptions_form_fields/' + pglogicalReplicationFormId).success(function(data) {
      $scope.pglogicalReplicationModel.replication_type = data.replication_type;
      $scope.pglogicalReplicationModel.subscriptions = data.subscriptions;

      if ($scope.pglogicalReplicationModel.replication_type == "none")
        miqService.miqFlash("warn", __("No replication role has been set"));

      $scope.afterGet = true;
      $scope.modelCopy = angular.copy( $scope.pglogicalReplicationModel );
      miqService.sparkleOff();
    });

    $scope.$watch("pglogicalReplicationModel.replication_type", function() {
      $scope.form = $scope.angularForm;
      $scope.model = "pglogicalReplicationModel";
    });
  };

  var pglogicalManageSubscriptionsButtonClicked = function(buttonName, serializeFields) {
    miqService.sparkleOn();
    var url = '/ops/pglogical_save_subscriptions/' + pglogicalReplicationFormId + '?button=' + buttonName;
    miqService.miqAjaxButton(url, serializeFields);
  };

  $scope.resetClicked = function() {
    $scope.pglogicalReplicationModel = angular.copy( $scope.modelCopy );
    $scope.angularForm.$setUntouched(true);
    $scope.angularForm.$setPristine(true);
    miqService.miqFlash("warn", __("All changes have been reset"));
  };

  $scope.saveClicked = function() {
    // remove existing subscriptions marked for deletetion before sending them up for save
    $scope.pglogicalReplicationModel.subscriptions.forEach(function(subscription, index, object) {
      // remove subscription from list if they were not updatedin the form
      if (subscription.remove === true || (typeof subscription.id !== 'undefined' && !subscriptionChanged(subscription, $scope.modelCopy.subscriptions[index]))) {
        object.splice(index, 1);
      }
    });
    pglogicalManageSubscriptionsButtonClicked('save', {
      'replication_type': $scope.pglogicalReplicationModel.replication_type,
      'subscriptions' : $scope.pglogicalReplicationModel.subscriptions
    });
    $scope.angularForm.$setPristine(true);
  };

  // check if subscription values have been changed
  var subscriptionChanged = function(new_subscription, original_subscription) {
    if (new_subscription.database  === original_subscription.database &&
        new_subscription.host      === original_subscription.host &&
        new_subscription.username  === original_subscription.username &&
        new_subscription.password  === original_subscription.password &&
        new_subscription.port      === original_subscription.port)
      return false;
    else
      return true;
  }

  $scope.toggleValueForWatch =   function(watchValue, initialValue) {
    if($scope[watchValue] == initialValue)
      $scope[watchValue] = "NO-OP";
    else if($scope[watchValue] == "NO-OP")
      $scope[watchValue] = initialValue;
  };

  // replication type changed, show appropriate flash message
  $scope.replicationTypeChanged = function() {
    miqService.miqFlashClear();
    var original_value = $scope.modelCopy.replication_type;
    var new_value      = $scope.pglogicalReplicationModel.replication_type;
    if ((original_value == "none" && new_value == "none") || (original_value == "remote" && new_value == 'none'))
      miqService.miqFlash("warn", __("No replication role has been set"));
    else if (original_value == "global" && new_value == 'none')
      miqService.miqFlash("warn", __("All current subscriptions will be removed"));
    else if (original_value == "global" && new_value == 'remote')
      miqService.miqFlash("warn", __("Changing to remote replication role will remove all current subscriptions"));

    if (new_value != "global")
      $scope.pglogicalReplicationModel.subscriptions = []
  };

  // add new subscription button pressed
  $scope.enableSubscriptionAdd = function(){
    $scope.pglogicalReplicationModel.updateEnabled = false;
    $scope.pglogicalReplicationModel.addEnabled    = true;
    $scope.pglogicalReplicationModel.database      = '';
    $scope.pglogicalReplicationModel.host          = '';
    $scope.pglogicalReplicationModel.username      = '';
    $scope.pglogicalReplicationModel.password      = '';
    $scope.pglogicalReplicationModel.port          = '5432';
  };

  // update existing subscription button pressed
  $scope.enableSubscriptionUpdate = function(idx){
    var subscription = $scope.pglogicalReplicationModel.subscriptions[idx];
    if (subscription.newRecord === true) {
      $scope.pglogicalReplicationModel.s_index       = idx;
      $scope.pglogicalReplicationModel.updateEnabled = true;
      $scope.pglogicalReplicationModel.database      = subscription.database;
      $scope.pglogicalReplicationModel.host          = subscription.host;
      $scope.pglogicalReplicationModel.username      = subscription.username;
      $scope.pglogicalReplicationModel.password      = subscription.password;
      $scope.pglogicalReplicationModel.port          = subscription.port;
    }
    else if (confirm("An updated subscription must point to the same database with which it was originally created. Failure to do so will result in undefined behavior. Do you want to continue?")) {
      $scope.pglogicalReplicationModel.s_index       = idx;
      $scope.pglogicalReplicationModel.updateEnabled = true;
      $scope.pglogicalReplicationModel.database      = subscription.database;
      $scope.pglogicalReplicationModel.host          = subscription.host;
      $scope.pglogicalReplicationModel.username      = subscription.username;
      $scope.pglogicalReplicationModel.password      = subscription.password;
      $scope.pglogicalReplicationModel.port          = subscription.port;
    }
  };

  // add new subscription
  $scope.addSubscription = function(idx) {
    if (typeof idx == 'undefined') {
      $scope.pglogicalReplicationModel.subscriptions.push({
        database: $scope.pglogicalReplicationModel.database,
        host: $scope.pglogicalReplicationModel.host,
        username: $scope.pglogicalReplicationModel.username,
        password: $scope.pglogicalReplicationModel.password,
        port: $scope.pglogicalReplicationModel.port,
        newRecord: true
      });
    } else {
      var subscription      = $scope.pglogicalReplicationModel.subscriptions[idx];
      subscription.database = $scope.pglogicalReplicationModel.database;
      subscription.host     = $scope.pglogicalReplicationModel.host;
      subscription.username = $scope.pglogicalReplicationModel.username;
      subscription.password = $scope.pglogicalReplicationModel.password;
      subscription.port     = $scope.pglogicalReplicationModel.port;
    }
    $scope.pglogicalReplicationModel.addEnabled = false;
    $scope.pglogicalReplicationModel.updateEnabled = false;
  };

  //delete an existing subscription
  $scope.removeSubscription = function(idx) {
    var subscription = $scope.pglogicalReplicationModel.subscriptions[idx];
    if (subscription.newRecord === true)
      $scope.pglogicalReplicationModel.subscriptions.splice(idx, 1);
    else if (confirm("Deleting a subscription will remove all replicated data which originated in the selected region. Do you want to continue?"))
      subscription.remove = true;
  };

  // discard new subscription add
  $scope.discardSubscription = function(idx) {
    if (typeof idx == 'undefined') {
      $scope.pglogicalReplicationModel.database   = '';
      $scope.pglogicalReplicationModel.host       = '';
      $scope.pglogicalReplicationModel.username   = '';
      $scope.pglogicalReplicationModel.password   = '';
      $scope.pglogicalReplicationModel.port       = '';
      $scope.pglogicalReplicationModel.addEnabled = false;
    } else {
      var original_values = $scope.modelCopy.subscriptions[idx];
      var subscription    = $scope.pglogicalReplicationModel.subscriptions[idx];
      $scope.pglogicalReplicationModel.updateEnabled = false;
      subscription.database = original_values.database;
      subscription.host     = original_values.host;
      subscription.username = original_values.username;
      subscription.password = original_values.password;
      subscription.port     = original_values.port;
    }
  };

  // validate subscription, all required fields should have data
  $scope.subscriptionValid = function() {
    if (typeof $scope.pglogicalReplicationModel.database != 'undefined' && $scope.pglogicalReplicationModel.database !== '' &&
        typeof $scope.pglogicalReplicationModel.host     != 'undefined' && $scope.pglogicalReplicationModel.host     !== '' &&
        typeof $scope.pglogicalReplicationModel.username != 'undefined' && $scope.pglogicalReplicationModel.username !== '' &&
        typeof $scope.pglogicalReplicationModel.password != 'undefined' && $scope.pglogicalReplicationModel.password !== ''
      )
      return true;
    else
      return false;
  }

  $scope.saveEnabled = function() {
    saveable = $scope.angularForm.$dirty && $scope.angularForm.$valid
    if (saveable &&
      $scope.pglogicalReplicationModel.replication_type === "global" &&
      $scope.pglogicalReplicationModel.subscriptions.length >= 1)
      return true;
    else  if (saveable &&
      $scope.pglogicalReplicationModel.replication_type !== "global" &&
      $scope.pglogicalReplicationModel.subscriptions.length == 0)
      return true;
    else
      return false;
  }

  // method to set flag to disable certain buttons when add of subscription in progress
  $scope.addInProgress = function() {
    return $scope.pglogicalReplicationModel.addEnabled == true;
  }

  // validate new/existing subscription
  $scope.validateSubscription = function(idx) {
    var data = {};
    if (typeof idx == 'undefined') {
      data["database"] = $scope.pglogicalReplicationModel.database;
      data["host"]     = $scope.pglogicalReplicationModel.host;
      data["username"] = $scope.pglogicalReplicationModel.username;
      data["password"] = $scope.pglogicalReplicationModel.password;
      data["port"]     = $scope.pglogicalReplicationModel.port;
    } else {
      var subscription = $scope.pglogicalReplicationModel.subscriptions[idx];
      data["database"] = subscription.database;
      data["host"]     = subscription.host;
      data["username"] = subscription.username;
      data["password"] = subscription.password;
      data["port"]     = subscription.port;
    }
    miqService.sparkleOn();
    var url = '/ops/pglogical_validate_subscription/' + pglogicalReplicationFormId;
    miqService.miqAjaxButton(url, data);
  };

  // cancel delete button should be displayed only if existing saved subscriptions were deleted
  $scope.showCancelDelete = function(idx) {
    var subscription = $scope.pglogicalReplicationModel.subscriptions[idx];
    // only show subscriptions in red if they were saved subscriptions and deleted in current edit session
    if (subscription.remove === true)
      return true;
    else
      return false;
  }

  // put back subscription that was deleted into new subscriptions array
  $scope.cancelDelete = function(idx) {
    var subscription = $scope.pglogicalReplicationModel.subscriptions[idx];
    subscription.remove = false;
  }

  $scope.showChanged = function(idx, fieldName) {
    var original_values = $scope.modelCopy.subscriptions[idx];
    // if updating a record use form fields to compare
    if ($scope.pglogicalReplicationModel.updateEnabled) {
      var subscription = {};
      subscription["database"] = $scope.pglogicalReplicationModel.database;
      subscription["host"]     = $scope.pglogicalReplicationModel.host;
      subscription["username"] = $scope.pglogicalReplicationModel.username;
      subscription["password"] = $scope.pglogicalReplicationModel.password;
      subscription["port"]     = $scope.pglogicalReplicationModel.port;
    } else
      var subscription = $scope.pglogicalReplicationModel.subscriptions[idx];

    if (typeof original_values != 'undefined' && original_values[fieldName] != subscription[fieldName])
      return true;
    else
     return false;
  }

  $scope.subscriptionInValidMessage = function(){
    if ($scope.pglogicalReplicationModel.replication_type == 'global' &&
      ($scope.pglogicalReplicationModel.subscriptions.length === 0 ||
      ($scope.pglogicalReplicationModel.subscriptions.length == 1 && $scope.pglogicalReplicationModel.subscriptions[0].remove === true)))
      return true;
    else
      return false;
  }

  init();
}]);
