ManageIQ.angular.rxSubject = new Rx.Subject();

function sendDataWithRx(data) {
  ManageIQ.angular.rxSubject.next(data);
}

function listenToRx(callback) {
  ManageIQ.angular.rxSubject.subscribe(callback);
}
