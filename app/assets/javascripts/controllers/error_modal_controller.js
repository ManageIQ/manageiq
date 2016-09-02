ErrorModalController.$inject = ['$timeout'];
function ErrorModalController($timeout) {
  var $ctrl = this;
  $ctrl.data = null;
  $ctrl.error = null;
  $ctrl.isHtml = false;

  ManageIQ.angular.rxSubject.subscribe(function(event) {
    if ('serverError' in event) {
      $timeout(function() {
        $ctrl.show(event.serverError);
      });
    }
  });

  $ctrl.show = function(err) {
    $ctrl.data = err && err.data;
    $ctrl.error = err;
    $ctrl.isHtml = err && err.headers && err.headers('content-type') && err.headers('content-type').match('text/html');

    // special handling for our error screen
    if ($ctrl.isHtml && $ctrl.data) {
      var m = $ctrl.data.match(/<h2>\s*Error text:\s*<\/h2>\s*<br>\s*<h3>\s*(.*?)\s*<\/h3>/);
      if (m) {
        $ctrl.data = m[1];
      }
    }
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
      '                {{$ctrl.data}}',
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
