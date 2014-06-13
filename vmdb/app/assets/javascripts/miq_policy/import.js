//= require_directory ../SlickGrid-2.1/
var rows;

$j.getJSON("get_json?import_file_upload_id=" + import_file_upload_id, function(rows_json){

  rows = rows_json;
  function myFilter(item) {

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
  };

  var PolicyNameFormatter = function (row, cell, value, columnDef, dataContext) {
    var spacer = "<span style='display:inline-block;height:1px;width:" + (15 * dataContext["indent"]) + "px'></span>";
    var status_img = "<img src=" + dataContext.status_icon + ">"

    var idx = dataview.getIdxById(dataContext.id);
    if (rows[idx + 1] && rows[idx + 1].indent > rows[idx].indent) {
      if (dataContext._collapsed) {
        return spacer + " <span class='toggle expand'></span>&nbsp;" + status_img + value;
      } else {
        return spacer + " <span class='toggle collapse'></span>&nbsp;" + status_img + value;
      }
    } else {
      return spacer + " <span class='toggle'></span>&nbsp;" + status_img + value;
    }
  };

  var grid;
  var dataview = new Slick.Data.DataView({inlineFilters: true});

  var columns = [
    {id: "title", name: "Details", field: "title", width: 300, formatter: PolicyNameFormatter },
    {id: "msg", name: "Message", field: "msg", width: 300}
  ];

  var options = {
    enableColumnReorder: false,
    asyncEditorLoading: false,
    forceFitColumns: true
  };

  dataview.beginUpdate();
  dataview.setItems(rows);
  dataview.setFilter(myFilter);
  dataview.endUpdate();

  grid = new Slick.Grid("#import_grid", dataview, columns, options);

  grid.onClick.subscribe(function (e, args) {
    if ($j(e.target).hasClass("toggle")) {
      var item = dataview.getItem(args.row);
      if (item) {
        if (!item._collapsed) {
          item._collapsed = true;
        } else {
          item._collapsed = false;
        }

        dataview.updateItem(item.id, item);
      }
      e.stopImmediatePropagation();
    }
  });

  // wire up model events to drive the grid
  dataview.onRowCountChanged.subscribe(function (e, args) {
    grid.updateRowCount();
    grid.render();
  });

  dataview.onRowsChanged.subscribe(function (e, args) {
    grid.invalidateRows(args.rows);
    grid.render();
  });
});
