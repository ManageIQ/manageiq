ErrorModalController.$inject = ['$timeout'];
function ErrorModalController($timeout) {
  var $ctrl = this;
  $ctrl.error = null;

  ManageIQ.angular.rxSubject.subscribe(function(event) {
    if ('serverError' in event) {
      $timeout(function() {
        $ctrl.show(event.serverError);
      });
    }
  });

  $ctrl.show = function(err) {
    $ctrl.error = err;
  };

  $ctrl.close = function() {
    $ctrl.error = null;
  };
}

angular.module('miq.error', [])
  .component('errorModal', {
    controller: ErrorModalController,

    // inlining the template because it may be harder to GET when the server is down
    template: [
      '<div id="errorModal" ng-class="{ ' + "'modal-open'" + ': $ctrl.error }">',
      '  <div class="modal" ng-class="{ show: $ctrl.error }">',
      '    <div class="modal-dialog">',
      '      <div class="modal-content error-modal-miq">',
      '        <div class="modal-header">',
      '          <button class="close" ng-click="$ctrl.close()">',
      '            <span class="pficon pficon-close">',
      '            </span>',
      '          </button>',
      '        </div>',
      '        <div class="modal-body">',
      '          <h2>',
      '            Server Error',
      '          </h2>',
      '          <div class="fields">',
      '            <ul class="list-unstyled">',
      '              <li>',
      '                <strong>',
      '                  Status',
      '                </strong>',
      '                {{$ctrl.error.status}} {{$ctrl.error.statusText}}',
      '              </li>',
      '              <li>',
      '                <strong>',
      '                  Content-Type',
      '                </strong>',
      '                {{$ctrl.error.headers("content-type")}}',
      '              </li>',
      '              <li>',
      '                <strong>',
      '                  Data',
      '                </strong>',
      '                {{$ctrl.error.data}}',
      '              </li>',
      '            </ul>',
      '          </div>',
      '        </div>',
      '        <div class="modal-footer">',
      '        </div>',
      '      </div>',
      '    </div>',
      '  </div>',
      '</div>',
    ].join("\n"),
  });

$(function() {
  var element = $('<error-modal>');
  element.appendTo(window.document.body);

  miq_bootstrap(element, 'miq.error');
});
