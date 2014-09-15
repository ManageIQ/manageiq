// Functions used by MIQ for the dhtmlxtree control

//function to pass ajax request to server, to remember tree states
function miqTreeState(rowId,state){
	new Ajax.Request(encodeURI("/vm/compare_set_state" + "?rowId=" + rowId + "&state=" + state),
								{asynchronous:true, evalScripts:true}
	);
	return true;
}

// Handle row click (ajax or normal html trans)
function miqRowClick(row_id, cell_idx) {
  cell = this.cells(row_id, cell_idx);
	if (cell_idx != 0 && cell.getAttribute('is_button') != 1)
		if (typeof row_url_ajax != "undefined" && row_url_ajax == true)
			new Ajax.Request(encodeURI(row_url + row_id),
					{asynchronous:true, evalScripts:true,
						onLoading:function(request){miqSparkle(true);},
						onComplete:function(request){miqSparkle(false);}}
					);
		else
			DoNav(row_url + row_id);
}

// Handle row click - used by AE
function miqAeRowSelected(row_id,cell_idx) {
	if (cell_idx != 0) {
		selected_id = this.getSelectedRowId();
		if (selected_id != null){
			if (selected_id.split("_")[0] == "Field"){
				this.clearSelection();
			}else{
				cfmeDynatree_activateNode('ae_tree', row_id)
			}
		}
	}
}

// Method to hide flash_msg when folde ris being edited in menu editor
function miqMenuRowSelected(row_id,cell_idx) {
	$('flash_msg_div_menu_list').hide();
	folder_list_grid.editCell();
}

// Handle row click
function miqRequestRowSelected(row_id) {
	if (row_id != null){
		new Ajax.Request(encodeURI(request_url + "?" + field_name + "=" + row_id),
				{asynchronous:true, evalScripts:true,
					onLoading:function(request){miqSparkle(true);},
					onComplete:function(request){miqSparkle(false);}}
				);		
	}
	return true;
}

// Handle checkbox
function miqGridOnCheck(row_id, cell_idx, state) {
	crows = gtl_list_grid.getCheckedRows(0);
	$('miq_grid_checks').value = crows
	count = crows == "" ? 0:crows.split(",").length;
	if ($('center_tb')) miqSetButtons(count, "center_tb");
	else miqSetButtons(count, "center_buttons_div");
}

function miqCheck_AE_All(button_div,gridname) {
	miqSparkle(true);
	var state = true;
	var crows = "";
	if (typeof ns_list_grid != "undefined" && gridname == "ns_list_grid") {
		state = $('Toggle1').checked;
		ns_list_grid.checkAll(state ? true : false)
		crows = ns_list_grid.getCheckedRows(0);
	} else if (typeof ns_grid != "undefined" && gridname == "ns_grid") {
		state = $('Toggle2').checked;
		ns_grid.checkAll(state ? true:false)
		crows = ns_grid.getCheckedRows(0);
	} else if (typeof instance_grid != "undefined" && gridname == "instance_grid") {
		state = $('Toggle3').checked;
		instance_grid.checkAll(state ? true:false)
		crows = instance_grid.getCheckedRows(0);
	} else if (typeof class_methods_grid != "undefined" && gridname == "class_methods_grid") {
		state = $('Toggle4').checked;
		class_methods_grid.checkAll(state ? true:false)
		crows = class_methods_grid.getCheckedRows(0);
	}
	if ($('miq_grid_checks')) $('miq_grid_checks').value = crows
	if ($('miq_grid_checks2')) $('miq_grid_checks2').value = crows
	count = crows == "" ? 0:crows.split(",").length;
	miqSetButtons(count, button_div);
	miqSparkle(false);
}

// This function is called in miqOnLoad to init any grids on the screen
function miqInitGrids() {
	if (typeof miq_grids != "undefined") {
		miq_grids.each(function(pair) {
			miqInitGrid(pair.key); // pass they key (grid name), called function will get the grid hash
		});
	}
}

// Initialize a single grid (is called directly after an AJAX trans)
function miqInitGrid(grid_name){
	var grid_hash = miq_grids.get(grid_name)	// Get the hash for the passed in grid
	var miq_grid_checks = "";										//<%# Keep track of the grid checkboxes %>
		
	// Build the grid object, then point a local var at it
	eval(grid_name + " = new dhtmlXGridObject('" + grid_hash.get('g_id') + "')");
	var grid = eval(grid_name);
	var options = grid_hash.get('opts')
	// Start with a clear grid
	grid.clearAll(true)

	// Set paths and skin
	grid.setImagePath("/images/dhtmlxgrid/");
	grid.imgURL = "/images/dhtmlxgrid/";
	grid.setSkin(options['skin']);

if (options['alt_row']) {
    grid.enableAlterCss("miq_row0", "miq_row1");
  } else if (options['alt_row_no_hover']) {
      grid.enableAlterCss("miq_row0 no-hover", "miq_row1 no-hover");
	} else {
		grid.enableAlterCss("", "");
	}

	// Set other grid options
	if (options['row_edit']) {
		grid.setEditable(true);
	} 	
	
	if (options['multi_select']) {
		grid.enableMultiselect(true);
	} else {
		grid.enableMultiselect(false);
	}	

	// Load the grid with XML data, if present
	if (grid_hash.get('xml') != "") {
		grid.parse(grid_hash.get('xml'));
	}
	
	if (options['autosize']) {
		grid.enableAutoHeight(true);
		grid.enableAutoWidth(true);
		grid.objBox.style.overflow="hidden";						//IE fix to eliminate scroll bars on initial display
	}

	grid.setSizes();
		
	if (options['no_resize']) {
		grid.enableResizing("false")
	}

  // Turn on the sort indicator if the options were passed
  if (options['sortcol']) {
    if (options['sortdir'])
      dir = options['sortdir'];
    else
      dir = "asc";
    grid.setSortImgState(true, options['sortcol'], dir);
  }

	if (!options['no_save_state']) {
		grid.attachEvent("onOpenEnd", miqTreeState);
	}
	
	if (options['grid_url']) {
		grid_url = options['grid_url']
		grid.attachEvent("onCheck", miqOnAECheck);
		grid.attachEvent("onRowSelect", miqAeRowSelected);
	} else {
		grid.attachEvent("onCheck", miqGridOnCheck);
		grid.attachEvent("onBeforeSorting", miqGridSort);
	}

	if (options['menu_grid_edit']) {
		grid.attachEvent("onRowDblClicked", miqMenuRowSelected);
	}	
	
	//checking existence on "_none_" at the end of string
	if (options['row_url'] && options['row_url'].lastIndexOf("_none_") != (options['row_url'].length-6) ) {
		row_url = options['row_url'];
		row_url_ajax = options['row_url_ajax'];
		grid.attachEvent("onRowSelect", miqRowClick);
	}

	if (options['save_col_widths']) {
		grid.attachEvent("onResize", miqResizeCol);						//Method called when resize starts
		grid.attachEvent("onResizeEnd", miqResizeColEnd);			//Medhod called when resize ends 
		miq_grid_col_widths = grid.cellWidthPX.join(",")	//Save the original column widths 
	}
	grid.attachEvent("onXLE", function() { miqSparkle(false); } );
}

// Handle checkbox
function miqOnAECheck(row_id, cell_idx, state) {
	crows = this.getCheckedRows(0);
	$$('#miq_grid_checks').each(function(a) {		
		a.value = crows
	})
	$$('#miq_grid_checks2').each(function(a) {
		a.value = crows
	})
	
	count = crows == "" ? 0:crows.split(",").length;	
	//if ($('policy_bar'))	miqSetButtons(count, "policy_bar");
	//if ($('policy_bar2')) miqSetButtons(count, "policy_bar2");
  if ($('center_tb')) miqSetButtons(count, "center_tb");
  else miqSetButtons(count, "center_buttons_div");
}

// Handle sort
function miqGridSort(col_id, grid_obj, dir) {
	if (miq_action_url == "sort_ds_grid") {
		url = "/miq_request/sort_ds_grid" + "?sortby=" + col_id;
		new Ajax.Request(encodeURI(url),
											{asynchronous:true, evalScripts:true,
											onLoading:function(request){miqSparkle(true);},
											onComplete:function(request){miqSparkle(false);}}
			);
	} else {
		if (grid_obj && col_id > 1) {
			url = miq_action_url;
			if (typeof miq_parent_id != "undefined") {
				url = "/" + miq_parent_class + "/" + url + "/" + miq_parent_id;
			}
			url = url + "?sortby=" + (col_id - 1) + "&" + window.location.search.substring(1);
			new Ajax.Request(encodeURI(url),
											{asynchronous:true, evalScripts:true,
											onLoading:function(request){miqSparkle(true);},
											onComplete:function(request){miqSparkle(false);}}
			);
		}	else
			return false;
	}
}

// Handle column resize
function miqResizeCol(cell_idx, width, grid_obj) {
	if (cell_idx < 2)
		return false;
	else
		return true;
}

// Handle column resize end
function miqResizeColEnd(grid_obj) {
	if (typeof miq_grid_col_widths != "undefined") {
		if (miq_grid_col_widths != grid_obj.cellWidthPX.join(",")) {
			miq_grid_col_widths = grid_obj.cellWidthPX.join(",");
			new Ajax.Request(encodeURI("/" + miq_controller + "/save_col_widths/?col_widths=" + miq_grid_col_widths),
											{asynchronous:true, evalScripts:true}
			);
//			alert("Cell widths" + miq_grid_col_widths);
} }	}

// Order a service from the catalog list view
function miqOrderService(id){
  new Ajax.Request(encodeURI("/" + miq_controller + "/x_button/" + id + "?pressed=svc_catalog_provision"),
                  {asynchronous:true, evalScripts:true,
                  onLoading:function(request){miqSparkle(true);},
                  onComplete:function(request){miqSparkle(false);}}
  );
}

function miqDhtmlxgridSerialize(gridObj) {
  dhtmlxgridXml = "<?xml version='1.0'?>";
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
