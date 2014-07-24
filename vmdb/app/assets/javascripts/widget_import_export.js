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
  $j('.hidden-import-file-upload-id').val(importFileUploadId);

  $j.getJSON("widget_json?import_file_upload_id=" + importFileUploadId, function(rows_json) {
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

    $j('#import_file_upload_id').val(importFileUploadId);
    $j('.import-data').show();
    $j('.widget-import-buttons').show();
    $j('.import-or-export').hide();
    $j('.widget-export-buttons').hide();
  });

  showSuccessMessage(JSON.parse(message).message);
};

var setUpExportWidgetClickHandlers = function() {
  $j('.widget-export').change(function() {
    if ($j('.widget-export').val() !== null) {
      if ($j('#export-widgets').hasClass('dimmed')) {
        $j('#export-widgets').removeClass('dimmed');
      }
    } else {
      if (!$j('#export-widgets').hasClass('dimmed')) {
        $j('#export-widgets').addClass('dimmed');
      }
    }
  });

  $j('#export-widgets').click(function() {
    if ($j('.widget-export').val() !== null) {
      $j('#export-widgets-form').submit();
    }
  });
};

var setUpImportWidgetClickHandlers = function() {
  $j('.import-commit').click(function() {
    miqSparkleOn();
    clearMessages();

    $j.post('import_widgets', $j('#import-form').serialize(), function(data) {
      var flashMessage = JSON.parse(data).first();
      if (flashMessage.level == 'error') {
        showErrorMessage(flashMessage.message);
      } else {
        showSuccessMessage(flashMessage.message);
      }

      showMainWidgetImportExport();
    });
  });

  $j('.import-cancel').click(function() {
    miqSparkleOn();
    clearMessages();

    $j.post('cancel_import', $j('#import-form').serialize(), function(data) {
      var flashMessage = JSON.parse(data).first();
      showSuccessMessage(flashMessage.message);
      showMainWidgetImportExport();
    });
  });

  $j('#toggle-all').click(function() {
    $j('.import-checkbox').prop('checked', this.checked);
  });
};

var showMainWidgetImportExport = function() {
  $j('.import-or-export').show();
  $j('.widget-export-buttons').show();
  $j('.import-data').hide();
  $j('.widget-import-buttons').hide();
  miqSparkleOff();
};
