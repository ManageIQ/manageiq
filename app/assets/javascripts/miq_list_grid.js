/* global DoNav miqDomElementExists miqJqueryRequest miqSetButtons miqUpdateButtons */

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

function checkboxItemId($elem) {
  var val = $elem.val()
  var name = $elem.attr('name');

  if (_.startsWith(name, 'check_')) {
    return name.substr(6);
  }

  return val;
}

// returns a list of checked row ids
function miqGridGetCheckedRows(grid) {
  grid = grid || 'list_grid';
  var crows = [];

  $('#' + grid + ' .list-grid-checkbox').each(function(_idx, elem) {
    if (! $(elem).prop('checked')) {
      return;
    }

    var item_id = checkboxItemId($(elem));
    crows.push(item_id);
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

// Order a service from the catalog list view
function miqOrderService(id) {
  var url = '/' + ManageIQ.controller + '/x_button/' + id + '?pressed=svc_catalog_provision';
  miqJqueryRequest(url, {beforeSend: true, complete: true});
}

// Handle checkbox
function miqGridOnCheck(elem, button_div, grid) {
  if (elem) {
    miqUpdateButtons(elem, button_div);
  }

  var crows = miqGridGetCheckedRows(grid);
  ManageIQ.gridChecks = crows;

  if (miqDomElementExists('center_tb')) {
    miqSetButtons(crows.length, "center_tb");
  } else {
    miqSetButtons(crows.length, "center_buttons_div");
  }
}

// Handle sort
function miqGetSortUrl(col_id) {
  var controller = null;
  var action = ManageIQ.actionUrl;
  var id = null;

  if (action == "sort_ds_grid") {
    controller = 'miq_request';
  } else if (ManageIQ.record.parentId !== null) {
    controller = ManageIQ.record.parentClass;
    id = ManageIQ.record.parentId;
  }

  var url = action;
  if (controller) {
    url = '/' + controller + '/' + url;
  }
  if (id && (url.indexOf(id) < 0)) {
    url = url + '/' + id;
  }

  url = url + "?sortby=" + col_id + "&" + window.location.search.substring(1);
  return url;
}

function miqGridSort(col_id) {
  url = miqGetSortUrl(col_id);
  miqJqueryRequest(url, {beforeSend: true, complete: true});
}
