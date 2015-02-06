//= require import

var listenForDialogPostMessages = function() {
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
};

var getAndRenderServiceDialogJson = function(importFileUploadId, message) {
  $('.hidden-import-file-upload-id').val(importFileUploadId);

  $.getJSON("service_dialog_json?import_file_upload_id=" + importFileUploadId, function(rows_json) {
    var statusFormatter = function(row, cell, value, columnDef, dataContext) {
      var status_img = "<img src=/images/icons/16/" + dataContext.status_icon + ".png >";

      return status_img + dataContext.status;
    };

    var inputCheckboxFormatter = function(row, cell, value, columnDef, dataContext) {
      var checked = '';
      var value = dataContext.name;
      var attributes = "class='import-checkbox' type='checkbox' name='dialogs_to_import[]' value = '" + value + "'";
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

    $('#import_file_upload_id').val(importFileUploadId);
    $('.import-data').show();
    $('.import-or-export').hide();
  });

  showSuccessMessage(JSON.parse(message).message);
};
