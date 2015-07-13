//v.3.6 build 131108

/*
Copyright DHTMLX LTD. http://www.dhtmlx.com
You allowed to use this component or parts of it under GPL terms
To use it on other terms or get Professional edition of the component please contact us at sales@dhtmlx.com
*/
/*
	keymap like MS Excel offers
*/
dhtmlXGridObject.prototype._key_events={
			k13_1_0:function(){
				this.editStop();
			},
			k13_0_1:function(){
				this.editStop();
				this._key_events.k38_0_0.call(this);
			},
			k13_0_0:function(){
				this.editStop();
				this.callEvent("onEnter",[(this.row?this.row.idd:null),(this.cell?this.cell._cellIndex:null)]);
				this._still_active=true;
				this._key_events.k40_0_0.call(this);
            },
            k9_0_0:function(){
				this.editStop();
				if (!this.callEvent("onTab",[true])) return true;
				if (this.cell && (this.cell._cellIndex+1)>=this._cCount) return;
				var z=this._getNextCell(null,1);
				if (z && this.row==z.parentNode){
					this.selectCell(z.parentNode,z._cellIndex,true);
					this._still_active=true;
				}
			},
			k9_0_1:function(){
				this.editStop();
				if (!this.callEvent("onTab",[false])) return true;
				if (this.cell && (this.cell._cellIndex==0)) return;
				var z=this._getNextCell(null,-1);
				if (z && this.row==z.parentNode) {
					this.selectCell(z.parentNode,z._cellIndex,true);
					this._still_active=true;
				}
            },
            k113_0_0:function(){
            	if (this._f2kE) this.editCell();
            },
            k32_0_0:function(){
            	var c=this.cells4(this.cell);
            	if (!c.changeState || (c.changeState()===false)) return false;
            },
            k27_0_0:function(){
            	this.editStop(true);
            	this._still_active=true;
            },
            k33_0_0:function(){
            	if(this.pagingOn)
            		this.changePage(this.currentPage-1);
            	else this.scrollPage(-1);            		
	        },
			k34_0_0:function(){
            	if(this.pagingOn)
            		this.changePage(this.currentPage+1);
            	else this.scrollPage(1);
	        },
			k37_0_0:function(){
				if (this.editor) return false;
            	if(this.isTreeGrid())
            		this.collapseKids(this.row)
            	else this._key_events.k9_0_1.call(this);
	        },
			k39_0_0:function(){
				if (this.editor) return false;
				if(!this.editor && this.isTreeGrid())
            		this.expandKids(this.row)
            	else this._key_events.k9_0_0.call(this);
            },
			k37_1_0:function(){
				if (this.editor) return false;
				this.selectCell(this.row,0,true);
	        },
			k39_1_0:function(){
				if (this.editor) return false;
				this.selectCell(this.row,this._cCount-1,true);
            }, 
			k38_1_0:function(){
				if (this.editor || !this.rowsCol.length) return false;
				this.selectCell(this.rowsCol[0],this.cell._cellIndex,true);
	        },
			k40_1_0:function(){
				if (this.editor || !this.rowsCol.length) return false;
				this.selectCell(this.rowsCol[this.rowsCol.length-1],this.cell._cellIndex,true);
            },
			k38_0_1:function(){
				if (this.editor || !this.rowsCol.length) return false;
				var rowInd = this.row.rowIndex;
				var nrow=this._nextRow(rowInd-1,-1);
				if (!nrow || nrow._sRow || nrow._rLoad) return false;
                this.selectCell(nrow,this.cell._cellIndex,true,true);
	        },
			k40_0_1:function(){
				if (this.editor || !this.rowsCol.length) return false;
				var rowInd = this.row.rowIndex;
				var nrow=this._nextRow(rowInd-1,1);
				if (!nrow || nrow._sRow || nrow._rLoad) return false;
                this.selectCell(nrow,this.cell._cellIndex,true,true);
            },     
			k38_1_1:function(){
				if (this.editor || !this.rowsCol.length) return false;
				var rowInd = this.row.rowIndex;
				for (var i = rowInd - 1; i >= 0; i--){
					this.selectCell(this.rowsCol[i],this.cell._cellIndex,true,true);
				}
	        },
			k40_1_1:function(){
				if (this.editor || !this.rowsCol.length) return false;
				var rowInd = this.row.rowIndex;
				for (var i = rowInd; i <this.rowsCol.length; i++){
					this.selectCell(this.rowsCol[i],this.cell._cellIndex,true,true);
				}
            },                   
			k40_0_0:function(){
				var master = this._realfake?this._fake:this;
				if (this.editor && this.editor.combo)
					this.editor.shiftNext();
				else{
					if (this.editor) return false;
					var rowInd = Math.max((master._r_select||0),this.getRowIndex(this.row.idd));
					var row = this._nextRow(rowInd, 1);

					if (row){
						master._r_select=null;
						this.selectCell(row, this.cell._cellIndex, true);
						if (master.pagingOn) master.showRow(row.idd);
					} else {
                    	if (!this.callEvent("onLastRow", [])) return false;
                    	this._key_events.k34_0_0.apply(this,[]);
                	}
				}
            },
            k36_0_0:function(){ //home
            	return this._key_events.k37_1_0.call(this);
            },
            k35_0_0:function(){ //ctrl-home
            	return this._key_events.k39_1_0.call(this);
            },            
            k36_1_0:function(){ //home
            	if (this.editor || !this.rowsCol.length) return false;
				this.selectCell(this.rowsCol[0],0,true);
            },
            k35_1_0:function(){ //ctrl-end
            	if (this.editor || !this.rowsCol.length) return false;
				this.selectCell(this.rowsCol[this.rowsCol.length-1],this._cCount-1,true);
            },  
            k33_0_0:function(){
            	if(this.pagingOn)
            		this.changePage(this.currentPage-1);
            	else this.scrollPage(-1);            		
	        },
			k34_0_0:function(){
            	if(this.pagingOn)
            		this.changePage(this.currentPage+1);
            	else this.scrollPage(1);
	        },                                  
			k38_0_0:function(){	
				var master = this._realfake?this._fake:this;
				if (this.editor && this.editor.combo)
					this.editor.shiftPrev();
				else{
					if (this.editor) return false;
					if (!this.row.idd) return;
					var rowInd = this.getRowIndex(this.row.idd)+1;
					if (rowInd != -1 && (!this.pagingOn || (rowInd!=1))){
						var nrow = this._nextRow(rowInd-1, -1);
						this.selectCell(nrow, this.cell._cellIndex, true);
						if (master.pagingOn && nrow) master.showRow(nrow.idd);
					} else {
						this._key_events.k33_0_0.apply(this,[]);
					}
				}
            },
            k_other:function(ev){ 
            	if (this.editor) return false;
            	if (!ev.ctrlKey && ev.keyCode>=40 && (ev.keyCode < 91 || (ev.keyCode >95 && ev.keyCode <111) || ev.keyCode > 187))
            		if (this.cell){
            			var c=this.cells4(this.cell);
            			if (c.isDisabled()) return false;
            			var t=c.getValue();
            			if (c.editable!==false) c.setValue("");
            			this.editCell();
            			if (this.editor) {
            				this.editor.val=t;
            				if (this.editor.obj && this.editor.obj.select)
            					this.editor.obj.select();
        				}
            			else c.setValue(t);
            		}
            }
		};