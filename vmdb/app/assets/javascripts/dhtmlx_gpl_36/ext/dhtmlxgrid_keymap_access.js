//v.3.6 build 131108

/*
Copyright DHTMLX LTD. http://www.dhtmlx.com
You allowed to use this component or parts of it under GPL terms
To use it on other terms or get Professional edition of the component please contact us at sales@dhtmlx.com
*/
/*
	keymap like MS Access offers
*/
dhtmlXGridObject.prototype._select_ifpossible=function(){
	if (this.editor && this.editor.obj && this.editor.obj.select) this.editor.obj.select();
};
dhtmlXGridObject.prototype._key_events={
			//ctrl-enter
			k13_1_0:function(){
				this.editStop();
			},
			//shift-enter
			k13_0_1:function(){
				this._key_events.k9_0_1.call(this);
			},
			//enter
			k13_0_0:function(){
				this._key_events.k9_0_0.call(this);
            },
            //tab
            k9_0_0:function(){
					this.editStop();
				if (!this.callEvent("onTab",[true])) return true;
				var z=this._getNextCell(null,1);
				if (z) {
					if (this.pagingOn) this.showRow(z.parentNode.idd);
					this.selectCell(z.parentNode,z._cellIndex,(this.row!=z.parentNode),false,true);
					this._still_active=true;
				}
				this._select_ifpossible();
            },
            //shift-tab
			k9_0_1:function(){
				this.editStop();
				if (!this.callEvent("onTab",[false])) return true;
				var z=this._getNextCell(null,-1);
				if (z) {
					this.selectCell(z.parentNode,z._cellIndex,(this.row!=z.parentNode),false,true);
					this._still_active=true;
				}
				this._select_ifpossible();
            },
            //f2 key
            k113_0_0:function(){
            	if (this._f2kE) this.editCell();
            },
            //space
            k32_0_0:function(){
            	var c=this.cells4(this.cell);
            	if (!c.changeState || (c.changeState()===false)) return false;
            },
            //escape
            k27_0_0:function(){
            	this.editStop(true);
            },
            //pageUp
            k33_0_0:function(){
            	if(this.pagingOn)
            		this.changePage(this.currentPage-1);
            	else this.scrollPage(-1);            		
	        },
	        //pageDown
			k34_0_0:function(){
            	if(this.pagingOn)
            		this.changePage(this.currentPage+1);
            	else this.scrollPage(1);
	        },
	        //left
			k37_0_0:function(){
				if (this.editor) return false;
            	if(this.isTreeGrid())
            		this.collapseKids(this.row);
            	else this._key_events.k9_0_1.call(this);
	        },
	        //right
			k39_0_0:function(){
				if (this.editor) return false;
				if(!this.editor && this.isTreeGrid())
            		this.expandKids(this.row);
            	else this._key_events.k9_0_0.call(this);
            },
            //ctrl left
			k37_1_0:function(){
				if (this.editor) return false;
				this.selectCell(this.row,0,false,false,true);
				this._select_ifpossible();
	        },
	        //ctrl right
			k39_1_0:function(){
				if (this.editor) return false;
				this.selectCell(this.row,this._cCount-1,false,false,true);
				this._select_ifpossible();
            },
            //ctrl up
			k38_1_0:function(){
			
				this.selectCell(this.rowsCol[0],this.cell._cellIndex,true,false,true);
				this._select_ifpossible();
	        },
	        //ctrl down
			k40_1_0:function(){
				this.selectCell(this.rowsCol[this.rowsCol.length-1],this.cell._cellIndex,true,false,true);
				this._select_ifpossible();
            },
            //shift up
			k38_0_1:function(){
				var rowInd = this.getRowIndex(this.row.idd);
				var nrow=this._nextRow(rowInd,-1);
				if (!nrow || nrow._sRow || nrow._rLoad) return false;
                this.selectCell(nrow,this.cell._cellIndex,true,false,true);
				this._select_ifpossible();
	        },
	        //shift down
			k40_0_1:function(){
				var rowInd = this.getRowIndex(this.row.idd);
				var nrow=this._nextRow(rowInd,1);
				if (!nrow || nrow._sRow || nrow._rLoad) return false;
                this.selectCell(nrow,this.cell._cellIndex,true,false,true);
                this._select_ifpossible();
            },   
            //ctrl shift up  
			k38_1_1:function(){
				var rowInd = this.getRowIndex(this.row.idd);
				for (var i = rowInd; i >= 0; i--){
					this.selectCell(this.rowsCol[i],this.cell._cellIndex,true,false,true);
				}
	        },
	        //ctrl shift down
			k40_1_1:function(){
				var rowInd = this.getRowIndex(this.row.idd);
				for (var i = rowInd+1; i <this.rowsCol.length; i++){
					this.selectCell(this.rowsCol[i],this.cell._cellIndex,true,false,true);
				}
            },    
            //down               
			k40_0_0:function(){
				if (this.editor && this.editor.combo)
					this.editor.shiftNext();
				else{
					if (!this.row.idd) return;
					var rowInd = rowInd=this.getRowIndex(this.row.idd)+1;
					if (this.rowsBuffer[rowInd]){
						var nrow=this._nextRow(rowInd-1,1);
						if (this.pagingOn && nrow) this.showRow(nrow.idd);
						this._Opera_stop=0;
                        this.selectCell(nrow,this.cell._cellIndex,true,false,true);
                    }
                    else {
                    	if (!this.callEvent("onLastRow", [])) return false;
                    	this._key_events.k34_0_0.apply(this,[]);
                	}
				}
				this._still_active=true;								
            },
            //home
            k36_0_0:function(){ 
            	return this._key_events.k37_1_0.call(this);
            },
            //end
            k35_0_0:function(){ 
            	return this._key_events.k39_1_0.call(this);
            },            
            //ctrl-home
            k36_1_0:function(){ 
            	if (this.editor || !this.rowsCol.length) return false;
				this.selectCell(this.rowsCol[0],0,true,false,true);
				this._select_ifpossible();
            },
            //ctrl-end
            k35_1_0:function(){ 
            	if (this.editor || !this.rowsCol.length) return false;
				this.selectCell(this.rowsCol[this.rowsCol.length-1],this._cCount-1,true,false,true);
				this._select_ifpossible();
            },  
            //padeup
            k33_0_0:function(){
            	if(this.pagingOn)
            		this.changePage(this.currentPage-1);
            	else this.scrollPage(-1);            		
	        },
	        //pagedown
			k34_0_0:function(){
            	if(this.pagingOn)
            		this.changePage(this.currentPage+1);
            	else this.scrollPage(1);
	        },  
	        //up                                
			k38_0_0:function(){
				if (this.editor && this.editor.combo)
					this.editor.shiftPrev();
				else{
				
					if (!this.row.idd) return;
					var rowInd = rowInd=this.getRowIndex(this.row.idd)+1;
					if (rowInd!=-1){
						var nrow=this._nextRow(rowInd-1,-1);
                        this._Opera_stop=0;
                        if (this.pagingOn && nrow) this.showRow(nrow.idd);
                        this.selectCell(nrow,this.cell._cellIndex,true,false,true);
                    }
					else this._key_events.k33_0_0.apply(this,[]);
				}
				this._still_active=true;
            }
		};
