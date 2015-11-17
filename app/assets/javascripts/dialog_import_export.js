//= require import

var renderServiceDialogJson = function(rows_json, importFileUploadId) {
  var statusFormatter = function(row, cell, value, columnDef, dataContext) {
    var status_img = "<img src=/images/icons/16/" + dataContext.status_icon + ".png >";

    return status_img + dataContext.status;
  };

  var dataview = new Slick.Data.DataView({inlineFilters: true});

  var checkboxSelector = new Slick.CheckboxSelectColumn({
    cssClass: "import-checkbox",
  });

  var columns = [
    checkboxSelector.getColumnDefinition(),
    {
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

  grid.setSelectionModel(new Slick.RowSelectionModel({selectActiveRow: false}));
  grid.registerPlugin(checkboxSelector);

  $('#import_file_upload_id').val(importFileUploadId);
  $('.import-data').show();
  $('.import-or-export').hide();

  var rowsToSelect = [];
  $.each(grid.getData().getItems(), function(index, item) {
    if (item.status_icon === 'equal-green') {
      rowsToSelect.push(item.id);
    }
  });

  grid.setSelectedRows(rowsToSelect);
  grid.invalidate();
  grid.render();

  setUpImportClickHandlers('import_service_dialogs', grid, function() {
    $.get('dialog_accordion_json', function(data) {
      ManageIQ.dynatreeReplacement.replace(data.locals_for_render);
    });
  });
};

var getAndRenderServiceDialogJson = function(importFileUploadId, message) {
  $('.hidden-import-file-upload-id').val(importFileUploadId);

  $.getJSON("service_dialog_json?import_file_upload_id=" + importFileUploadId).done(function(rows_json) {
    renderServiceDialogJson(rows_json, importFileUploadId);
  });

  showSuccessMessage(JSON.parse(message).message);
};
