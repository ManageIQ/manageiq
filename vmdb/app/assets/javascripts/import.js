//= require_directory ./SlickGrid-2.1/

var setUpImportClickHandlers = function(url) {
  $j('.import-commit').click(function() {
    miqSparkleOn();
    clearMessages();

    $j.post(url, $j('#import-form').serialize(), function(data) {
      var flashMessage = JSON.parse(data).first();
      if (flashMessage.level == 'error') {
        showErrorMessage(flashMessage.message);
      } else {
        showSuccessMessage(flashMessage.message);
      }

      $j('.import-or-export').show();
      $j('.import-data').hide();
      miqSparkleOff();
    });
  });

  $j('.import-cancel').click(function() {
    miqSparkleOn();
    clearMessages();

    $j.post('cancel_import', $j('#import-form').serialize(), function(data) {
      var flashMessage = JSON.parse(data).first();
      showSuccessMessage(flashMessage.message);

      $j('.import-or-export').show();
      $j('.import-data').hide();
      miqSparkleOff();
    });
  });

  $j('#toggle-all').click(function() {
    $j('.import-checkbox').prop('checked', this.checked);
  });
};

var clearMessages = function() {
  $j('.import-flash-message .alert').removeClass('alert-success alert-danger alert-warning');
  $j('.icon-placeholder').removeClass('pficon pficon-ok pficon-layered');
  $j('.pficon-error-octagon').removeClass('pficon-error-octagon');
  $j('.pficon-error-exclamation').removeClass('pficon-error-exclamation');
  $j('.pficon-warning-triangle').removeClass('pficon-warning-triangle');
  $j('.pficon-warning-exclamation').removeClass('pficon-warning-exclamation');
};

var flashMessageClickHandler = function() {
  clearMessages();
  this.hide();
};

var showSuccessMessage = function(message) {
  $j('.import-flash-message .alert').addClass('alert-success');
  $j('.icon-placeholder').addClass('pficon-ok').addClass('pficon');
  $j('.import-flash-message .alert .message').html(message);
  $j('.import-flash-message').show();

  $j('.import-flash-message').click(flashMessageClickHandler);
};

var showErrorMessage = function(message) {
  $j('.import-flash-message .alert').addClass('alert-danger');
  $j('.icon-placeholder').addClass('pficon-layered');
  $j('.icon-placeholder .pficon').first().addClass('pficon-error-octagon');
  $j('.icon-placeholder .pficon').last().addClass('pficon-error-exclamation');
  $j('.import-flash-message .alert .message').html(message);
  $j('.import-flash-message').show();

  $j('.import-flash-message').click(flashMessageClickHandler);
};

var showWarningMessage = function(message) {
  $j('.import-flash-message .alert').addClass('alert-warning');
  $j('.icon-placeholder').addClass('pficon-layered');
  $j('.icon-placeholder .pficon').first().addClass('pficon-warning-triangle');
  $j('.icon-placeholder .pficon').last().addClass('pficon-warning-exclamation');
  $j('.import-flash-message .alert .message').html(message);
  $j('.import-flash-message').show();

  $j('.import-flash-message').click(flashMessageClickHandler);
};
