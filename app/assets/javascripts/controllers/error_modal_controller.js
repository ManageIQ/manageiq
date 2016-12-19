ErrorModalController.$inject = ['$timeout'];
function ErrorModalController($timeout) {
  var $ctrl = this;
  $ctrl.data = null;
  $ctrl.error = null;
  $ctrl.isHtml = false;

  listenToRx(function(event) {
    if ('serverError' in event) {
      $timeout(function() {
        $ctrl.show(event.serverError);
      });
    }
  });

  $ctrl.show = function(err) {
    if (!err || !_.isObject(err)) {
      return;
    }

    $ctrl.data = err.data;
    $ctrl.error = err;
    $ctrl.isHtml = err.headers && err.headers('content-type') && err.headers('content-type').match('text/html');

    // special handling for our error screen
    if ($ctrl.isHtml && $ctrl.data) {
      var m = $ctrl.data.match(/<h2>\s*Error text:\s*<\/h2>\s*<br>\s*<h3>\s*(.*?)\s*<\/h3>/);
      if (m) {
        $ctrl.data = m[1];
      }
    }

    $ctrl.status = (err.status !== -1) ? err.status + " " + err.statusText : "Server not responding";
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
      '          <h4 class="modal-title">',
      '            Server Error',
      '          </h4>',
      '        </div>',
      '        <div class="modal-body">',
      '          <div class="col-xs-12 col-md-2">',
      '            <i class="error-icon pficon-error-circle-o"></i>',
      '          </div>',
      '          <div class="col-xs-12 col-md-10">',
      '            <p>',
      '              <strong>',
      '                Status',
      '              </strong>',
      '              {{$ctrl.status}}',
      '            </p>',
      '            <p>',
      '              <strong>',
      '                Content-Type',
      '              </strong>',
      '              {{$ctrl.error.headers("content-type")}}',
      '            </p>',
      '            <p>',
      '              <strong>',
      '                Data',
      '              </strong>',
      '              {{$ctrl.data}}',
      '            </p>',
      '          </div>',
      '        </div>',
      '        <div class="modal-footer">',
      '          <button type="button" class="btn btn-primary" ng-click="$ctrl.close()">Close</button>',
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
