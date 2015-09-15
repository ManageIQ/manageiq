// ES6 endsWith polyfill
if (!String.prototype.endsWith) {
  String.prototype.endsWith = function(searchString, position) {
      var subjectString = this.toString();
      if (position === undefined || position > subjectString.length) {
        position = subjectString.length;
      }
      position -= searchString.length;
      var lastIndex = subjectString.indexOf(searchString, position);
      return lastIndex !== -1 && lastIndex === position;
  };
}

// Functions used by MIQ for the dhtmlxtree control

// Function to pass ajax request to server, to remember tree states
function miqTreeState(rowId, state) {
  miqJqueryRequest('/vm/compare_set_state?rowId=' + rowId + '&state=' + state);
  return true;
}

// Handle row click (ajax or normal html trans)
function miqRowClick(row_id, cell_idx) {
  var cell = this.cells(row_id, cell_idx);
  if (cell_idx && !cell.getAttribute('is_button')) {
    if (typeof row_url_ajax != "undefined" && row_url_ajax) {
      miqJqueryRequest(row_url + row_id, {beforeSend: true, complete: true});
    } else {
      if (!row_url.endsWith("/")) {
        row_url = row_url + "/";
      }
      DoNav(row_url + row_id);
    }
  }
}

// Handle row click - used by AE
function miqAeRowSelected(row_id, cell_idx) {
  if (cell_idx) {
    var selected_id = this.getSelectedRowId();
    if (selected_id != null) {
      if (selected_id.split("_")[0] == "Field") {
        this.clearSelection();
      } else {
        miqDynatreeActivateNode('ae_tree', row_id);
      }
    }
  }
}

// Method to hide flash_msg when folde ris being edited in menu editor
function miqMenuRowSelected(row_id, cell_idx) {
  $('#flash_msg_div_menu_list').hide();
  folder_list_grid.editCell();
}

// Handle row click
function miqRequestRowSelected(row_id) {
  if (row_id != null) {
    miqJqueryRequest(request_url + '?' + field_name + '=' + row_id, {beforeSend: true, complete: true});
  }
  return true;
}

// Handle checkbox
function miqGridOnCheck(row_id, cell_idx, state) {
  var crows = ManageIQ.grids.grids['gtl_list_grid'].obj.getCheckedRows(0);
  $('#miq_grid_checks').val(crows);
  var count = crows ? crows.split(",").length : 0;
  if (miqDomElementExists('center_tb')) {
    miqSetButtons(count, "center_tb");
  } else {
    miqSetButtons(count, "center_buttons_div");
  }
}

function miqCheck_AE_All(button_div, gridname) {
  miqSparkle(true);
  var state = true;
  var crows = "";
  if (typeof ManageIQ.grids.grids.ns_list_grid != "undefined" &&
      gridname == "ns_list_grid") {
    state = $('#Toggle1').prop('checked');
    ManageIQ.grids.grids.ns_list_grid.checkAll(state);
    crows = ManageIQ.grids.grids.ns_list_grid.getCheckedRows(0);
  } else if (typeof ManageIQ.grids.grids.ns_grid != "undefined" &&
             gridname == "ns_grid") {
    state = $('#Toggle2').prop('checked');
    ManageIQ.grids.grids.ns_grid.checkAll(state);
    crows = ns_grid.getCheckedRows(0);
  } else if (typeof ManageIQ.grids.grids.instance_grid != "undefined" &&
             gridname == "instance_grid") {
    state = $('#Toggle3').prop('checked');
    ManageIQ.grids.grids.instance_grid.checkAll(state);
    crows = instance_grid.getCheckedRows(0);
  } else if (typeof ManageIQ.grids.grids.class_methods_grid != "undefined" &&
             gridname == "class_methods_grid") {
    state = $('#Toggle4').prop('checked');
    ManageIQ.grids.grids.class_methods_grid.checkAll(state);
    crows = class_methods_grid.getCheckedRows(0);
  }
  if (miqDomElementExists('miq_grid_checks')) {
    $('#miq_grid_checks').val(crows);
  }
  if (miqDomElementExists('miq_grid_checks2')) {
    $('#miq_grid_checks2').val(crows);
  }
  var count = crows ? crows.split(",").length : 0;
  miqSetButtons(count, button_div);
  miqSparkle(false);
}

// This function is called in miqOnLoad to init any grids on the screen
function miqInitGrids() {
  if (ManageIQ.grids.grids !== null) {
    $.each(ManageIQ.grids.grids, function (key) {
      miqInitGrid(key); // pass they key (grid name), called function will get the grid hash
    });
  }
}

// Initialize a single grid (is called directly after an AJAX trans)
function miqInitGrid(grid_name) {
  var grid_hash = ManageIQ.grids.grids[grid_name]; // Get the hash for the passed in grid
  var miq_grid_checks = ""; // Keep track of the grid checkboxes

  // Build the grid object, then point a local var at it
  var grid = new dhtmlXGridObject(grid_hash.g_id);
  ManageIQ.grids.grids[grid_name].obj = grid;
  var options = grid_hash.opts;
  // Start with a clear grid
  grid.clearAll(true);

  // Set paths and skin
  grid.setImagePath("/images/dhtmlxgrid/");
  grid.imgURL = "/images/dhtmlxgrid/";
  grid.setSkin(options.skin);

  if (options.alt_row) {
    grid.enableAlterCss("miq_row0", "miq_row1");
  } else if (options.alt_row_no_hover) {
    grid.enableAlterCss("miq_row0 no-hover", "miq_row1 no-hover");
  } else {
    grid.enableAlterCss("", "");
  }

  // Set other grid options
  if (options.row_edit) {
    grid.setEditable(true);
  }

  if (options.multi_select) {
    grid.enableMultiselect(true);
  } else {
    grid.enableMultiselect(false);
  }

  // Load the grid with XML data, if present
  if (grid_hash.xml) {
    grid.parse(grid_hash.xml);
  }

  if (options.autosize) {
    grid.enableAutoHeight(true);
    grid.enableAutoWidth(true);
    $(grid.objBox).css('overflow', 'hidden'); // IE fix to eliminate scroll bars on initial display
  }

  grid.setSizes();

  if (options.no_resize) {
    grid.enableResizing("false");
  }

  // Turn on the sort indicator if the options were passed
  if (options.sortcol) {
    if (options.sortdir) {
      dir = options.sortdir;
    } else {
      dir = "asc";
    }
    grid.setSortImgState(true, options.sortcol, dir);
  }

  if (!options.no_save_state) {
    grid.attachEvent("onOpenEnd", miqTreeState);
  }

  if (options.grid_url) {
    grid_url = options.grid_url;
    grid.attachEvent("onCheck", miqOnAECheck);
    grid.attachEvent("onRowSelect", miqAeRowSelected);
  } else {
    grid.attachEvent("onCheck", miqGridOnCheck);
    grid.attachEvent("onBeforeSorting", miqGridSort);
  }

  if (options.menu_grid_edit) {
    grid.attachEvent("onRowDblClicked", miqMenuRowSelected);
  }

  // checking existence on "_none_" at the end of string
  if (options.row_url && options.row_url.lastIndexOf("_none_") != (options.row_url.length - 6) ) {
    row_url = options.row_url;
    row_url_ajax = options.row_url_ajax;
    grid.attachEvent("onRowSelect", miqRowClick);
  }

  if (options.save_col_widths) {
    grid.attachEvent("onResize", miqResizeCol); // Method called when resize starts
    grid.attachEvent("onResizeEnd", miqResizeColEnd); // Medhod called when resize ends
    ManageIQ.grids.gridColumnWidths = grid.cellWidthPX.join(","); // Save the original column widths
  }
  grid.attachEvent("onXLE", function () {
    miqSparkle(false);
  });
}

// Handle checkbox
function miqOnAECheck(row_id, cell_idx, state) {
  var crows = this.getCheckedRows(0);
  $("#miq_grid_checks").val(crows);
  $("#miq_grid_checks2").val(crows);

  var count = crows ? crows.split(",").length : 0;
  if (miqDomElementExists('center_tb')) {
    miqSetButtons(count, "center_tb");
  } else {
    miqSetButtons(count, "center_buttons_div");
  }
}

// Handle sort
function miqGridSort(col_id, grid_obj, dir) {
  if (ManageIQ.actionUrl == "sort_ds_grid") {
    var url = '/miq_request/sort_ds_grid?sortby=' + col_id;
    miqJqueryRequest(url, {beforeSend: true, complete: true});
  } else {
    if (grid_obj && col_id > 1) {
      var url = ManageIQ.actionUrl;
      if (ManageIQ.record.parentId !== null) {
        url = "/" + ManageIQ.record.parentClass + "/" + url + "/" + ManageIQ.record.parentId;
      }
      url = url + "?sortby=" + (col_id - 1) + "&" + window.location.search.substring(1);
      miqJqueryRequest(url, {beforeSend: true, complete: true});
    } else {
      return false;
    }
  }
}

// Handle column resize
function miqResizeCol(cell_idx, width, grid_obj) {
  return (cell_idx >= 2);
}

// Handle column resize end
function miqResizeColEnd(grid_obj) {
  if (ManageIQ.grids.gridColumnWidths !== null) {
    if (ManageIQ.grids.gridColumnWidths != grid_obj.cellWidthPX.join(",")) {
      ManageIQ.grids.gridColumnWidths = grid_obj.cellWidthPX.join(",");
      var url = '/' + ManageIQ.controller + '/save_col_widths/?col_widths=' + ManageIQ.grids.gridColumnWidths;
      miqJqueryRequest(url);
    }
  }
}

// Order a service from the catalog list view
function miqOrderService(id) {
  var url = '/' + ManageIQ.controller + '/x_button/' + id + '?pressed=svc_catalog_provision';
  miqJqueryRequest(url, {beforeSend: true, complete: true});
}

function miqDhtmlxgridSerialize(gridObj) {
  var dhtmlxgridXml = "<?xml version='1.0'?>";
  dhtmlxgridXml += "<rows>";
  rowIds = gridObj.getAllRowIds().split(',');
  for (i = 0; i < rowIds.length; i++) {
    dhtmlxgridXml += "<row id=" + "'" + rowIds[i] + "'>";
    for (j = 0; j < gridObj.getColumnCount(); j++) {
      dhtmlxgridXml += "<cell>" + gridObj.cells(rowIds[i], j).getValue() + "</cell>";
    }
    dhtmlxgridXml += "</row>";
  }
  dhtmlxgridXml += "</rows>";
  return dhtmlxgridXml;
}
