//v.3.6 build 131108

/*
Copyright DHTMLX LTD. http://www.dhtmlx.com
You allowed to use this component or parts of it under GPL terms
To use it on other terms or get Professional edition of the component please contact us at sales@dhtmlx.com
*/
function dhtmlXGridFromTable(obj,init){
      if(typeof(obj)!='object')
         obj = document.getElementById(obj);
            var w=document.createElement("DIV");
            w.setAttribute("width",obj.getAttribute("gridWidth")||(obj.offsetWidth?(obj.offsetWidth+"px"):0)||(window.getComputedStyle?window.getComputedStyle(obj,null)["width"]:(obj.currentStyle?obj.currentStyle["width"]:0)));
            w.setAttribute("height",obj.getAttribute("gridHeight")||(obj.offsetHeight?(obj.offsetHeight+"px"):0)||(window.getComputedStyle?window.getComputedStyle(obj,null)["height"]:(obj.currentStyle?obj.currentStyle["height"]:0)));
			w.className = obj.className;
			obj.className="";
			if (obj.id) w.id = obj.id;

            var mr=obj;
            var drag=obj.getAttribute("dragAndDrop");
            mr.parentNode.insertBefore(w,mr);
            var f=mr.getAttribute("name")||("name_"+(new Date()).valueOf());

            var windowf=new dhtmlXGridObject(w);
            window[f]=windowf;

            var acs=mr.getAttribute("onbeforeinit");
            var acs2=mr.getAttribute("oninit");

			if (acs) eval(acs);

        	windowf.setImagePath(windowf.imgURL||(mr.getAttribute("imgpath")|| mr.getAttribute("image_path") ||""));
			var skin = mr.getAttribute("skin");
			if (skin) windowf.setSkin(skin);

        	if (init) init(windowf);

            var hrow=mr.rows[0];
            var za="";
            var zb="";
            var zc="";
            var zd="";
            var ze="";

            for (var i=0; i<hrow.cells.length; i++){
                za+=(za?",":"")+hrow.cells[i].innerHTML;
                var width=hrow.cells[i].getAttribute("width")||hrow.cells[i].offsetWidth||(window.getComputedStyle?window.getComputedStyle(hrow.cells[i],null)["width"]:(hrow.cells[i].currentStyle?hrow.cells[i].currentStyle["width"]:0));
                zb+=(zb?",":"")+(width=="*"?width:parseInt(width));
                zc+=(zc?",":"")+(hrow.cells[i].getAttribute("align")||"left");
                zd+=(zd?",":"")+(hrow.cells[i].getAttribute("type")||"ed");
                ze+=(ze?",":"")+(hrow.cells[i].getAttribute("sort")||"str");
            	var f_a=hrow.cells[i].getAttribute("format");
            	if (f_a)
            		if(hrow.cells[i].getAttribute("type").toLowerCase().indexOf("calendar")!=-1) 
            			windowf._dtmask=f_a;
            		else
            			windowf.setNumberFormat(f_a,i);
            }

        	windowf.setHeader(za);
        	windowf.setInitWidths(zb)
        	windowf.setColAlign(zc)
        	windowf.setColTypes(zd);
        	windowf.setColSorting(ze);
			if (obj.getAttribute("gridHeight")=="auto")
		    	windowf.enableAutoHeigth(true);

			if (obj.getAttribute("multiline")) windowf.enableMultiline(true);

			var lmn=mr.getAttribute("lightnavigation");
			if (lmn) windowf.enableLightMouseNavigation(lmn);

			var evr=mr.getAttribute("evenrow");
			var uevr=mr.getAttribute("unevenrow");

			if (evr||uevr) windowf.enableAlterCss(evr,uevr);
			if (drag) windowf.enableDragAndDrop(true);

            windowf.init();
            if (obj.getAttribute("split")) windowf.splitAt(obj.getAttribute("split"));

            //adding rows
            windowf._process_inner_html(mr,1);
            
			if (acs2) eval(acs2);            
			if (obj.parentNode && obj.parentNode.removeChild)
				obj.parentNode.removeChild(obj);
     return windowf;

            }
dhtmlXGridObject.prototype._process_html=function(xml){
	if (xml.tagName && xml.tagName == "TABLE") return this._process_inner_html(xml,0);
	var temp=document.createElement("DIV");
	temp.innerHTML=xml.xmlDoc.responseText;
	var mr = temp.getElementsByTagName("TABLE")[0];
	this._process_inner_html(mr,0);
}
dhtmlXGridObject.prototype._process_inner_html=function(mr,start){
	var n_l=mr.rows.length;
	for (var j=start; j<n_l; j++){
		var id=mr.rows[j].getAttribute("id")||j;
		this.rowsBuffer.push({ idd:id, data:mr.rows[j], _parser: this._process_html_row, _locator:this._get_html_data });
	}
	this.render_dataset();
	this.setSizes();
}
   
dhtmlXGridObject.prototype._process_html_row=function(r,xml){
	var cellsCol = xml.getElementsByTagName('TD');
    var strAr = [];
    
	r._attrs=this._xml_attrs(xml);
	
	//load cell data
    for(var j=0;j<cellsCol.length;j++){
    	var cellVal=cellsCol[j];
        var exc=cellVal.getAttribute("type");
        if (r.childNodes[j]){
        	if (exc)
        		r.childNodes[j]._cellType=exc;
       		r.childNodes[j]._attrs=this._xml_attrs(cellsCol[j]);
   		}
       
		if (cellVal.firstChild)
		    strAr.push(cellVal.innerHTML);
		else strAr.push("");
        
        if (cellVal.colSpan>1){
            r.childNodes[j]._attrs["colspan"]=cellVal.colSpan;		
            for (var k=1; k<cellVal.colSpan; k++){
                strAr.push("")
            }
        }
		
}
	for(j<cellsCol.length; j<r.childNodes.length; j++)
        r.childNodes[j]._attrs={};

        
    //back to common code
	this._fillRow(r,(this._c_order?this._swapColumns(strAr):strAr));
    return r;
}
dhtmlXGridObject.prototype._get_html_data=function(data,ind){
	data=data.firstChild;
	while (true){
		if (!data) return "";
		if (data.tagName=="TD") ind--;
		if (ind<0) break;
		data=data.nextSibling;
	}
  return (data.firstChild?data.firstChild.data:"");
}



dhtmlxEvent(window,"load",function(){
    var z=document.getElementsByTagName("table");
    for (var a=0; a<z.length; a++)
        if (z[a].className=="dhtmlxGrid"){
            dhtmlXGridFromTable(z[a]);
            //we have found IT!
        }
});


//(c)dhtmlx ltd. www.dhtmlx.com
