describe('eventNotifications', function() {
  var testService;
  var $scope;

  beforeEach(module('miq.notifications'));

  beforeEach(inject(function(eventNotifications, _$rootScope_) {
    testService = eventNotifications;
    $scope = _$rootScope_;
  }));

  beforeEach(function () {
    $scope.eventsChanged = false;
    $scope.observer = function () {
      $scope.eventsChanged = true;
    };
    testService.registerObserverCallback($scope.observer);
  });

  it('should add to the notifications list and toast notifications when an event is added', function() {
    expect(testService.state().groups.length).toBe(2);

    testService.add(testService.EVENT_NOTIFICATION, testService.INFO, "test message", {}, 1);
    expect(testService.state().groups[0].notifications.length).toBe(1);
  });

  it('should notify observers when an event is added', function() {
    expect($scope.eventsChanged).toBeFalsy();
    testService.add(testService.EVENT_NOTIFICATION, testService.INFO, "test message", {}, 1);
    expect($scope.eventsChanged).toBeTruthy();
  });

  it('should update events', function() {
    testService.add(testService.EVENT_NOTIFICATION, testService.INFO, "test message", {}, 1);
    expect(testService.state().groups[0].notifications[0].type).toBe(testService.INFO);
    expect(testService.state().groups[0].notifications[0].message).toBe("test message");

    testService.update(testService.EVENT_NOTIFICATION, testService.ERROR, "test message", {}, 1);
    expect(testService.state().groups[0].notifications.length).toBe(1);
    expect(testService.state().groups[0].notifications[0].type).toBe(testService.ERROR);
    expect(testService.state().groups[0].notifications[0].message).toBe("test message");
  });

  it('should allow events to be marked as read', function() {
    testService.add(testService.EVENT_NOTIFICATION, testService.INFO, "test info message", {}, 1);
    testService.add(testService.EVENT_NOTIFICATION, testService.ERROR, "test error message", {}, 2);
    testService.add(testService.EVENT_NOTIFICATION, testService.WARNING, "test warning message", {}, 3);

    expect(testService.state().groups[0].notifications.length).toBe(3);

    // Pass group
    expect(testService.state().groups[0].notifications[1].unread).toBeTruthy();
    testService.markRead(testService.state().groups[0].notifications[1], testService.state().groups[0]);
    expect(testService.state().groups[0].notifications[1].unread).toBeFalsy();

    // Do not pass group
    expect(testService.state().groups[0].notifications[2].unread).toBeTruthy();
    testService.markRead(testService.state().groups[0].notifications[2]);
    expect(testService.state().groups[0].notifications[2].unread).toBeFalsy();
  });

  it('should allow events to be marked as unread', function() {
    testService.add(testService.EVENT_NOTIFICATION, testService.INFO, "test info message", {}, 1);
    testService.add(testService.EVENT_NOTIFICATION, testService.ERROR, "test error message", {}, 2);
    testService.add(testService.EVENT_NOTIFICATION, testService.WARNING, "test warning message", {}, 3);

    expect(testService.state().groups[0].notifications.length).toBe(3);

    // Pass group
    expect(testService.state().groups[0].notifications[1].unread).toBeTruthy();
    testService.markRead(testService.state().groups[0].notifications[1], testService.state().groups[0]);
    expect(testService.state().groups[0].notifications[1].unread).toBeFalsy();
    testService.markUnread(testService.state().groups[0].notifications[1], testService.state().groups[0]);
    expect(testService.state().groups[0].notifications[1].unread).toBeTruthy();

    // Do not pass group
    expect(testService.state().groups[0].notifications[2].unread).toBeTruthy();
    testService.markRead(testService.state().groups[0].notifications[2]);
    expect(testService.state().groups[0].notifications[2].unread).toBeFalsy();
    testService.markUnread(testService.state().groups[0].notifications[2]);
    expect(testService.state().groups[0].notifications[2].unread).toBeTruthy();
  });

  it('should allow all events to be marked as read', function() {
    testService.add(testService.EVENT_NOTIFICATION, testService.INFO, "test info message", {}, 1);
    testService.add(testService.EVENT_NOTIFICATION, testService.ERROR, "test error message", {}, 2);
    testService.add(testService.EVENT_NOTIFICATION, testService.WARNING, "test warning message", {}, 3);

    expect(testService.state().groups[0].notifications.length).toBe(3);
    expect(testService.state().groups[0].notifications[0].unread).toBeTruthy();
    expect(testService.state().groups[0].notifications[1].unread).toBeTruthy();
    expect(testService.state().groups[0].notifications[2].unread).toBeTruthy();

    testService.markAllRead(testService.state().groups[0]);

    expect(testService.state().groups[0].notifications[0].unread).toBeFalsy();
    expect(testService.state().groups[0].notifications[1].unread).toBeFalsy();
    expect(testService.state().groups[0].notifications[2].unread).toBeFalsy();
  });

  it('should allow all events to be marked as unread', function() {
    testService.add(testService.EVENT_NOTIFICATION, testService.INFO, "test info message", {}, 1);
    testService.add(testService.EVENT_NOTIFICATION, testService.ERROR, "test error message", {}, 2);
    testService.add(testService.EVENT_NOTIFICATION, testService.WARNING, "test warning message", {}, 3);

    expect(testService.state().groups[0].notifications.length).toBe(3);
    expect(testService.state().groups[0].notifications[0].unread).toBeTruthy();
    expect(testService.state().groups[0].notifications[1].unread).toBeTruthy();
    expect(testService.state().groups[0].notifications[2].unread).toBeTruthy();

    testService.markRead(testService.state().groups[0].notifications[1], testService.state().groups[0]);
    expect(testService.state().groups[0].notifications[1].unread).toBeFalsy();

    testService.markAllUnread(testService.state().groups[0]);

    expect(testService.state().groups[0].notifications[0].unread).toBeTruthy();
    expect(testService.state().groups[0].notifications[1].unread).toBeTruthy();
    expect(testService.state().groups[0].notifications[2].unread).toBeTruthy();
  });

  it('should allow events to be cleared', function() {
    testService.add(testService.EVENT_NOTIFICATION, testService.INFO, "test info message", {}, 1);
    testService.add(testService.EVENT_NOTIFICATION, testService.ERROR, "test error message", {}, 2);
    testService.add(testService.EVENT_NOTIFICATION, testService.WARNING, "test warning message", {}, 3);

    expect(testService.state().groups[0].notifications.length).toBe(3);
    expect(testService.state().groups[0].notifications[0].type).toBe(testService.WARNING);
    expect(testService.state().groups[0].notifications[1].type).toBe(testService.ERROR);
    expect(testService.state().groups[0].notifications[2].type).toBe(testService.INFO);

    // Pass the group
    testService.clear(testService.state().groups[0].notifications[1], testService.state().groups[0]);
    expect(testService.state().groups[0].notifications.length).toBe(2);
    expect(testService.state().groups[0].notifications[0].type).toBe(testService.WARNING);
    expect(testService.state().groups[0].notifications[1].type).toBe(testService.INFO);

    // Do not ass the group
    testService.clear(testService.state().groups[0].notifications[1], testService.state().groups[0]);
    expect(testService.state().groups[0].notifications.length).toBe(1);
    expect(testService.state().groups[0].notifications[0].type).toBe(testService.WARNING);
  });

  it('should allow all events to be cleared', function() {
    testService.add(testService.EVENT_NOTIFICATION, testService.INFO, "test info message", {}, 1);
    testService.add(testService.EVENT_NOTIFICATION, testService.ERROR, "test error message", {}, 2);
    testService.add(testService.EVENT_NOTIFICATION, testService.WARNING, "test warning message", {}, 3);

    expect(testService.state().groups[0].notifications.length).toBe(3);

    testService.clearAll(testService.state().groups[0]);
    expect(testService.state().groups[0].notifications.length).toBe(0);
  });

  it('should show toast notifications', function() {
    var notification = {message: "Test Toast", type: testService.INFO};
    testService.showToast(notification);
    expect(testService.state().toastNotifications.length).toBe(1);
  });

  it('should allow toast notifications to be dismissed', function() {
    var notification = {message: "Test Toast", type: testService.INFO};
    var notification2 = {message: "Test Toast 2", type: testService.ERROR};
    testService.showToast(notification);
    testService.showToast(notification2);
    expect(testService.state().toastNotifications.length).toBe(2);

    testService.dismissToast(notification);
    expect(testService.state().toastNotifications.length).toBe(1);
    expect(testService.state().toastNotifications[0].message).toBe("Test Toast 2");
  });
});
