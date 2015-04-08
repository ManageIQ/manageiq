//= require import

var listenForKeyPostMessages = function() {
  window.addEventListener('message', function(event) {
    miqSparkleOff();
    clearMessages();

    var importFileUploadId = event.data.import_file_upload_id;

    if (importFileUploadId) {
      getAndRenderServiceKeyJson(importFileUploadId, event.data.message);
    } else {
      var messageData = JSON.parse(event.data.message);

      if (messageData.level == 'warning') {
        showWarningMessage(messageData.message);
      } else {
        showErrorMessage(messageData.message);
      }
    }
  });
};

var getAndRenderServiceKeyJson = function(importFileUploadId, message) {
  $('.hidden-import-file-upload-id').val(importFileUploadId);

  $.getJSON("key_json?import_file_upload_id=" + importFileUploadId)
    .done(function(rows_json) {
    showSuccessMessage(JSON.parse(message).message);
  })
  .fail(function(failedMessage) {
    var messageData = JSON.parse(failedMessage.responseText);

    if (messageData.level == 'warning') {
      showWarningMessage(messageData.message);
    } else {
      showErrorMessage(messageData.message);
    }
  });

};

setUpKeyImportClickHandlers: function() {
  $('.import-commit').click(function(event) {
    event.preventDefault();
    miqSparkleOn();
    clearMessages();

    var postData = $('#import-form').serialize();
    $.post('import_key', postData, function(data) {
      var flashMessage = JSON.parse(data)[0];
      if (flashMessage.level == 'error') {
        showErrorMessage(flashMessage.message);
      } else {
        showSuccessMessage(flashMessage.message);
      }

      miqSparkleOff();
    });
  });

  $('.import-back').click(function(event) {
    event.preventDefault();
    miqSparkleOn();
    clearMessages();

    $.post('cancel_import', $('#import-form').serialize(), function(data) {
      var flashMessage = JSON.parse(data)[0];
      showSuccessMessage(flashMessage.message);

      $('.import-or-export').show();
      $('.import-data').hide();
      miqSparkleOff();
    });
  });

};

