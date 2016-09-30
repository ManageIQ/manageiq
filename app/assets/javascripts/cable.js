//= require action_cable

var miqInitNotifications = function () {
  var cable = ActionCable.createConsumer('/ws/notifications');

  var notifications = cable.subscriptions.create("NotificationChannel", {
    disconnected: function () {
      var _this = this;
      // Try to request a new ws_token if disconnected, reconnecting will happen automatically
      API.ws_init().then(null, function () {
        console.warn("Unable to retrieve a valid ws_token!");
        // Disconnect permanently if the ws_token cannot be fetched
        _this.consumer.connection.close({ allowReconnect: false })
      });
    },
    received: function (data) {
      sendDataWithRx({notification: data});
    }
  });
}
