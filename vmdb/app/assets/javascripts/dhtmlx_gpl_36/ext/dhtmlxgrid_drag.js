//v.3.6 build 131108

/*
Copyright DHTMLX LTD. http://www.dhtmlx.com
You allowed to use this component or parts of it under GPL terms
To use it on other terms or get Professional edition of the component please contact us at sales@dhtmlx.com
*/
/**
*     @desc: enable/disable drag-and-drop
*     @type: public
*     @param: mode - enabled/disabled [ can be true/false/temporary_disabled - last value mean that tree can be D-n-D can be switched to true later ]
*     @topic: 0
*/
   dhtmlXGridObject.prototype.enableDragAndDrop=function(mode){
        if  (mode=="temporary_disabled"){
            this.dADTempOff=false;
            mode=true;                  }
        else
            this.dADTempOff=true;

		this.dragAndDropOff=convertStringToBoolean(mode);
		this._drag_validate=true;
		if (mode)
			this.objBox.ondragstart = function (e) {
				(e||event).cancelBubble = true;
				return false;
			}
       };

/**
*     @desc: set Drag-And-Drop behavior (child - drop as chils, sibling - drop as sibling
*     @type: public
*     @param: mode - behavior name (child,sibling,complex)
*     @topic: 0
*/
dhtmlXGridObject.prototype.setDragBehavior=function(mode){
        this.dadmodec=this.dadmodefix=0;
      switch (mode) {
         case "child": this.dadmode=0; this._sbmod=false;  break;
         case "sibling": this.dadmode=1; this._sbmod=false;  break;
         case "sibling-next": this.dadmode=1; this._sbmod=true; break;
         case "complex": this.dadmode=2; this._sbmod=false;  break;
         case "complex-next": this.dadmode=2; this._sbmod=true;  break;
      }    };


/**
*     @desc: switch to mode when draged item, droped in target location in same order as they was in source grid
*     @type: public
*     @param: mode - true/false to enable/disable mode
*     @topic: 0
*/
dhtmlXGridObject.prototype.enableDragOrder=function(mode){
        this._dndorder=convertStringToBoolean(mode);
};


dhtmlXGridObject.prototype._checkParent=function(row,ids){
	var z=this._h2.get[row.idd].parent;
	if (!z.parent) return;
	for (var i=0; i<ids.length; i++) 
		if (ids[i]==z.id) return true;
		
	return this._checkParent(this.rowsAr[z.id],ids);
}

/**
*     @desc: create html element for dragging
*     @type: private
*     @param: htmlObject - html node object
*     @topic: 1
*/
dhtmlXGridObject.prototype._createDragNode=function(htmlObject,e){
	  this.editStop();
	  if (window.dhtmlDragAndDrop.dragNode) return null;
      if (!this.dADTempOff) return null;
      htmlObject.parentObject=new Object();
      htmlObject.parentObject.treeNod=this;

	var text=this.callEvent("onBeforeDrag",[htmlObject.parentNode.idd,htmlObject._cellIndex, e]);
	if (!text) return null;

      var z=new Array();

          z[this.selMultiRows?z.length:0]=htmlObject.parentNode.idd;


	//remove child in case of treeGrid
	if (this.isTreeGrid()){
		for (var i=z.length-1; i>=0; i--) 
			if (this._checkParent(this.rowsAr[z[i]],z)) z.splice(i,1);
				
	}
	

	var self=this;
	if (z.length && this._dndorder)
		z.sort(function(a,b){ return (self.rowsAr[a].rowIndex>self.rowsAr[b].rowIndex?1:-1); });

     var el = this.getFirstParentOfType(_isIE?e.srcElement:e.target,"TD");
     if (el) this._dndExtra=el._cellIndex;
      this._dragged=new Array();
      for (var i=0; i<z.length; i++)
          if (this.rowsAr[z[i]]){
          this._dragged[this._dragged.length]=this.rowsAr[z[i]];
          this.rowsAr[z[i]].treeNod=this;
          }

      htmlObject.parentObject.parentNode=htmlObject.parentNode;

   var dragSpan=document.createElement('div');
   dragSpan.innerHTML=(text!==true?text:this.rowToDragElement(htmlObject.parentNode.idd));
   dragSpan.style.position="absolute";
   dragSpan.className="dragSpanDiv";
   return dragSpan;
}



/**
*   @desc:  create a drag visual marker
*   @type:  private
*/
dhtmlXGridObject.prototype._createSdrgc=function(){
    this._sdrgc=document.createElement("DIV");
    this._sdrgc.innerHTML="&nbsp;";
    this._sdrgc.className="gridDragLine";
    this.objBox.appendChild(this._sdrgc);
}











/**
*   @desc:  create a drag context object
*   @type:  private
*/
function dragContext(a,b,c,d,e,f,j,h,k,l){
    this.source=a||"grid";
    this.target=b||"grid";
    this.mode=c||"move";
    this.dropmode=d||"child";
    this.sid=e||0;
    this.tid=f;
    this.sobj=j||null;
    this.tobj=h||null;
   this.sExtra=k||null;
   this.tExtra=l||null;
    return this;
}
/**
*   @desc:  check is operation possible
*   @type:  private
*/
dragContext.prototype.valid=function(){
   if (this.sobj!=this.tobj) return true;
   if (this.sid==this.tid) return false;
   if (this.target=="treeGrid"){
      var z=this.tid
      while (z = this.tobj.getParentId(z) ){
         if (this.sid==z) return false;
         }
   }
   return true;
}
/**
*   @desc:  close context
*   @type:  private
*/
dragContext.prototype.close=function(){
    this.sobj=null;
    this.tobj=null;
}
/**
*   @desc:  return copy of context
*   @type:  private
*/
dragContext.prototype.copy=function(){
    return new dragContext(this.source,this.target,this.mode,this.dropmode,this.sid,this.tid,this.sobj,this.tobj,this.sExtra,this.tExtra);
}
/**
*   @desc:  set a lue of context attribute
*   @type:  private
*/
dragContext.prototype.set=function(a,b){
    this[a]=b;
    return this;
}
/**
*   @desc:  generate an Id for new node
*   @type:  private
*/
dragContext.prototype.uid=function(a,b){
    this.nid=this.sid;
    while (this.tobj.rowsAr[this.nid])
        this.nid=this.nid+((new Date()).valueOf());

    return this;
}
/**
*   @desc:  get data array for grid row
*   @type:  private
*/
dragContext.prototype.data=function(){
    if (this.sobj==this.tobj)
        return this.sobj._getRowArray(this.sobj.rowsAr[this.sid]);
    if (this.source=="tree")
        return this.tobj.treeToGridElement(this.sobj,this.sid,this.tid);
    else
        return this.tobj.gridToGrid(this.sid,this.sobj,this.tobj);
}
dragContext.prototype.attrs=function(){
    if (this.source=="tree")
        return {};
    else
        return this.sobj.rowsAr[this.sid]._attrs;
}
dragContext.prototype.childs=function(){
    if (this.source=="treeGrid")
		return this.sobj._h2.get[this.sid]._xml_await?this.sobj._h2.get[this.sid].has_kids:null;
	return null;
}

/**
*   @desc:  return parent id for row in context
*   @type:  private
*/
dragContext.prototype.pid=function(){
    if (!this.tid) return 0;
	if (!this.tobj._h2) return 0;
    if (this.target=="treeGrid")
        if (this.dropmode=="child")
            return this.tid;
        else{
			var z=this.tobj.rowsAr[this.tid];
			var apid=this.tobj._h2.get[z.idd].parent.id;
			if ((this.alfa)&&(this.tobj._sbmod)&&(z.nextSibling)){
				var zpid=this.tobj._h2.get[z.nextSibling.idd].parent.id;
				if (zpid==this.tid)
            		return this.tid;
				if (zpid!=apid)
            		return zpid;
			}
	        return apid;
	   }
}
/**
*   @desc:  get index of target position
*   @type:  private
*/
dragContext.prototype.ind=function(){ 
    if (this.tid==window.unknown) return this.tobj.rowsBuffer.length;
    if (this.target=="treeGrid"){
      if (this.dropmode=="child")
            this.tobj.openItem(this.tid);
      else
         this.tobj.openItem(this.tobj.getParentId(this.tid));
   }
    var ind=this.tobj.rowsBuffer._dhx_find(this.tobj.rowsAr[this.tid]);
	if ((this.alfa)&&(this.tobj._sbmod)&&(this.dropmode=="sibling")){
		var z=this.tobj.rowsAr[this.tid];
		if ((z.nextSibling)&&(this._h2.get[z.nextSibling.idd].parent.id==this.tid))
			return ind+1;
	}

    return (ind+1+((this.target=="treeGrid" && ind>=0 && this.tobj._h2.get[this.tobj.rowsBuffer[ind].idd].state=="minus")?this.tobj._getOpenLenght(this.tobj.rowsBuffer[ind].idd,0):0));
}
/**
*   @desc:  get row related image
*   @type:  private
*/
dragContext.prototype.img=function(){
    if ((this.target!="grid")&&(this.sobj._h2))
      return this.sobj.getItemImage(this.sid);
   else return null;
}

/**
*   @desc:  return list of rows in context
*   @type:  private
*/
dragContext.prototype.slist=function(){
    var res=new Array();
    for (var i=0; i<this.sid.length; i++)
        res[res.length]=this.sid[i][(this.source=="tree")?"id":"idd"];

    return res.join(",");
}


/**
*   @desc:  drag entry point
*   @type:  private
*/
dhtmlXGridObject.prototype._drag=function(sourceHtmlObject,dhtmlObject,targetHtmlObject,lastLanding){
   if (this._realfake) return this._fake._drag()	
   
   var z=(this.lastLanding)
    //close unfinished tasks
    if  (this._autoOpenTimer) window.clearTimeout(this._autoOpenTimer);

    //detect details
    var r1=targetHtmlObject.parentNode;
    var r2=sourceHtmlObject.parentObject;
    //drop on header
    if (!r1.idd) { r1.grid=this;    this.dadmodefix=0; }

    var c=new dragContext(0,0,0,((r1.grid.dadmode==1 || r1.grid.dadmodec)?"sibling":"child"));


    if (r2 && r2.childNodes)
        c.set("source","tree").set("sobj",r2.treeNod).set("sid",c.sobj._dragged);
    else{
    	if (!r2) return true;
        if (r2.treeNod.isTreeGrid && r2.treeNod.isTreeGrid())
        	c.set("source","treeGrid");
        c.set("sobj",r2.treeNod).set("sid",c.sobj._dragged);
        }

    if (r1.grid.isTreeGrid())
        c.set("target","treeGrid");
	else
		c.set("dropmode","sibling");
    c.set("tobj",r1.grid).set("tid",r1.idd);



   var el = this.getFirstParentOfType(lastLanding,"TD")
   if (el) c.set("tExtra",el._cellIndex);
   if (el) c.set("sExtra",c.sobj._dndExtra);

    if (c.sobj.dpcpy) c.set("mode","copy");
    
    if (c.tobj._realfake) c.tobj=c.tobj._fake;
    if (c.sobj._realfake) c.sobj=c.sobj._fake;
    
    c.tobj._clearMove();
    
	if (r2 && r2.treeNod && r2.treeNod._nonTrivialRow)
		r2.treeNod._nonTrivialRow(this,c.tid,c.dropmode,r2);
	else {
		c.tobj.dragContext=c;
	    if (!c.tobj.callEvent("onDrag",[c.slist(),c.tid,c.sobj,c.tobj,c.sExtra,c.tExtra]))  return  c.tobj.dragContext=null;
	
	   //all ready, start mantras
	   var result=new Array();
	   if (typeof(c.sid)=="object"){
	        var nc=c.copy();
	        for (var i=0; i<c.sid.length; i++){
	         if (!nc.set("alfa",(!i)).set("sid",c.sid[i][(c.source=="tree"?"id":"idd")]).valid()) continue;
	            nc.tobj._dragRoutine(nc);
	            if (nc.target=="treeGrid" && nc.dropmode == "child") nc.tobj.openItem(nc.tid);
	            result[result.length]=nc.nid;
	         nc.set("dropmode","sibling").set("tid",nc.nid);
	            }
	        nc.close();
	        }
	    else
	       c.tobj._dragRoutine(c);		

	   //finish math if any awaiting
	   if (c.tobj.laterLink) c.tobj.laterLink();
	   //destroy context
		c.tobj.callEvent("onDrop",[c.slist(),c.tid,result.join(","),c.sobj,c.tobj,c.sExtra,c.tExtra]);
	}

   c.tobj.dragContext=null;
   c.close();
}


/**
*   @desc:  context drag routine
*   @type:  private
*/
dhtmlXGridObject.prototype._dragRoutine=function(c){
      if ((c.sobj==c.tobj)&&(c.source=="grid")&&(c.mode=="move")&&!this._fake){
         //special case for moving rows in same grid
         if (c.sobj._dndProblematic) return;
         var fr=c.sobj.rowsAr[c.sid];
         var bind=c.sobj.rowsCol._dhx_find(fr);
         c.sobj.rowsCol._dhx_removeAt(c.sobj.rowsCol._dhx_find(fr));
         c.sobj.rowsBuffer._dhx_removeAt(c.sobj.rowsBuffer._dhx_find(fr));
         c.sobj.rowsBuffer._dhx_insertAt(c.ind(),fr);
         if (c.tobj._fake){
         	c.tobj._fake.rowsCol._dhx_removeAt(bind);
         	var tr=c.tobj._fake.rowsAr[c.sid];
         	tr.parentNode.removeChild(tr);
     	 }         
         c.sobj._insertRowAt(fr,c.ind());

         c.nid=c.sid;
         c.sobj.callEvent("onGridReconstructed",[]);
         return;
      }
      var new_row;
		if (this._h2 && typeof c.tid !="undefined" && c.dropmode=="sibling" && (this._sbmod || c.tid)){
			if (c.alfa && this._sbmod && this._h2.get[c.tid].childs.length){
				this.openItem(c.tid)
				new_row=c.uid().tobj.addRowBefore(c.nid,c.data(),this._h2.get[c.tid].childs[0].id,c.img(),c.childs());
			}
			else
			new_row=c.uid().tobj.addRowAfter(c.nid,c.data(),c.tid,c.img(),c.childs());
			}
		else
        	new_row=c.uid().tobj.addRow(c.nid,c.data(),c.ind(),c.pid(),c.img(),c.childs());

          new_row._attrs = c.attrs();
		
		
        if (c.source=="tree"){
        	this.callEvent("onRowAdded",[c.nid]);            
            var sn=c.sobj._globalIdStorageFind(c.sid);
            if (sn.childsCount){
                var nc=c.copy().set("tid",c.nid).set("dropmode",c.target=="grid"?"sibling":"child");
              for(var j=0;j<sn.childsCount;j++){
                    c.tobj._dragRoutine(nc.set("sid",sn.childNodes[j].id));
                    if (c.mode=="move") j--;
                    }
                nc.close();
                }
        }
        else{
            c.tobj._copyUserData(c);
			this.callEvent("onRowAdded",[c.nid]);            
			
            if ((c.source=="treeGrid")){
            	
            	if (c.sobj==c.tobj) new_row._xml=c.sobj.rowsAr[c.sid]._xml;
                var snc=c.sobj._h2.get[c.sid];
                if ((snc)&&(snc.childs.length)){
                    var nc=c.copy().set("tid",c.nid);
                    if(c.target=="grid")
                        nc.set("dropmode","sibling");
                    else {
                    	nc.tobj.openItem(c.tid);
                        nc.set("dropmode","child");
                        }
					var l=snc.childs.length;
                    for(var j=0;j<l;j++){
                    	c.sobj.render_row_tree(null,snc.childs[j].id);
                        c.tobj._dragRoutine(nc.set("sid",snc.childs[j].id));
                        if (l!=snc.childs.length) {  j--; l=snc.childs.length; }
                        }
                    nc.close();
                    }
            }
        }

        if (c.mode=="move"){
           c.sobj[(c.source=="tree")?"deleteItem":"deleteRow"](c.sid);
           if ((c.sobj==c.tobj)&&(!c.tobj.rowsAr[c.sid])) {
               c.tobj.changeRowId(c.nid,c.sid);
            c.nid=c.sid;
         }
      }
}


/**
*   @desc: redefine this method in your code to define how grid row values should be used in another grid
*   @param: rowId - id of draged row
*   @param: sgrid - source grid object
*   @param: tgrid - target grid object
*   @returns: array of values for cells in target grid row
*   @type: public
*   @topic: 7
*/
dhtmlXGridObject.prototype.gridToGrid = function(rowId,sgrid,tgrid){
    var z=new Array();
    for (var i=0; i<sgrid.hdr.rows[0].cells.length; i++)
        z[i]=sgrid.cells(rowId,i).getValue();
   return z;
}

/**
*   @desc:  check if d-n-d is in allowed rules
*   @type:  private
*/
dhtmlXGridObject.prototype.checkParentLine=function(node,id){
    if ((!this._h2)||(!id)||(!node)) return false;
    if (node.id==id) return true;
    else return this.checkParentLine(node.parent,id);
}

/**
*   @desc:  called when drag moved over landing
*   @type:  private
*/
dhtmlXGridObject.prototype._dragIn=function(htmlObject,shtmlObject,x,y){
                    if (!this.dADTempOff) return 0;
                    var tree=this.isTreeGrid();
                    var obj=shtmlObject.parentNode.idd?shtmlObject.parentNode:shtmlObject.parentObject;
                    
					if (this._drag_validate){
                    	if(htmlObject.parentNode==shtmlObject.parentNode)
                        	return 0;
                        	
	                    if ((tree)&&(this==obj.grid)&&((this.checkParentLine(this._h2.get[htmlObject.parentNode.idd],shtmlObject.parentNode.idd))))
    	                    return 0;
    	            }
                    if (!this.callEvent("onDragIn",[obj.idd||obj.id,htmlObject.parentNode.idd,obj.grid||obj.treeNod,(htmlObject.grid||htmlObject.parentNode.grid)]))
                        return this._setMove(htmlObject,x,y,true);

                    this._setMove(htmlObject,x,y);

                  if ((tree)&&(htmlObject.parentNode.expand!="")){
                     this._autoOpenTimer=window.setTimeout(new callerFunction(this._autoOpenItem,this),1000);
                   this._autoOpenId=htmlObject.parentNode.idd;
                        }
                  else
                    if  (this._autoOpenTimer) window.clearTimeout(this._autoOpenTimer);

                    return htmlObject;
}
/**
*   @desc:  open item on timeout
*   @type:  private
*/
dhtmlXGridObject.prototype._autoOpenItem=function(e,gridObject){
	   gridObject.openItem(gridObject._autoOpenId);
}

/**
*   @desc:  called on onmouseout event , when drag out landing zone
*   @type:  private
*/
dhtmlXGridObject.prototype._dragOut=function(htmlObject){
                    this._clearMove();
                    var obj=htmlObject.parentNode.parentObject?htmlObject.parentObject.id:htmlObject.parentNode.idd;
                    this.callEvent("onDragOut",[obj]);
                    if  (this._autoOpenTimer) window.clearTimeout(this._autoOpenTimer);
}
/**
*   @desc:  set visual effect for moving row over landing
*   @type:  private
*/
dhtmlXGridObject.prototype._setMove=function(htmlObject,x,y,skip){
   if (!htmlObject.parentNode.idd) return;
   var a1=getAbsoluteTop(htmlObject);
   var a2=getAbsoluteTop(this.objBox);
   

   //scroll down
   if ( (a1-a2)>(parseInt(this.objBox.offsetHeight)-50) )
      this.objBox.scrollTop=parseInt(this.objBox.scrollTop)+20;
   //scroll top
   if ( (a1-a2+parseInt(this.objBox.scrollTop))<(parseInt(this.objBox.scrollTop)+30) )
      this.objBox.scrollTop=parseInt(this.objBox.scrollTop)-20;
      
   if (skip) return 0;
   
    if (this.dadmode==2)
    {

        var z=y-a1+(document.body.scrollTop||document.documentElement.scrollTop)-2-htmlObject.offsetHeight/2;
        if ((Math.abs(z)-htmlObject.offsetHeight/6)>0)
        {
        this.dadmodec=1;
      //sibbling zone
        if (z<0)  this.dadmodefix=-1; else   this.dadmodefix=1;
        }
        else this.dadmodec=0;
    }
    else
        this.dadmodec=this.dadmode;




    if (this.dadmodec){
      if (!this._sdrgc) this._createSdrgc();
      this._sdrgc.style.display="block";
      this._sdrgc.style.top=a1-a2+parseInt(this.objBox.scrollTop)+((this.dadmodefix>=0)?htmlObject.offsetHeight:0)+"px";
    }
    else{
      this._llSelD=htmlObject;
      if (htmlObject.parentNode.tagName=="TR")
      for (var i=0; i<htmlObject.parentNode.childNodes.length; i++)
      {
      var z= htmlObject.parentNode.childNodes[i];
	  z._bgCol=z.style.backgroundColor;
      z.style.backgroundColor="#FFCCCC";
      }
    }
}
/**
*   @desc:  remove all visual effects
*   @type:  private
*/
dhtmlXGridObject.prototype._clearMove=function(){
    if (this._sdrgc) this._sdrgc.style.display="none";
    if ((this._llSelD)&&(this._llSelD.parentNode.tagName=="TR")){
    	var coll = this._llSelD.parentNode.childNodes;
        for (var i=0; i<coll.length; i++)
           coll[i].style.backgroundColor=coll[i]._bgCol;
	}       

    this._llSelD=null;
}


/**
*   @desc: redefine this method in your code to define how grid row values should be displaied while draging
*   @param: gridRowId - id of grid row
*   @returns: html string representing dragging row 
*   @type: public
*   @topic: 7
*/
dhtmlXGridObject.prototype.rowToDragElement=function(gridRowId){
    var out=this.cells(gridRowId,0).getValue();
    return out;
}








/**
*   @desc:  copy user data for row
*   @type:  private
*/
dhtmlXGridObject.prototype._copyUserData = function(c){
			if(!c.tobj.UserData[c.nid] || c.tobj!=c.sobj)
            	c.tobj.UserData[c.nid] = new Hashtable();
            else return;

            var z1 = c.sobj.UserData[c.sid];
            var z2 = c.tobj.UserData[c.nid];
            if (z1) {
                z2.keys = z2.keys.concat(z1.keys);
                z2.values = z2.values.concat(z1.values);
            }
    }



/**
*     @desc: move row
*     @type:  public
*     @param: rowId - source row Id
*     @param: mode - moving mode (up,down,row_sibling)
*     @param: targetId - target row  in row_sibling mode
*     @param: targetGrid - used for moving between grids (optional)
*     @edition: Professional
*     @topic: 2
*/
dhtmlXGridObject.prototype.moveRow=function(rowId,mode,targetId,targetGrid){
      switch(mode){
      case "row_sibling":
                    this.moveRowTo(rowId,targetId,"move","sibling",this,targetGrid);
         break;
      case "up":
               this.moveRowUp(rowId);
         break;
      case "down":
               this.moveRowDown(rowId);
          break;
      }
}






//(c)dhtmlx ltd. www.dhtmlx.com
