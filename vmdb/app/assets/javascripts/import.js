//= require_directory ./SlickGrid-2.1/

var setUpImportClickHandlers = function(url, importCallback) {
  $('.import-commit').click(function() {
    miqSparkleOn();
    clearMessages();

    $.post(url, $('#import-form').serialize(), function(data) {
      var flashMessage = data[0];
      if (flashMessage.level == 'error') {
        showErrorMessage(flashMessage.message);
      } else {
        showSuccessMessage(flashMessage.message);
      }

      $('.import-or-export').show();
      $('.import-data').hide();

      if (importCallback !== undefined) {
        importCallback();
      }

      miqSparkleOff();
    }, 'json');
  });

  $('.import-cancel').click(function() {
    miqSparkleOn();
    clearMessages();

    $.post('cancel_import', $('#import-form').serialize(), function(data) {
      var flashMessage = data[0];
      showSuccessMessage(flashMessage.message);

      $('.import-or-export').show();
      $('.import-data').hide();
      miqSparkleOff();
    }, 'json');
  });

  $('#toggle-all').click(function() {
    $('.import-checkbox').prop('checked', this.checked);
  });
};

var clearMessages = function() {
  $('.import-flash-message .alert').removeClass('alert-success alert-danger alert-warning');
  $('.icon-placeholder').removeClass('pficon pficon-ok pficon-layered');
  $('.pficon-error-octagon').removeClass('pficon-error-octagon');
  $('.pficon-error-exclamation').removeClass('pficon-error-exclamation');
  $('.pficon-warning-triangle').removeClass('pficon-warning-triangle');
  $('.pficon-warning-exclamation').removeClass('pficon-warning-exclamation');
};

var flashMessageClickHandler = function() {
  clearMessages();
  this.hide();
};

var showSuccessMessage = function(message) {
  $('.import-flash-message .alert').addClass('alert-success');
  $('.icon-placeholder').addClass('pficon-ok').addClass('pficon');
  $('.import-flash-message .alert .message').html(message);
  $('.import-flash-message').show();

  $('.import-flash-message').click(flashMessageClickHandler);
};

var showErrorMessage = function(message) {
  $('.import-flash-message .alert').addClass('alert-danger');
  $('.icon-placeholder').addClass('pficon-layered');
  $('.icon-placeholder .pficon').first().addClass('pficon-error-octagon');
  $('.icon-placeholder .pficon').last().addClass('pficon-error-exclamation');
  $('.import-flash-message .alert .message').html(message);
  $('.import-flash-message').show();

  $('.import-flash-message').click(flashMessageClickHandler);
};

var showWarningMessage = function(message) {
  $('.import-flash-message .alert').addClass('alert-warning');
  $('.icon-placeholder').addClass('pficon-layered');
  $('.icon-placeholder .pficon').first().addClass('pficon-warning-triangle');
  $('.icon-placeholder .pficon').last().addClass('pficon-warning-exclamation');
  $('.import-flash-message .alert .message').html(message);
  $('.import-flash-message').show();

  $('.import-flash-message').click(flashMessageClickHandler);
};
