//v.3.6 build 131108

/*
Copyright DHTMLX LTD. http://www.dhtmlx.com
You allowed to use this component or parts of it under GPL terms
To use it on other terms or get Professional edition of the component please contact us at sales@dhtmlx.com
*/
/**
*   @desc: enable smart rendering mode
*   @type: public
*   @param: mode - true|false - enable|disable mode
*   @param: buffer - has sense only in dynamic loading mode, count of rows requrested from server by single operation, optional
*   @topic: 0
*/
dhtmlXGridObject.prototype.enableSmartRendering=function(mode,buffer,reserved){
	if (arguments.length>2){
		if (buffer && !this.rowsBuffer[buffer-1]) this.rowsBuffer[buffer-1]=0;
		buffer=reserved;
	}
	this._srnd=convertStringToBoolean(mode);
	this._srdh=this._srdh||20;
	this._dpref=buffer||0;
	
};
/**
*   @desc: allows to pre-render rows during scrolling, make scrolling more smooth, but with small drop in overall perfomance
*   @type: public
*   @param: buffer - count of rows, which will be prerendered
*   @topic: 0
*/
dhtmlXGridObject.prototype.enablePreRendering=function(buffer){
	this._srnd_pr=parseInt(buffer||50);
};
/**
*   @desc: force grid in dyn. srnd mode fully load itself from server side
*   @type: public
*   @param: buffer - how much rows grid can request from server side in one operation
*   @topic: 0
*/
dhtmlXGridObject.prototype.forceFullLoading=function(buffer, callback){
	for (var i=0; i<this.rowsBuffer.length; i++)
		if (!this.rowsBuffer[i]){
			var usedbuffer = buffer || (this.rowsBuffer.length-i);
			if (this.callEvent("onDynXLS",[i,usedbuffer])){
				var self=this;
				this.load(this.xmlFileUrl+getUrlSymbol(this.xmlFileUrl)+"posStart="+i+"&count="+usedbuffer, function(){
					window.setTimeout(function(){	self.forceFullLoading(buffer, callback); },100); 
				}, this._data_type);
			}
			return;
		}
	if (callback) callback.call(this);
};

/**
*   @desc: set height which will be used in smart rendering mode for row calculation, function need to be used if you use custom skin for grid which changes default row height
*   @type: public
   @param: {int} height - awaited height of row
*   @returns: void
*   @topic: 0
*/      
dhtmlXGridObject.prototype.setAwaitedRowHeight = function(height) {
   this._srdh=parseInt(height);
};

dhtmlXGridObject.prototype._get_view_size=function(){
	return Math.floor(parseInt(this.entBox.offsetHeight)/this._srdh)+2;
};
dhtmlXGridObject.prototype._add_filler=function(pos,len,fil,rsflag){
	if (!len) return null;
	var id="__filler__";
	var row=this._prepareRow(id);
	row.firstChild.style.width="1px";
	for (var i=1; i<row.childNodes.length; i++)
	    row.childNodes[i].style.display='none';
 	row.firstChild.style.height=len*this._srdh+"px";
 	fil=fil||this.rowsCol[pos];
 	if (fil && fil.nextSibling) 
 		fil.parentNode.insertBefore(row,fil.nextSibling);
 	else
 		if (_isKHTML)
 			this.obj.appendChild(row);
 		else
 			this.obj.rows[0].parentNode.appendChild(row);
 			
 	this.callEvent("onAddFiller",[pos,len,row,fil,rsflag]);
 	return [pos,len,row];
};
dhtmlXGridObject.prototype._update_srnd_view=function(){
	    var min=Math.floor(this.objBox.scrollTop/this._srdh);
        var max=min+this._get_view_size();
        if (this.multiLine) {
        // Calculate the min, by Stephane Bernard
            var pxHeight = this.objBox.scrollTop;
            min = 0;
            while(pxHeight > 0) {
                pxHeight-=this.rowsCol[min]?this.rowsCol[min].offsetHeight:this._srdh;
                min++;
            }
            // Calculate the max
            max=min+this._get_view_size();
            if (min>0) min--;
        }        
        max+=(this._srnd_pr||0);//pre-rendering
        if (max>this.rowsBuffer.length) max=this.rowsBuffer.length;

        for (var j=min; j<max; j++){ 
            if (!this.rowsCol[j]){
				var res=this._add_from_buffer(j);
				if (res==-1){
					if (this.xmlFileUrl){
						if (this._dpref && this.rowsBuffer[max-1]){
							//we have last row in sett, assuming that we in scrolling up process
							var rows_count = this._dpref?this._dpref:(max-j)
							var start_pos = Math.max(0, max - this._dpref);
							this._current_load=[start_pos, max-start_pos];
						} else 
							this._current_load=[j,(this._dpref?this._dpref:(max-j))];
						if (this.callEvent("onDynXLS",this._current_load))
							this.load(this.xmlFileUrl+getUrlSymbol(this.xmlFileUrl)+"posStart="+this._current_load[0]+"&count="+this._current_load[1], this._data_type);
					}
					return;
				} else {
	               	if (this._tgle){
	               		this._updateLine(this._h2.get[this.rowsBuffer[j].idd],this.rowsBuffer[j]);
	               		this._updateParentLine(this._h2.get[this.rowsBuffer[j].idd],this.rowsBuffer[j]);
	           		}
					if (j && j==(this._realfake?this._fake:this)["_r_select"]){
						this.selectCell(j, this.cell?this.cell._cellIndex:0, true);
					}
				}
            }
		}
	if (this._fake && !this._realfake && this.multiLine) 
		this._fake.objBox.scrollTop = this.objBox.scrollTop;		
}
dhtmlXGridObject.prototype._add_from_buffer=function(ind){
	    var row=this.render_row(ind);
	    if (row==-1) return -1;
	    if (row._attrs["selected"] || row._attrs["select"]){
			this.selectRow(row,false,true);
			row._attrs["selected"]=row._attrs["select"]=null;
		}
						
	    if (!this._cssSP){ 
		    if (this._cssEven && ind%2 == 0 )
				row.className=this._cssEven+((row.className.indexOf("rowselected") != -1)?" rowselected ":" ")+(row._css||"");
			else if (this._cssUnEven && ind%2 == 1 )
			    row.className=this._cssUnEven+((row.className.indexOf("rowselected") != -1)?" rowselected ":" ")+(row._css||"");				
			} else if (this._h2) {
				var x=this._h2.get[row.idd];
				row.className+=" "+((x.level%2)?(this._cssUnEven+" "+this._cssUnEven):(this._cssEven+" "+this._cssEven))+"_"+x.level+(this.rowsAr[x.id]._css||"");
			}
			

	    //now we need to get location of node
	    for (var i=0; i<this._fillers.length; i++){
	    	var f=this._fillers[i];
	    	if (f && f[0]<=ind && (f[0]+f[1])>ind ){
	    		//filler found
	    		var pos=ind-f[0];
	    		if (pos==0){
	    			//start
	    			this._insert_before(ind,row,f[2]);
	    			this._update_fillers(i,-1,1);
	    		} else if (pos == f[1]-1){
	    			this._insert_after(ind,row,f[2]);
	    			this._update_fillers(i,-1,0);
	    		} else {
	    			this._fillers.push(this._add_filler(ind+1,f[1]-pos-1,f[2],1));
	    			this._insert_after(ind,row,f[2]);
	    			this._update_fillers(i,-f[1]+pos,0);
	    		}
	    		return;
	    	}
	    }
}
dhtmlXGridObject.prototype._update_fillers=function(ind,right,left){
	var f=this._fillers[ind];
	f[1]=f[1]+right;
	f[0]=f[0]+left;
	if (!f[1]){
		this.callEvent("onRemoveFiller",[f[2]]);
		f[2].parentNode.removeChild(f[2]);
		this._fillers.splice(ind,1);
	} else {
		f[2].firstChild.style.height=parseFloat(f[2].firstChild.style.height)+right*this._srdh+"px";	
		this.callEvent("onUpdateFiller",[f[2]]);
	}
}
dhtmlXGridObject.prototype._insert_before=function(ind,row,fil){
	fil.parentNode.insertBefore(row,fil);
	this.rowsCol[ind]=row;
	this.callEvent("onRowInserted",[row,null,fil,"before"]);
}
dhtmlXGridObject.prototype._insert_after=function(ind,row,fil){
	if (fil.nextSibling)
		fil.parentNode.insertBefore(row,fil.nextSibling);
	else
		fil.parentNode.appendChild(row);
	this.rowsCol[ind]=row;
	this.callEvent("onRowInserted",[row,null,fil,"after"]);
}
