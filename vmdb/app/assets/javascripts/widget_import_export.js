//= require import

var listenForWidgetPostMessages = function() {
  window.addEventListener('message', function(event) {
    miqSparkleOff();
    clearMessages();

    var importFileUploadId = event.data.import_file_upload_id;

    if (importFileUploadId) {
      getAndRenderWidgetJson(importFileUploadId, event.data.message);
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

var getAndRenderWidgetJson = function(importFileUploadId, message) {
  $('.hidden-import-file-upload-id').val(importFileUploadId);

  $.getJSON("widget_json?import_file_upload_id=" + importFileUploadId, function(rows_json) {
    var statusFormatter = function(row, cell, value, columnDef, dataContext) {
      var status_img = "<img src=/images/icons/16/" + dataContext.status_icon + ".png >";

      return status_img + dataContext.status;
    };

    var inputCheckboxFormatter = function(row, cell, value, columnDef, dataContext) {
      var checked = '';
      var value = dataContext.name;
      var attributes = "class='import-checkbox' type='checkbox' name='widgets_to_import[]' value = '" + value + "'";
      if (dataContext.status_icon == 'equal-green') {
        checked = "checked='checked'";
      }
      return "<input " + attributes + checked + "></input>";
    };

    var dataview = new Slick.Data.DataView({inlineFilters: true});

    var columns = [{
      id: "import",
      name: "Import",
      field: "import_checkbox",
      width: 65,
      formatter: inputCheckboxFormatter
    }, {
      id: "name",
      name: "Widget Name",
      field: "name",
      width: 300
    }, {
      id: "status",
      name: "Status",
      field: "status",
      width: 300,
      formatter: statusFormatter
    }];

    dataview.beginUpdate();
    dataview.setItems(rows_json);
    dataview.endUpdate();

    var grid = new Slick.Grid("#import-grid", dataview, columns, {enableColumnReorder: false});

    $('#import_file_upload_id').val(importFileUploadId);
    $('.import-data').show();
    $('.widget-import-buttons').show();
    $('.import-or-export').hide();
    $('.widget-export-buttons').hide();
  });

  showSuccessMessage(JSON.parse(message).message);
};

var setUpExportWidgetClickHandlers = function() {
  $('.widget-export').change(function() {
    if ($('.widget-export').val() !== null) {
      if ($('#export-widgets').hasClass('btn-disabled')) {
        $('#export-widgets').removeClass('btn-disabled');
      }
    } else {
      if (!$('#export-widgets').hasClass('btn-disabled')) {
        $('#export-widgets').addClass('btn-disabled');
      }
    }
  });

  $('#export-widgets').click(function() {
    if ($('.widget-export').val() !== null) {
      $('#export-widgets-form').submit();
    }
  });
};

var setUpImportWidgetClickHandlers = function() {
  $('.import-commit').click(function() {
    miqSparkleOn();
    clearMessages();

    $.post('import_widgets', $('#import-form').serialize(), function(data) {
      var flashMessage = JSON.parse(data).first();
      if (flashMessage.level == 'error') {
        showErrorMessage(flashMessage.message);
      } else {
        showSuccessMessage(flashMessage.message);
      }

      showMainWidgetImportExport();
    });
  });

  $('.import-cancel').click(function() {
    miqSparkleOn();
    clearMessages();

    $.post('cancel_import', $('#import-form').serialize(), function(data) {
      var flashMessage = JSON.parse(data).first();
      showSuccessMessage(flashMessage.message);
      showMainWidgetImportExport();
    });
  });

  $('#toggle-all').click(function() {
    $('.import-checkbox').prop('checked', this.checked);
  });
};

var showMainWidgetImportExport = function() {
  $('.import-or-export').show();
  $('.widget-export-buttons').show();
  $('.import-data').hide();
  $('.widget-import-buttons').hide();
  miqSparkleOff();
};
