// Initialize a single grid (is called directly after an AJAX trans)
function miqInitSlickGrid(grid_name, dataJson, columnsJson, options) {
  for (var i in columnsJson) {
    columnsJson[i].asyncPostRender = applyCSS;
    columnsJson[i].formatter = HtmlFormatter;
  }
  if (columnsJson.length) {
    columnsJson[0].formatter = TreeFormatter;
  }

  ManageIQ.slick.slickRows = dataJson;
  ManageIQ.slick.slickColumns = columnsJson;

  // initialize the model
  ManageIQ.slick.slickDataView = new Slick.Data.DataView();
  ManageIQ.slick.slickGrid = new Slick.Grid(grid_name, ManageIQ.slick.slickDataView, ManageIQ.slick.slickColumns, options);
  var plugin = new Slick.AutoTooltips();
  ManageIQ.slick.slickGrid.registerPlugin(plugin);

  ManageIQ.slick.slickGrid.onClick.subscribe(function (e, args) {
  if ($(e.target).hasClass("toggle")) {
    var state = 0;
    var item = ManageIQ.slick.slickDataView.getItem(args.row);

    if (item) {
      if (!item._collapsed) {
        item._collapsed = true;
        state = -1;
      } else {
        item._collapsed = false;
        state = 1;
      }
      ManageIQ.slick.slickDataView.updateItem(item.id, item);
    }
    e.stopImmediatePropagation();

    miqJqueryRequest('/' + ManageIQ.controller + '/compare_set_state?rowId=' + item.exp_id + '&state=' + state);
  }
});

  // wire up model events to drive the grid
  ManageIQ.slick.slickDataView.onRowCountChanged.subscribe(function (e, args) {
    ManageIQ.slick.slickGrid.updateRowCount();
    ManageIQ.slick.slickGrid.render();
  });

  ManageIQ.slick.slickDataView.onRowsChanged.subscribe(function (e, args) {
    ManageIQ.slick.slickGrid.invalidateRows(args.rows);
    ManageIQ.slick.slickGrid.render();
  });

  ManageIQ.slick.slickDataView.beginUpdate();
  ManageIQ.slick.slickDataView.setItems(ManageIQ.slick.slickRows);
  ManageIQ.slick.slickDataView.setFilterArgs(ManageIQ.slick.slickRows);
  ManageIQ.slick.slickDataView.setFilter(myFilter);
  ManageIQ.slick.slickDataView.endUpdate();
}

function HtmlFormatter(row, cell, value, columnDef, dataContext) {
  return value;
}

function TreeFormatter(row, cell, value, columnDef, dataContext) {
  if (dataContext.indent === undefined) {
    return value;
  }

  value = value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  var spacer = "<span style='display:inline-block;height:1px;width:" + (15 * dataContext.indent) + "px'></span>";
  spacer += "<span class='cell-plain'></span>";
  var idx = ManageIQ.slick.slickDataView.getIdxById(dataContext.id);
  var toggle_attribute = "";

  if (ManageIQ.slick.slickRows[idx + 1] && ManageIQ.slick.slickRows[idx + 1].indent > ManageIQ.slick.slickRows[idx].indent) {
    if (dataContext._collapsed) {
      toggle_attribute = "expand";
    } else {
      toggle_attribute = "collapse";
    }
    return spacer + " <span class='toggle " + toggle_attribute + "'></span>&nbsp;" + value;
  } else {
    return spacer + " <span class='toggle'></span>&nbsp;" + value;
  }
}

function myFilter(item, rows) {
  if (item.parent != null) { // null or undefined
    var parent = rows[item.parent];

    while (parent) {
      if (parent._collapsed) {
        return false;
      }
      parent = rows[parent.parent];
    }
  }
  return true;
}

function applyCSS(cellNode, row, dataContext, colDef) {
  var value = "";
  for (var prop in dataContext) {
    if (dataContext.hasOwnProperty(prop)) {
      if (prop === colDef.field) {
        value = dataContext[prop];
        break;
      }
    }
  }
  if (dataContext.section && colDef.field == 'col0') {
    $(cellNode).addClass('cell-bkg-plain');
  }

  if (value.search('cell-stripe') > -1) {
    $(cellNode).addClass('cell-bkg');
  } else if (value.search('cell-plain') > -1) {
    $(cellNode).addClass('cell-bkg-plain');
  }
}
