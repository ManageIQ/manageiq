//v.3.6 build 131108

/*
Copyright DHTMLX LTD. http://www.dhtmlx.com
You allowed to use this component or parts of it under GPL terms
To use it on other terms or get Professional edition of the component please contact us at sales@dhtmlx.com
*/
dhtmlXGridObject.prototype.toPDF=function(url,mode,header,footer,rows,target){
	var save_sel = {
		row: this.getSelectedRowId(),
		col: this.getSelectedCellIndex()
	};
	if (save_sel.row === null || save_sel.col === -1)
		save_sel = false;
	else {
		var el = this.cells(save_sel.row, save_sel.col).cell;
		el.parentNode.className = el.parentNode.className.replace(' rowselected', '');
		el.className = el.className.replace(' cellselected', '');
		save_sel.el = el;
	}
	mode = mode || "color";	
	var full_color = mode == "full_color";
	var grid = this;
	grid._asCDATA = true;
	if (typeof(target) === 'undefined')
		this.target = " target=\"_blank\"";
	else
		this.target = target;
		
	eXcell_ch.prototype.getContent = function(){
		return this.getValue();
	};
	eXcell_ra.prototype.getContent = function(){
		return this.getValue();
	};
	function xml_top(profile) {
		var spans = [];
		for (var i=1; i<grid.hdr.rows.length; i++){
			spans[i]=[];
			for (var j=0; j<grid._cCount; j++){
				var cell = grid.hdr.rows[i].childNodes[j];
				if (!spans[i][j])
					spans[i][j]=[0,0];
				if (cell)
					spans[i][cell._cellIndexS]=[cell.colSpan, cell.rowSpan];
			}
		}
		
	    var xml = "<rows profile='"+profile+"'";
	       if (header)
	          xml+=" header='"+header+"'";
	       if (footer)
	          xml+=" footer='"+footer+"'";
	    xml+="><head>"+grid._serialiseExportConfig(spans).replace(/^<head/,"<columns").replace(/head>$/,"columns>");
	    for (var i=2; i < grid.hdr.rows.length; i++) {
                var empty_cols = 0;
                var row = grid.hdr.rows[i];
    	        var cxml="";
	    	for (var j=0; j < grid._cCount; j++) {
	    		if ((grid._srClmn && !grid._srClmn[j]) || (grid._hrrar[j] && ( !grid._fake || j >= grid._fake.hdrLabels.length))) {
	    			empty_cols++;
	    			continue;
    			}
	    		var s = spans[i][j];
	    		var rspan =  (( s[0] && s[0] > 1 ) ? ' colspan="'+s[0]+'" ' : "");
                        if (s[1] && s[1] > 1){
                             rspan+=' rowspan="'+s[1]+'" ';
                             empty_cols = -1;
                        }
                        
                
                var val = "";
                for (var k=0; k<row.cells.length; k++){
					if (row.cells[k]._cellIndexS==j) {
						if (row.cells[k].getElementsByTagName("SELECT").length)
							val="";
						else
							val = _isIE?row.cells[k].innerText:row.cells[k].textContent;
							val=val.replace(/[ \n\r\t\xA0]+/," ");
						break;
					}
				}
	    		if (!val || val==" ") empty_cols++;
	    		cxml+="<column"+rspan+"><![CDATA["+val+"]]></column>";
	    	};
	    	if (empty_cols != grid._cCount)
	    		xml+="\n<columns>"+cxml+"</columns>";
	    };
	    xml+="</head>\n";
	    xml+=xml_footer();
	    return xml;
	};
	
	function xml_body() {
		var xml =[];
	    if (rows)
	    	for (var i=0; i<rows.length; i++)
	    		xml.push(xml_row(grid.getRowIndex(rows[i])));
	    else
	    	for (var i=0; i<grid.getRowsNum(); i++)
	    		xml.push(xml_row(i));
	    return xml.join("\n");
	}
	function xml_footer() {
		var xml =["<foot>"];
		if (!grid.ftr) return "";
		for (var i=1; i < grid.ftr.rows.length; i++) {
			xml.push("<columns>");
			var row = grid.ftr.rows[i];
			for (var j=0; j < grid._cCount; j++){
				if (grid._srClmn && !grid._srClmn[j]) continue;
				if (grid._hrrar[j] && ( !grid._fake || j >= grid._fake.hdrLabels.length)) continue;
				for (var k=0; k<row.cells.length; k++){
				 	var val = "";
				 	var span = "";
					if (row.cells[k]._cellIndexS==j) {
						val = _isIE?row.cells[k].innerText:row.cells[k].textContent;
						val=val.replace(/[ \n\r\t\xA0]+/," ");
						
						if (row.cells[k].colSpan && row.cells[k].colSpan!=1)
							span = " colspan='"+row.cells[k].colSpan+"' ";
						
						if (row.cells[k].rowSpan && row.cells[k].rowSpan!=1)
							span = " rowspan='"+row.cells[k].rowSpan+"' ";
						break;
					}
				}
				xml.push("<column"+span+"><![CDATA["+val+"]]></column>");
			}
			xml.push("</columns>");
		};
		xml.push("</foot>");
	    return xml.join("\n");
	};
	function get_style(node, style){
		return (window.getComputedStyle?(window.getComputedStyle(node, null)[style]):(node.currentStyle?node.currentStyle[style]:null))||"";
	};
	
	function xml_row(ind){
		if (!grid.rowsBuffer[ind]) return "";
		var r = grid.render_row(ind);
		if (r.style.display=="none") return "";
		var level = grid.isTreeGrid() ? ' level="' + grid.getLevel(r.idd) + '"' : '';
		var xml = "<row" + level + ">";
		for (var i=0; i < grid._cCount; i++) {
			if (((!grid._srClmn)||(grid._srClmn[i]))&&(!grid._hrrar[i] || ( grid._fake && i < grid._fake.hdrLabels.length))){
				var cell = grid.cells(r.idd, i);
				if (full_color){
					var text_color	= get_style(cell.cell,"color");
		        	var bg_color	= get_style(cell.cell,"backgroundColor");
					var bold		= get_style(cell.cell, "font-weight") || get_style(cell.cell, "fontWeight");
					var italic		= get_style(cell.cell, "font-style") || get_style(cell.cell, "fontStyle");
					var align		= get_style(cell.cell, "text-align") || get_style(cell.cell, "textAlign");
					var font	 = get_style(cell.cell, "font-family") || get_style(cell.cell, "fontFamily");
		        	if (bg_color == "transparent" || bg_color == "rgba(0, 0, 0, 0)") bg_color = "rgb(255,255,255)";
		        	xml+="<cell bgColor='"+bg_color+"' textColor='" + text_color + "' bold='" + bold + "' italic='" + italic + "' align='"+align+"' font='" + font + "'>";
				} else 
					xml+="<cell>";
				
				xml+="<![CDATA["+(cell.getContent?cell.getContent():cell.getTitle())+"]]></cell>";
			}
		};
		return xml+"</row>";
	}
	function xml_end(){
	    var xml = "</rows>";
	    return xml;
	}


			
	var d=document.createElement("div");
	d.style.display="none";
	document.body.appendChild(d);
	var uid = "form_"+grid.uid();

	d.innerHTML = '<form id="'+uid+'" method="post" action="'+url+'" accept-charset="utf-8"  enctype="application/x-www-form-urlencoded"' + this.target + '><input type="hidden" name="grid_xml" id="grid_xml"/> </form>';
	document.getElementById(uid).firstChild.value = encodeURIComponent(xml_top(mode).replace("\u2013", "-") + xml_body() + xml_end());
	document.getElementById(uid).submit();
	d.parentNode.removeChild(d);


	grid = null;
	
	if (save_sel) {
		save_sel.el.parentNode.className += ' rowselected';
		save_sel.el.className += ' cellselected';
	};
	save_sel = null;
};
dhtmlXGridObject.prototype._serialiseExportConfig=function(spans){
	function xmlentities(str) {
		if (typeof(str)!=='string') return str;
		str = str.replace(/&/g, "&amp;");
		str = str.replace(/"/g, "&quot;");
		str = str.replace(/'/g, "&apos;");
		str = str.replace(/</g, "&lt;");
		str = str.replace(/>/g, "&gt;");
		return str;
	}
	
	var out = "<head>";

	for (var i = 0; i < this.hdr.rows[0].cells.length; i++){
		if (this._srClmn && !this._srClmn[i]) continue;
		if (this._hrrar[i] && ( !this._fake || i >= this._fake.hdrLabels.length)) continue;
		var sort = this.fldSort[i];
		if (sort == "cus"){
			sort = this._customSorts[i].toString();
			sort=sort.replace(/function[\ ]*/,"").replace(/\([^\f]*/,"");
		}
		var s = spans[1][i];
		var rpans = (( s[1] && s[1] > 1 ) ? ' rowspan="'+s[1]+'" ' : "")+(( s[0] && s[0] > 1 ) ? ' colspan="'+s[0]+'" ' : "");
		out+="<column "+rpans+" width='"+this.getColWidth(i)+"' align='"+this.cellAlign[i]+"' type='"+this.cellType[i] + "' hidden='" + ((this.isColumnHidden && this.isColumnHidden(i)) ? 'true' : 'false')
			+"' sort='"+(sort||"na")+"' color='"+(this.columnColor[i]||"")+"'"
			+(this.columnIds[i]
				? (" id='"+this.columnIds[i]+"'")
				: "")+">";
		if (this._asCDATA)
			out+="<![CDATA["+this.getHeaderCol(i)+"]]>";
		else
			out+=this.getHeaderCol(i);
		var z = this.combos[i]?this.getCombo(i):null;

		if (z)
			for (var j = 0; j < z.keys.length; j++)out+="<option value='"+xmlentities(z.keys[j])+"'><![CDATA["+z.values[j]+"]]></option>";
		out+="</column>";
	}
	return out+="</head>";
};
if (window.eXcell_sub_row_grid)
	window.eXcell_sub_row_grid.prototype.getContent=function(){ return ""; };


dhtmlXGridObject.prototype.toExcel = function(url,mode,header,footer,rows) {
	if (!document.getElementById('ifr')) {
		var ifr = document.createElement('iframe');
		ifr.style.display = 'none';
		ifr.setAttribute('name', 'dhx_export_iframe');
		ifr.setAttribute('src', '');
		ifr.setAttribute('id', 'dhx_export_iframe');
		document.body.appendChild(ifr);
	}

	var target = " target=\"dhx_export_iframe\"";
	this.toPDF(url,mode,header,footer,rows,target);
}
