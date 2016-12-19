ManageIQ.angular.rxSubject = new Rx.Subject();

function sendDataWithRx(data) {
  ManageIQ.angular.rxSubject.onNext(data);
}
