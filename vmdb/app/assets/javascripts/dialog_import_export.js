//= require_directory ./SlickGrid-2.1/

window.addEventListener('message', function(event) {
  miqSparkleOff();
  clearMessages();

  var importFileUploadId = event.data.import_file_upload_id;

  if (importFileUploadId) {
    getAndRenderServiceDialogJson(importFileUploadId, event.data.message);
  } else {
    var messageData = JSON.parse(event.data.message);

    if (messageData.level == 'warning') {
      showWarningMessage(messageData.message);
    } else {
      showErrorMessage(messageData.message);
    }
  }
});

var getAndRenderServiceDialogJson = function(importFileUploadId, message) {
  $j('.hidden-import-file-upload-id').val(importFileUploadId);

  $j.getJSON("service_dialog_json?import_file_upload_id=" + importFileUploadId, function(rows_json) {
    var statusFormatter = function(row, cell, value, columnDef, dataContext) {
      var status_img = "<img src=/images/icons/16/" + dataContext.status_icon + ".png >"

      return status_img + dataContext.status;
    };

    var inputCheckboxFormatter = function(row, cell, value, columnDef, dataContext) {
      var checked = '';
      var value = dataContext.name;
      var attributes = "class='dialog-checkbox' type='checkbox' name='dialogs_to_import[]' value = '" + value + "'";
      if (dataContext.status_icon == 'equal-green') {
        checked = "checked='checked'";
      }
      return "<input " + attributes + checked + "></input>";
    };

    var dataview = new Slick.Data.DataView({inlineFilters: true});

    var columns = [
      {
      id: "import",
      name: "Import",
      field: "import_checkbox",
      width: 65,
      formatter: inputCheckboxFormatter
    }, {
      id: "name",
      name: "Service Dialog Name",
      field: "name",
      width: 300
    }, {
      id: "status",
      name: "Status",
      field: "status",
      width: 300,
      formatter: statusFormatter
    }
    ];

    dataview.beginUpdate();
    dataview.setItems(rows_json);
    dataview.endUpdate();

    var grid = new Slick.Grid("#import-grid", dataview, columns, {enableColumnReorder: false});

    $j('#import_file_upload_id').val(importFileUploadId);
    $j('.import-data').show();
    $j('.import-or-export').hide();
  });

  showSuccessMessage(JSON.parse(message).message);
};

var setUpClickHandlers = function() {
  $j('.import-commit').click(function() {
    miqSparkleOn();
    clearMessages();

    $j.post('import_service_dialogs', $j('#import-form').serialize(), function(data) {
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
    $j('.dialog-checkbox').prop('checked', this.checked);
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
