ManageIQ.notification = ManageIQ.notifications.subscriptions.create("NotificationChannel", {
  connected: function () {},
  disconnected: function () {},
  received: function (data) {
    var _this = this;
    var level2class = {
      error:   'danger',
      warning: 'warning',
      info:    'info',
      success: 'success'
    };

    var level2icon = {
      error:   'error-circle-o',
      warning: 'warning-triangle-o',
      info:    'info',
      success: 'ok'
    };

    var toast = $('<div>')
      .addClass('toast-pf toast-pf-max-width toast-pf-top-right alert alert-dismissable col-xs-12')
      .addClass('alert-' + level2class[data.level]);
    var button = $('<div>')
      .addClass('close')
      .attr('type', 'button')
      .data('dismiss', 'alert')
      .attr('aria-hidden', true)
      .append($('<span>').addClass('pficon pficon-close'));
    var icon = $('<span>').addClass('pficon pficon-' + level2icon[data.level]);

    toast.append(button, icon, data.message);
    $('body').prepend(toast);

    var dismissMessage = function () {
      toast.remove();
    };

    button.click(function () {
      dismissMessage();
      _this.perform('mark', data);
    });

    setTimeout(dismissMessage, 3000);
  }
});
