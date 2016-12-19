angular.module('miq.notifications')
  .service('eventNotifications', eventNotifications);

eventNotifications.$inject = ['$timeout'];

function eventNotifications($timeout) {
  if (!ManageIQ.angular.eventNotificationsData) {
    ManageIQ.angular.eventNotificationsData = {
      state: {
        groups: [],
        unreadNotifications: false,
        toastNotifications: [],
        drawerShown: false
      },
      toastDelay: 8 * 1000,
      observerCallbacks: []
    };
  }

  // psudo constants
  this.EVENT_NOTIFICATION = 'event';
  this.TASK_NOTIFICATION = 'task';

  this.ERROR = 'danger';
  this.WARNING = 'warning';
  this.INFO = 'info';
  this.SUCCESS = 'success';

  var state = ManageIQ.angular.eventNotificationsData.state;
  var observerCallbacks = ManageIQ.angular.eventNotificationsData.observerCallbacks;
  var _this = this;

  var updateUnreadCount = function(group) {
    if (group) {
      group.unreadCount = group.notifications.filter(function(notification) {
        return notification.unread;
      }).length;
    }
    state.unreadNotifications = state.groups.find(function(nextGroup) {
        return nextGroup.unreadCount > 0;
      }) !== undefined;
  };

  var notifyObservers = function(){
    angular.forEach(observerCallbacks, function(callback){
      callback();
    });
  };

  this.doReset = function(seed) {
    state.groups.splice(0, state.groups.length);
    var events = {
      notificationType: this.EVENT_NOTIFICATION,
      heading: __("Events"),
      unreadCount: 0,
      notifications: []
    }
    state.groups.push(events);
    state.groups.push(
      {
        notificationType: this.TASK_NOTIFICATION,
        heading: __("Tasks"),
        unreadCount: 0,
        notifications: []
      }
    );
    state.unreadNotifications = false;
    state.toastNotifications = [];

    if (seed) {
      API.get('/api/notifications?expand=resources&attributes=details')
      .then(function (data) {
        data.resources.forEach(function(resource) {
          var msg = miqFormatNotification(resource.details.text, resource.details.bindings);
          events.notifications.splice(0, 0, {
            id: resource.id,
            notificationType: _this.EVENT_NOTIFICATION,
            unread: !resource.seen,
            type: resource.details.level,
            message: msg,
            data: {
              message: msg
            },
            href: resource.href,
            timeStamp: resource.details.created_at
          });
        });

        updateUnreadCount(events);
        notifyObservers();
      });
    }
  };

  this.registerObserverCallback = function(callback){
    observerCallbacks.push(callback);
  };

  this.unregisterObserverCallback = function(callback){
    var index = observerCallbacks.indexOf(callback);
    if (index > -1) {
      observerCallbacks.splice(index, 1);
    }
  };

  this.state = function() {
    return state;
  };

  this.setDrawerShown = function(shown) {
    state.drawerShown = shown;
    notifyObservers();
  };

  this.add = function(notificationType, type, message, notificationData, id) {
    var newNotification = {
      id: id,
      notificationType: notificationType,
      unread: true,
      type: type,
      message: message,
      data: notificationData,
      href: id ? '/api/notifications/' + id : undefined,
      timeStamp: (new Date()).getTime()
    };

    var group = state.groups.find(function(notificationGroup) {
      return notificationGroup.notificationType === notificationType;
    });
    if (group) {
      if (group.notifications) {
        group.notifications.splice(0, 0, newNotification);
      } else {
        group.notifications = [newNotification];
      }
      updateUnreadCount(group);
    }
    this.showToast(newNotification);
    notifyObservers();
  };

  this.update = function(notificationType, type, message, notificationData, id, showToast) {
    var notification;
    var group = state.groups.find(function(notificationGroup) {
      return notificationGroup.notificationType === notificationType;
    });

    if (group) {
      notification = group.notifications.find(function(notification) {
        return notification.id === id;
      });

      if (notification) {
        if (showToast) {
          notification.unread = true;
        }
        notification.type = type;
        notification.message = message;
        notification.data = notificationData;
        notification.timeStamp = (new Date()).getTime();
        updateUnreadCount(group);
      }
    }

    if (showToast) {
      if (!notification) {
        notification = {
          type: type,
          message: message
        };
      }

      this.showToast(notification);
    }
    notifyObservers();
  };

  this.markRead = function(notification, group) {
    if (notification) {
      notification.unread = false;
      this.removeToast(notification);
      if (notification.href) {
        API.post(notification.href, {action: 'mark_as_seen'});
      }
    }
    if (group) {
      updateUnreadCount(group);
    } else {
      state.groups.forEach(function(group) {
        updateUnreadCount(group);
      });
    }
    notifyObservers();
  };

  this.markUnread = function(notification, group) {
    if (notification) {
      notification.unread = true;
    }
    if (group) {
      updateUnreadCount(group);
    } else {
      state.groups.forEach(function(group) {
        updateUnreadCount(group);
      });
    }
    notifyObservers();
  };

  this.markAllRead = function(group) {
    if (group) {
      var resources = group.notifications.map(function(notification) {
        notification.unread = false;
        _this.removeToast(notification);
        return { href: notification.href };
      }).filter(function (notification) { return notification.href });
      if (resources.length > 0) {
        API.post('/api/notifications', {action: 'mark_as_seen', resources: resources});
      }
      group.unreadCount = 0;
      updateUnreadCount();
    }
    notifyObservers();
  };

  this.markAllUnread = function(group) {
    if (group) {
      group.notifications.forEach(function(notification) {
        notification.unread = true;
      });
      group.unreadCount = group.notifications.length;
      updateUnreadCount();
      notifyObservers();
    }
  };

  this.clear = function(notification, group) {
    var index;

    if (notification) {
      this.removeToast(notification);
      if (notification.href) {
        API.delete(notification.href);
      }
    }

    if (!group) {
      group = state.groups.find(function(nextGroup) {
        return notification.notificationType === nextGroup.notificationType;
      });
    }

    if (group) {
      index = group.notifications.indexOf(notification);
      if (index > -1) {
        group.notifications.splice(index, 1);
        updateUnreadCount(group);
        notifyObservers();
      }
    }
  };

  this.clearAll = function(group) {
    if (group) {
      var resources = group.notifications.map(function(notification) {
        _this.removeToast(notification);
        return { href: notification.href };
      }).filter(function (notification) { return notification.href });
      if (resources.length > 0) {
        API.post('/api/notifications', {action: 'delete', resources: resources});
      }
      group.notifications = [];
      updateUnreadCount(group);
      notifyObservers();
    }
  };

  this.removeToast = function(notification) {
    var index = state.toastNotifications.indexOf(notification);
    if (index > -1) {
      state.toastNotifications.splice(index, 1);
      notifyObservers();
    }
  };

  this.showToast = function(notification, persist) {
    var $this = this;
    notification.show = true;
    state.toastNotifications.push(notification);
    notifyObservers();

    // any toast notifications with out 'danger' or 'error' status are automatically removed after a delay
    if (persist !== true && notification.type !== 'danger' && notification.type !== 'error') {
      notification.viewing = false;
      $timeout(function() {
        notification.show = false;
        if (!notification.viewing) {
          $this.removeToast(notification);
        }
      }, ManageIQ.angular.eventNotificationsData.toastDelay);
    }
  };

  this.setViewingToast = function(notification, viewing) {
    notification.viewing = viewing;
    if (!viewing && !notification.show) {
      this.removeToast(notification);
    }
  };

  this.dismissToast = function(notification) {
    notification.show = false;
    this.removeToast(notification);
  };

  this.doReset(true);

  listenToRx(function (data) {
    if (data.notification) {
      var msg = miqFormatNotification(data.notification.text, data.notification.bindings);
      _this.add('event', data.notification.level, msg, {message: msg}, data.notification.id);
    }
  });
}
