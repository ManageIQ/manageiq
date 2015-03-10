var rows;
var columns;
var grid;

// Initialize a single grid (is called directly after an AJAX trans)
function cfmeInitSlickGrid(grid_name, dataJson, columnsJson, options) {
  for(var i in columnsJson) {
    columnsJson[i].asyncPostRender = applyCSS;
    if(i == 0) {
      columnsJson[i].formatter = TreeFormatter;
    }
    else {
      columnsJson[i].formatter = HtmlFormatter;
    }
  }
  rows = dataJson;
  columns = columnsJson;

  //initialize the model
  dataView = new Slick.Data.DataView();
  grid = new Slick.Grid(grid_name, dataView, columns, options);
  plugin = new Slick.AutoTooltips();
  grid.registerPlugin(plugin);

  grid.onClick.subscribe(function (e, args) {
  if ($(e.target).hasClass("toggle")) {
    var state = 0;
    var item = dataView.getItem(args.row);

    if (item) {
      if (!item._collapsed) {
        item._collapsed = true;
        state = -1;
      } else {
        item._collapsed = false;
        state = 1;
      }
      dataView.updateItem(item.id, item);
    }
    e.stopImmediatePropagation();

    miqJqueryRequest('/' + miq_controller + '/compare_set_state?rowId=' + item.exp_id + '&state=' + state);
  }
  });

    // wire up model events to drive the grid
  dataView.onRowCountChanged.subscribe(function (e, args) {
    grid.updateRowCount();
    grid.render();
  });

  dataView.onRowsChanged.subscribe(function (e, args) {
    grid.invalidateRows(args.rows);
    grid.render();
  });

  dataView.beginUpdate();
  dataView.setItems(rows);
  dataView.setFilterArgs(rows);
  dataView.setFilter(myFilter);
  dataView.endUpdate();
}

function HtmlFormatter(row, cell, value, columnDef, dataContext) {
  return value;
}

function TreeFormatter(row, cell, value, columnDef, dataContext) {
  if (dataContext.indent == undefined)
    return value;

  value = value.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;");
  var spacer = "<span style='display:inline-block;height:1px;width:" + (15 * dataContext["indent"]) + "px'></span>";
  spacer += "<span class='cell-plain'></span>";
  var idx = dataView.getIdxById(dataContext.id);
  var toggle_attribute = "";

  if (rows[idx + 1] && rows[idx + 1].indent > rows[idx].indent) {
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
  if (item.parent != null) {
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
  var value="";
  for( var prop in dataContext ) {
    if( dataContext.hasOwnProperty( prop ) ) {
      if( prop  === colDef.field ) {
        value =  dataContext[ prop ];
        break;
      }
    }
  }
  if (dataContext.section && colDef.field == 'col0')
    $(cellNode).addClass('cell-bkg-plain');

  if(value.search('cell-stripe') > -1)
    $(cellNode).addClass('cell-bkg');
  else if(value.search('cell-plain') > -1)
    $(cellNode).addClass('cell-bkg-plain');
}
