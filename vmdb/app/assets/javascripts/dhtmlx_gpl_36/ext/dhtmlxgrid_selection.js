//v.3.6 build 131108

/*
Copyright DHTMLX LTD. http://www.dhtmlx.com
You allowed to use this component or parts of it under GPL terms
To use it on other terms or get Professional edition of the component please contact us at sales@dhtmlx.com
*/
/**
*     @desc: enables block selection mode in grid
*     @type: public
*     @topic: 0
*/
dhtmlXGridObject.prototype.enableBlockSelection = function(mode)
{
	if (typeof this._bs_mode == "undefined"){
		var self = this;
		this.obj.onmousedown = function(e) {
			if (self._bs_mode) self._OnSelectionStart((e||event),this); return true;
		}
		this._CSVRowDelimiter = this.csv.row;
		this.attachEvent("onResize", function() {self._HideSelection(); return true;});
		this.attachEvent("onGridReconstructed", function() {self._HideSelection(); return true;});
		this.attachEvent("onFilterEnd",this._HideSelection);
	}
	if (mode===false){
		this._bs_mode=false;
		return this._HideSelection();
	} else this._bs_mode=true;
}
/**
*     @desc:  affect block selection, so it will copy|paste only visible text , not values behind
*	  @param: mode - true/false
*     @type: public
*     @topic: 0
*/
dhtmlXGridObject.prototype.forceLabelSelection = function(mode)
{
	this._strictText = convertStringToBoolean(mode)
}


dhtmlXGridObject.prototype.disableBlockSelection = function()
{
	this.obj.onmousedown = null;
}
	
dhtmlXGridObject.prototype._OnSelectionStart = function(event, obj)
{

	var self = this;
	if (event.button == 2) return;
	var src = event.srcElement || event.target;
	if (this.editor){
		if (src.tagName && (src.tagName=="INPUT" || src.tagName=="TEXTAREA"))   return;
		this.editStop();
	}
	
	self.setActive(true);
	var pos = this.getPosition(this.obj);
	var x = event.clientX - pos[0] + (document.body.scrollLeft||(document.documentElement?document.documentElement.scrollLeft:0));
	var y = event.clientY - pos[1] + (document.body.scrollTop||(document.documentElement?document.documentElement.scrollTop:0));
	this._CreateSelection(x-4, y-4);

	if (src == this._selectionObj) {
		this._HideSelection();
		this._startSelectionCell = null;
	} else {
	    while (src.tagName.toLowerCase() != 'td')
	        src = src.parentNode;
	    this._startSelectionCell = src;
	}
	
	if (this._startSelectionCell){
		if (!this.callEvent("onBeforeBlockSelected",[this._startSelectionCell.parentNode.idd, this._startSelectionCell._cellIndex]))
			return this._startSelectionCell = null;
	}
	
	    //this._ShowSelection();
	    this.obj.onmousedown = null;
		this.obj[_isIE?"onmouseleave":"onmouseout"] = function(e){ if (self._blsTimer) window.clearTimeout(self._blsTimer); };	    
		this.obj.onmmold=this.obj.onmousemove;
		this._init_pos=[x,y];
	    this._selectionObj.onmousemove = this.obj.onmousemove = function(e) {e = e||event; e.returnValue = false;  self._OnSelectionMove(e);}
	    
	    
	    this._oldDMP=document.body.onmouseup;
	    document.body.onmouseup = function(e) {e = e||event; self._OnSelectionStop(e, this); return true; }
	this.callEvent("onBeforeBlockSelection",[]);
	document.body.onselectstart = function(){return false};//avoid text select	    
}

dhtmlXGridObject.prototype._getCellByPos = function(x,y){
	x=x;//+this.objBox.scrollLeft;
	if (this._fake)
		x+=this._fake.objBox.scrollHeight;
	y=y;//+this.objBox.scrollTop;
	var _x=0;
	for (var i=0; i < this.obj.rows.length; i++) {
		y-=this.obj.rows[i].offsetHeight;
		if (y<=0) {
			_x=this.obj.rows[i];
			break;
		}
	}
	if (!_x || !_x.idd) return null;
	for (var i=0; i < this._cCount; i++) {
		x-=this.getColWidth(i);
		if (x<=0) {
			while(true){
				if (_x._childIndexes && _x._childIndexes[i+1]==_x._childIndexes[i])
					_x=_x.previousSibling;
				else {
					return this.cells(_x.idd,i).cell;
				}
				
			}
		}
	}
	return null;
}

dhtmlXGridObject.prototype._OnSelectionMove = function(event)
{ 
	
	var self=this;
	this._ShowSelection();
	var pos = this.getPosition(this.obj);
	var X = event.clientX - pos[0] + (document.body.scrollLeft||(document.documentElement?document.documentElement.scrollLeft:0));
	var Y = event.clientY - pos[1] + (document.body.scrollTop||(document.documentElement?document.documentElement.scrollTop:0));

	if ((Math.abs(this._init_pos[0]-X)<5) && (Math.abs(this._init_pos[1]-Y)<5)) return this._HideSelection();
	
	var temp = this._endSelectionCell;
	if(this._startSelectionCell==null)
 		this._endSelectionCell  = this._startSelectionCell = this.getFirstParentOfType(event.srcElement || event.target,"TD");		
	else
		if (event.srcElement || event.target) {
			if ((event.srcElement || event.target).className == "dhtmlxGrid_selection")
				this._endSelectionCell=(this._getCellByPos(X,Y)||this._endSelectionCell);
			else {
				var t = this.getFirstParentOfType(event.srcElement || event.target,"TD");
				if (t.parentNode.idd) this._endSelectionCell = t;
			}
		}
		
	if (this._endSelectionCell){
		if (!this.callEvent("onBeforeBlockSelected",[this._endSelectionCell.parentNode.idd, this._endSelectionCell._cellIndex]))
			this._endSelectionCell = temp;
	}
	
		/*
	//window.status = pos[0]+'+'+pos[1];
	var prevX = this._selectionObj.startX;
	var prevY = this._selectionObj.startY;
	var diffX = X - prevX;
	var diffY = Y - prevY;
	
	if (diffX < 0) {
        this._selectionObj.style.left = this._selectionObj.startX + diffX + 1+"px";
        diffX = 0 - diffX;
	} else {
		this._selectionObj.style.left = this._selectionObj.startX - 3+"px";
	}
	if (diffY < 0) {
		this._selectionObj.style.top = this._selectionObj.startY + diffY + 1+"px";
        diffY = 0 - diffY;
	} else {
		this._selectionObj.style.top = this._selectionObj.startY - 3+"px";
	}
    this._selectionObj.style.width = (diffX>4?diffX-4:0) + 'px';
    this._selectionObj.style.height = (diffY>4?diffY-4:0) + 'px';


/* AUTO SCROLL */
	var BottomRightX = this.objBox.scrollLeft + this.objBox.clientWidth;
	var BottomRightY = this.objBox.scrollTop + this.objBox.clientHeight;
	var TopLeftX = this.objBox.scrollLeft;
	var TopLeftY = this.objBox.scrollTop;

	var nextCall=false;
	if (this._blsTimer) window.clearTimeout(this._blsTimer);	
	
	if (X+20 >= BottomRightX) {
		this.objBox.scrollLeft = this.objBox.scrollLeft+20;
		nextCall=true;
	} else if (X-20 < TopLeftX) {
		this.objBox.scrollLeft = this.objBox.scrollLeft-20;
		nextCall=true;
	}
	if (Y+20 >= BottomRightY && !this._realfake) {
		this.objBox.scrollTop = this.objBox.scrollTop+20;
		nextCall=true;
	} else if (Y-20 < TopLeftY && !this._realfake) {
		this.objBox.scrollTop = this.objBox.scrollTop-20;
		nextCall=true;		
	}
	this._selectionArea = this._RedrawSelectionPos(this._startSelectionCell, this._endSelectionCell);
	

	if (nextCall){ 
		var a=event.clientX;
		var b=event.clientY;
		this._blsTimer=window.setTimeout(function(){self._OnSelectionMove({clientX:a,clientY:b})},100);
	}
	
}

dhtmlXGridObject.prototype._OnSelectionStop = function(event)
{
	var self = this;
	if (this._blsTimer) window.clearTimeout(this._blsTimer);	
	this.obj.onmousedown = function(e) {if (self._bs_mode)  self._OnSelectionStart((e||event), this); return true;}
	this.obj.onmousemove = this.obj.onmmold||null;
	this._selectionObj.onmousemove = null;
	document.body.onmouseup = this._oldDMP||null;
	if ( parseInt( this._selectionObj.style.width ) < 2 && parseInt( this._selectionObj.style.height ) < 2) {
		this._HideSelection();
	} else {
	    var src = this.getFirstParentOfType(event.srcElement || event.target,"TD");
	    if ((!src) || (!src.parentNode.idd)){
	    	src=this._endSelectionCell;
    		}
    	if (!src) return this._HideSelection();
	    while (src.tagName.toLowerCase() != 'td')
	        src = src.parentNode;
	    this._stopSelectionCell = src;
	    this._selectionArea = this._RedrawSelectionPos(this._startSelectionCell, this._stopSelectionCell);
		this.callEvent("onBlockSelected",[]);
	}
	document.body.onselectstart = function(){};//avoid text select
}

dhtmlXGridObject.prototype._RedrawSelectionPos = function(LeftTop, RightBottom)
{

//	td._cellIndex
//
//	getRowIndex
	var pos = {};
	pos.LeftTopCol = LeftTop._cellIndex;
	pos.LeftTopRow = this.getRowIndex( LeftTop.parentNode.idd );
	pos.RightBottomCol = RightBottom._cellIndex;
	pos.RightBottomRow = this.getRowIndex( RightBottom.parentNode.idd );

	var LeftTop_width = LeftTop.offsetWidth;
	var LeftTop_height = LeftTop.offsetHeight;
	LeftTop = this.getPosition(LeftTop, this.obj);

	var RightBottom_width = RightBottom.offsetWidth;
	var RightBottom_height = RightBottom.offsetHeight;
	RightBottom = this.getPosition(RightBottom, this.obj);

    if (LeftTop[0] < RightBottom[0]) {
		var Left = LeftTop[0];
		var Right = RightBottom[0] + RightBottom_width;
    } else {
    	var foo = pos.RightBottomCol;
        pos.RightBottomCol = pos.LeftTopCol;
        pos.LeftTopCol = foo;
		var Left = RightBottom[0];
		var Right = LeftTop[0] + LeftTop_width;
    }

    if (LeftTop[1] < RightBottom[1]) {
		var Top = LeftTop[1];
		var Bottom = RightBottom[1] + RightBottom_height;
    } else {
    	var foo = pos.RightBottomRow;
        pos.RightBottomRow = pos.LeftTopRow;
        pos.LeftTopRow = foo;
		var Top = RightBottom[1];
		var Bottom = LeftTop[1] + LeftTop_height;
    }

    var Width = Right - Left;
    var Height = Bottom - Top;

	this._selectionObj.style.left = Left + 'px';
	this._selectionObj.style.top = Top + 'px';
	this._selectionObj.style.width =  Width  + 'px';
	this._selectionObj.style.height = Height + 'px';
	return pos;
}

dhtmlXGridObject.prototype._CreateSelection = function(x, y)
{
	if (this._selectionObj == null) {
		var div = document.createElement('div');
		div.style.position = 'absolute';
        div.style.display = 'none';
        div.className = 'dhtmlxGrid_selection';
		this._selectionObj = div;
		this._selectionObj.onmousedown = function(e){
			e=e||event;
			if (e.button==2 || (_isMacOS&&e.ctrlKey))
				return this.parentNode.grid.callEvent("onBlockRightClick", ["BLOCK",e]);
		}
		this._selectionObj.oncontextmenu=function(e){(e||event).cancelBubble=true;return false;}
		this.objBox.appendChild(this._selectionObj);
	}
    //this._selectionObj.style.border = '1px solid #83abeb';
    this._selectionObj.style.width = '0px';
    this._selectionObj.style.height = '0px';
    //this._selectionObj.style.border = '0px';
	this._selectionObj.style.left = x + 'px';
	this._selectionObj.style.top  = y + 'px';
    this._selectionObj.startX = x;
    this._selectionObj.startY = y;
}

dhtmlXGridObject.prototype._ShowSelection = function()
{
	if (this._selectionObj)
	    this._selectionObj.style.display = '';
}

dhtmlXGridObject.prototype._HideSelection = function()
{
	
	if (this._selectionObj)
	    this._selectionObj.style.display = 'none';
    this._selectionArea = null;
}
/**
*     @desc: copy content of block selection into clipboard in csv format (delimiter as set for csv serialization)
*     @type: public
*     @topic: 0
*/
dhtmlXGridObject.prototype.copyBlockToClipboard = function()
{
	if ( this._selectionArea != null ) {
		var serialized = new Array();
	if (this._mathSerialization)
         this._agetm="getMathValue";
    else if (this._strictText)
    	this._agetm="getTitle";
    else this._agetm="getValue";

    this._serialize_visible = true;

		for (var i=this._selectionArea.LeftTopRow; i<=this._selectionArea.RightBottomRow; i++) {
			var data = this._serializeRowToCVS(this.rowsBuffer[i], null,  this._selectionArea.LeftTopCol, this._selectionArea.RightBottomCol+1);
			if (!this._csvAID)
				serialized[serialized.length] = data.substr( data.indexOf( this.csv.cell ) + 1 );	//remove row ID and add to array
			else
				serialized[serialized.length] = data;
		}
		serialized = serialized.join(this._CSVRowDelimiter);
		this.toClipBoard(serialized);

	this._serialize_visible = false;
	}
}
/**
*     @desc: paste content of clipboard into block selection of grid
*     @type: public
*     @topic: 0
*/
dhtmlXGridObject.prototype.pasteBlockFromClipboard = function()
{
	var serialized = this.fromClipBoard();
    if (this._selectionArea != null) {
        var startRow = this._selectionArea.LeftTopRow;
        var startCol = this._selectionArea.LeftTopCol;
    } else if (this.cell != null && !this.editor) {
        var startRow = this.getRowIndex( this.cell.parentNode.idd );
        var startCol = this.cell._cellIndex;
    } else {
        return false;
    }

	serialized = this.csvParser.unblock(serialized, this.csv.cell, this.csv.row);
   // if ((serialized.length >1)&&(serialized[serialized.length-1]==""))
   // serialized.splice(serialized.length-1,1);
     
   //	if (serialized[serialized.length-1]=="") serialized.pop();
 /*   for (var i=0; i<serialized.length; i++) {
        serialized[i] = serialized[i].split(this.csv.cell);
    }*/
    var endRow = startRow+serialized.length;
    var endCol = startCol+serialized[0].length;
    if (endCol > this._cCount)
		endCol = this._cCount;
    var k = 0;
    for (var i=startRow; i<endRow; i++) {
        var row = this.render_row(i);
        if (row==-1) continue;
        var l = 0;
        for (var j=startCol; j<endCol; j++) {
        	if (this._hrrar[j]){
        		endCol = Math.max(endCol+1, this._cCount);
        		continue;
        	}
        	var ed = this.cells3(row, j);
        	if (ed.isDisabled()) {
        	    l++;
        	    continue;
        	}
        	if (this._onEditUndoRedo)
        		this._onEditUndoRedo(2, row.idd, j, serialized[ k ][ l ], ed.getValue());
        	if (ed.combo){
				var comboVa = ed.combo.values;
				for(var n=0; n<comboVa.length; n++)
					if (serialized[ k ][ l ] == comboVa[n]){
						ed.setValue( ed.combo.keys[ n ]);
						comboVa=null;
						break;
					}
				if (comboVa!=null && ed.editable) ed.setValue( serialized[ k ][ l++ ] );
				else l++;
        	}else
        		ed[ ed.setImage ? "setLabel" : "setValue" ]( serialized[ k ][ l++ ] );
        	ed.cell.wasChanged=true;
        }
        this.callEvent("onRowPaste",[row.idd])
        k++;
    }
}

dhtmlXGridObject.prototype.getSelectedBlock = function() {
	// if block selection exists
	if (this._selectionArea)
		return this._selectionArea;
	else if (this.getSelectedRowId() !== null){
		// if one cell is selected
			return {
				LeftTopRow: this.getSelectedRowId(),
				LeftTopCol: this.getSelectedCellIndex(),
				RightBottomRow: this.getSelectedRowId(),
				RightBottomCol: this.getSelectedCellIndex()
			};
		} else
			return null;
};
//(c)dhtmlx ltd. www.dhtmlx.com
