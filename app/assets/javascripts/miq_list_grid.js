// Handle row click (ajax or normal html trans)
function miqRowClick(row_id, row_url, row_url_ajax) {
  if (! row_url)
    return;

  if (row_url_ajax) {
    miqJqueryRequest(row_url + row_id, {beforeSend: true, complete: true});
  } else {
    DoNav(row_url + row_id);
  }
}

// Functions used by MIQ for the dhtmlxtree control

// Handle row click
function miqRequestRowSelected(row_id) {
  if (row_id != null) {
    miqJqueryRequest(request_url + '?' + field_name + '=' + row_id, {beforeSend: true, complete: true});
  }
  return true;
}

// returns a list of checked row ids
function miqGridGetCheckedRows(grid) {
  grid = grid || 'list_grid';
  var crows = [];

  $('#' + grid + ' .list-grid-checkbox').each(function(_idx, elem) {
    if ($(elem).prop('checked')) {
      crows.push($(elem).val());
    }
  });

  return crows;
}

// checks/unchecks all grid rows
function miqGridCheckAll(state, grid) {
  grid = grid || 'list_grid';
  state = !! state;

  $('#' + grid + ' .list-grid-checkbox').each(function(_idx, elem) {
    $(elem).prop('checked', state);
  });
}

// Handle checkbox
function miqGridOnCheck(row_id, cell_idx, state) {
  var crows = miqGridGetCheckedRows();
  $('#miq_grid_checks').val(crows.join(','));

  if (miqDomElementExists('center_tb')) {
    miqSetButtons(crows.length, "center_tb");
  } else {
    miqSetButtons(crows.length, "center_buttons_div");
  }
}

function miqCheck_AE_All(button_div, gridname) {
  miqSparkle(true);
  var state = true;
  var crows = [];

  if (ManageIQ.grids.ns_list_grid && gridname == "ns_list_grid") {
    state = $('#Toggle1').prop('checked');
    miqGridCheckAll(state, 'ns_list_grid');
    crows = miqGridGetCheckedRows('ns_list_grid');
  } else if (ManageIQ.grids.ns_grid && gridname == "ns_grid") {
    state = $('#Toggle2').prop('checked');
    miqGridCheckAll(state, 'ns_grid');
    crows = miqGridGetCheckedRows('ns_grid');
  } else if (ManageIQ.grids.instance_grid && gridname == "instance_grid") {
    state = $('#Toggle3').prop('checked');
    miqGridCheckAll(state, 'instance_grid');
    crows = miqGridGetCheckedRows('instance_grid');
  } else if (ManageIQ.grids.class_methods_grid && gridname == "class_methods_grid") {
    state = $('#Toggle4').prop('checked');
    miqGridCheckAll(state, 'class_methods_grid');
    crows = miqGridGetCheckedRows('class_methods_grid');
  }

  if (miqDomElementExists('miq_grid_checks')) {
    $('#miq_grid_checks').val(crows.join(','));
  }
  if (miqDomElementExists('miq_grid_checks2')) {
    $('#miq_grid_checks2').val(crows.join(','));
  }

  miqSetButtons(crows.length, button_div);
  miqSparkle(false);
}

// This function is called in miqOnLoad to init any grids on the screen
function miqInitGrids() {
  _.keys(ManageIQ.grids).forEach(miqInitGrid);
}

// Initialize a single grid (is called directly after an AJAX trans)
function miqInitGrid(grid_name) {
  return;  // TODO

  var miq_grid_checks = ""; // Keep track of the grid checkboxes

  // Turn on the sort indicator if the options were passed
  if (options.sortcol) {
    if (options.sortdir) {
      dir = options.sortdir;
    } else {
      dir = "asc";
    }
    grid.setSortImgState(true, options.sortcol, dir);
  }

  grid.attachEvent("onCheck", miqGridOnCheck);
  grid.attachEvent("onBeforeSorting", miqGridSort);
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

// Order a service from the catalog list view
function miqOrderService(id) {
  var url = '/' + ManageIQ.controller + '/x_button/' + id + '?pressed=svc_catalog_provision';
  miqJqueryRequest(url, {beforeSend: true, complete: true});
}
