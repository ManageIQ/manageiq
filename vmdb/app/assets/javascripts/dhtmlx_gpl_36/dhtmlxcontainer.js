//v.3.6 build 131108

/*
Copyright DHTMLX LTD. http://www.dhtmlx.com
You allowed to use this component or parts of it under GPL terms
To use it on other terms or get Professional edition of the component please contact us at sales@dhtmlx.com
*/
function dhtmlXContainer(obj) {
	
	var that = this;
	
	this.obj = obj;
	obj = null;
	
	this.obj._padding = true;
	
	this.dhxcont = null;
	
	this.st = document.createElement("DIV");
	this.st.style.position = "absolute";
	this.st.style.left = "-200px";
	this.st.style.top = "0px";
	this.st.style.width = "100px";
	this.st.style.height = "1px";
	this.st.style.visibility = "hidden";
	this.st.style.overflow = "hidden";
	document.body.insertBefore(this.st, document.body.childNodes[0]);
	
	this.obj._getSt = function() {
		// return this.st object, needed for content moving
		return that.st;
	}
	
	this.obj.dv = "def"; // default
	this.obj.av = this.obj.dv; // active for usage
	this.obj.cv = this.obj.av; // current opened
	this.obj.vs = {}; // all
	this.obj.vs[this.obj.av] = {};
	
	this.obj.view = function(name) {
		
		if (!this.vs[name]) {
			
			this.vs[name] = {};
			this.vs[name].dhxcont = this.vs[this.dv].dhxcont;
			
			var mainCont = document.createElement("DIV");
			mainCont.style.position = "relative";
			mainCont.style.left = "0px";
			mainCont.style.width = "200px";
			mainCont.style.height = "200px";
			mainCont.style.overflow = "hidden";
			mainCont.style.visibility = "";
			that.st.appendChild(mainCont);
			
			this.vs[name].dhxcont.mainCont[name] = mainCont;
			mainCont = null;
			
		}
		
		this.avt = this.av;
		this.av = name;
		
		return this;
		
	}
	
	this.obj.setActive = function() {
		
		if (!this.vs[this.av]) return;
		
		this.cv = this.av;
		
		// detach current content
		
		if (this.vs[this.avt].dhxcont == this.vs[this.avt].dhxcont.mainCont[this.avt].parentNode) {
			
			that.st.appendChild(this.vs[this.avt].dhxcont.mainCont[this.avt]);
			
			if (this.vs[this.avt].menu) that.st.appendChild(document.getElementById(this.vs[this.avt].menuId));
			if (this.vs[this.avt].toolbar) {
				that.st.appendChild(document.getElementById(this.vs[this.avt].toolbarId));
				var tb = this.vs[this.avt].toolbar;
				tb.forEachItem(function(id){
					var obj = tb.objPull[tb.idPrefix+id].obj;
					if (obj != null && typeof(obj._doOnMouseOut) == "function") obj._doOnMouseOut();
					obj = null;
				});
				tb = null;
			}
			if (this.vs[this.avt].sb) that.st.appendChild(document.getElementById(this.vs[this.avt].sbId));
			
		}
		
		// adjust content
		if (this._isCell) {
			//this.adjustContent(this.childNodes[0], (this._noHeader?0:this.skinParams[this.skin]["cpanel_height"]));
		}
		//this.vs[this.av].dhxcont.mainCont[this.av].style.width = this.vs[this.av].dhxcont.mainCont[this.avt].style.width;
		//this.vs[this.av].dhxcont.mainCont[this.av].style.height = this.vs[this.av].dhxcont.mainCont[this.avt].style.height;
		
		if (this.vs[this.av].dhxcont != this.vs[this.av].dhxcont.mainCont[this.av].parentNode) {
			
			this.vs[this.av].dhxcont.insertBefore(this.vs[this.av].dhxcont.mainCont[this.av],this.vs[this.av].dhxcont.childNodes[this.vs[this.av].dhxcont.childNodes.length-1]);
			
			if (this.vs[this.av].menu) this.vs[this.av].dhxcont.insertBefore(document.getElementById(this.vs[this.av].menuId), this.vs[this.av].dhxcont.childNodes[0]);
			if (this.vs[this.av].toolbar) this.vs[this.av].dhxcont.insertBefore(document.getElementById(this.vs[this.av].toolbarId), this.vs[this.av].dhxcont.childNodes[(this.vs[this.av].menu?1:0)]);
			if (this.vs[this.av].sb) this.vs[this.av].dhxcont.insertBefore(document.getElementById(this.vs[this.av].sbId), this.vs[this.av].dhxcont.childNodes[this.vs[this.av].dhxcont.childNodes.length-1]);
			
		}

		if (this._doOnResize) this._doOnResize();
		
		if (this._isWindow) this.updateNestedObjects();
		
		this.avt = null;
	}
	
	this.obj._viewRestore = function() {
		var t = this.av;
		if (this.avt) { this.av = this.avt; this.avt = null; }
		return t;
	}
	
	this.setContent = function(data) {
		/*
		this.dhxcont = data;
		this.dhxcont.innerHTML = "<div style='position: relative; left: 0px; top: 0px; overflow: hidden;'></div>"+
					 "<div class='dhxcont_content_blocker' style='display: none;'></div>";
		this.dhxcont.mainCont = this.dhxcont.childNodes[0];
		this.obj.vs[this.obj.av].dhxcont = this.dhxcont;
		*/
		
		this.obj.vs[this.obj.av].dhxcont = data;
		this.obj._init();
		data = null;
	}
	
	this.obj._init = function() {
		
		this.vs[this.av].dhxcont.innerHTML = "<div ida='dhxMainCont' style='position: relative; left: 0px; top: 0px; overflow: hidden;'></div>"+
							"<div class='dhxcont_content_blocker' style='display: none;'></div>";
		
		this.vs[this.av].dhxcont.mainCont = {};
		this.vs[this.av].dhxcont.mainCont[this.av] = this.vs[this.av].dhxcont.childNodes[0];
		
	}
	
	this.obj._genStr = function(w) {
		var s = ""; var z = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
		for (var q=0; q<w; q++) s += z.charAt(Math.round(Math.random() * (z.length-1)));
		return s;
	}
	
	this.obj.setMinContentSize = function(w, h) {
		this.vs[this.av]._minDataSizeW = w;
		this.vs[this.av]._minDataSizeH = h;
	}
	
	this.obj._setPadding = function(p, altCss) {
		
		if (typeof(p) == "object") {
			this._offsetTop = p[0];
			this._offsetLeft = p[1];
			this._offsetWidth = p[2];
			this._offsetHeight = p[3];
			p = null;
		} else {
			this._offsetTop = p;
			this._offsetLeft = p;
			this._offsetWidth = -p*2;
			this._offsetHeight = -p*2;
		}
		this.vs[this.av].dhxcont.className = "dhxcont_global_content_area "+(altCss||"");
		
	}
	
	this.obj.moveContentTo = function(cont) {
		
		
		// move dhtmlx components
		
		for (var a in this.vs) {
			
			cont.view(a).setActive();
			
			var pref = null;
			if (this.vs[a].grid) pref = "grid";
			if (this.vs[a].tree) pref = "tree";
			if (this.vs[a].tabbar) pref = "tabbar";
			if (this.vs[a].folders) pref = "folders";
			if (this.vs[a].layout) pref = "layout";
			
			if (pref != null) {
				
				
				cont.view(a).attachObject(this.vs[a][pref+"Id"], false, true, false);
				cont.vs[a][pref] = this.vs[a][pref];
				cont.vs[a][pref+"Id"] = this.vs[a][pref+"Id"];
				cont.vs[a][pref+"Obj"] = this.vs[a][pref+"Obj"];
				
				this.vs[a][pref] = null;
				this.vs[a][pref+"Id"] = null;
				this.vs[a][pref+"Obj"] = null;
				
			}
			
			if (this.vs[a]._frame) {
				cont.vs[a]._frame = this.vs[a]._frame;
				this.vs[a]._frame = null;
			}
			
			if (this.vs[a].menu != null) {
				
				if (cont.cv == cont.av) {
					cont.vs[cont.av].dhxcont.insertBefore(document.getElementById(this.vs[a].menuId), cont.vs[cont.av].dhxcont.childNodes[0]);
				} else {
					var st = cont._getSt();
					st.appendChild(document.getElementById(this.vs[a].menuId));
					st = null;
				}
				cont.vs[a].menu = this.vs[a].menu;
				cont.vs[a].menuId = this.vs[a].menuId;
				cont.vs[a].menuHeight = this.vs[a].menuHeight;
				this.vs[a].menu = null;
				this.vs[a].menuId = null;
				this.vs[a].menuHeight = null;
				
				if (this.cv == this.av && this._doOnAttachMenu) this._doOnAttachMenu("unload");
				if (cont.cv == cont.av && cont._doOnAttachMenu) cont._doOnAttachMenu("move");
				
			}
				
			if (this.vs[a].toolbar != null) {
				
				if (cont.cv == cont.av) {
					cont.vs[cont.av].dhxcont.insertBefore(document.getElementById(this.vs[a].toolbarId), cont.vs[cont.av].dhxcont.childNodes[(cont.vs[cont.av].menu!=null?1:0)]);
				} else {
					var st = cont._getSt();
					st.appendChild(document.getElementById(this.vs[a].toolbarId));
					st = null;
				}
				
				cont.vs[a].toolbar = this.vs[a].toolbar;
				cont.vs[a].toolbarId = this.vs[a].toolbarId;
				cont.vs[a].toolbarHeight = this.vs[a].toolbarHeight;
				this.vs[a].toolbar = null;
				this.vs[a].toolbarId = null;
				this.vs[a].toolbarHeight = null;
				
				if (this.cv == this.av && this._doOnAttachToolbar) this._doOnAttachToolbar("unload");
				if (cont.cv == cont.av && cont._doOnAttachToolbar) cont._doOnAttachToolbar("move");
			}
			
			if (this.vs[a].sb != null) {
				
				if (cont.cv == cont.av) {
					cont.vs[cont.av].dhxcont.insertBefore(document.getElementById(this.vs[a].sbId), cont.vs[cont.av].dhxcont.childNodes[cont.vs[cont.av].dhxcont.childNodes.length-1]);
				} else {
					var st = cont._getSt();
					st.appendChild(document.getElementById(this.vs[a].sbId));
					return st;
				}
				
				cont.vs[a].sb = this.vs[a].sb;
				cont.vs[a].sbId = this.vs[a].sbId;
				cont.vs[a].sbHeight = this.vs[a].sbHeight;
				this.vs[a].sb = null;
				this.vs[a].sbId = null;
				this.vs[a].sbHeight = null;
				if (this.cv == this.av && this._doOnAttachStatusBar) this._doOnAttachStatusBar("unload");
				if (cont.cv == cont.av && cont._doOnAttachStatusBar) cont._doOnAttachStatusBar("move");
			}
			
			
			var objA = this.vs[a].dhxcont.mainCont[a];
			var objB = cont.vs[a].dhxcont.mainCont[a];
			while (objA.childNodes.length > 0) objB.appendChild(objA.childNodes[0]);
		
			//this.vs[a] = null;
			
			
		}
		
		cont.view(this.av).setActive();
		
		cont = null;
		
	}
	
	this.obj.adjustContent = function(parentObj, offsetTop, marginTop, notCalcWidth, offsetBottom) {
		
		var dhxcont = this.vs[this.av].dhxcont;
		var mainCont = dhxcont.mainCont[this.av];
		
		dhxcont.style.left = (this._offsetLeft||0)+"px";
		dhxcont.style.top = (this._offsetTop||0)+offsetTop+"px";
		//
		var cw = parentObj.clientWidth+(this._offsetWidth||0);
		if (notCalcWidth !== true) dhxcont.style.width = Math.max(0, cw)+"px";
		if (notCalcWidth !== true) if (dhxcont.offsetWidth > cw) dhxcont.style.width = Math.max(0, cw*2-dhxcont.offsetWidth)+"px";
		//
		var ch = parentObj.clientHeight+(this._offsetHeight||0);
		dhxcont.style.height = Math.max(0, ch-offsetTop)+(marginTop!=null?marginTop:0)+"px";
		if (dhxcont.offsetHeight > ch - offsetTop) dhxcont.style.height = Math.max(0, (ch-offsetTop)*2-dhxcont.offsetHeight)+"px";
		if (offsetBottom) if (!isNaN(offsetBottom)) dhxcont.style.height = Math.max(0, parseInt(dhxcont.style.height)-offsetBottom)+"px";
		
		// main window content
		if (this.vs[this.av]._minDataSizeH != null) {
			// height for menu/toolbar/status bar should be included
			if (parseInt(dhxcont.style.height) < this.vs[this.av]._minDataSizeH) dhxcont.style.height = this.vs[this.av]._minDataSizeH+"px";
		}
		if (this.vs[this.av]._minDataSizeW != null) {
			if (parseInt(dhxcont.style.width) < this.vs[this.av]._minDataSizeW) dhxcont.style.width = this.vs[this.av]._minDataSizeW+"px";
		}
		
		if (notCalcWidth !== true) {
			mainCont.style.width = dhxcont.clientWidth+"px";
			// allow border to this.dhxcont.mainCont
			if (mainCont.offsetWidth > dhxcont.clientWidth) mainCont.style.width = Math.max(0, dhxcont.clientWidth*2-mainCont.offsetWidth)+"px";
		}
		
		var menuOffset = (this.vs[this.av].menu!=null?(!this.vs[this.av].menuHidden?this.vs[this.av].menuHeight:0):0);
		var toolbarOffset = (this.vs[this.av].toolbar!=null?(!this.vs[this.av].toolbarHidden?this.vs[this.av].toolbarHeight:0):0);
		var statusOffset = (this.vs[this.av].sb!=null?(!this.vs[this.av].sbHidden?this.vs[this.av].sbHeight:0):0);
		
		// allow border to this.dhxcont.mainCont
		mainCont.style.height = dhxcont.clientHeight+"px";
		if (mainCont.offsetHeight > dhxcont.clientHeight) mainCont.style.height = Math.max(0, dhxcont.clientHeight*2-mainCont.offsetHeight)+"px";
		mainCont.style.height = Math.max(0, parseInt(mainCont.style.height)-menuOffset-toolbarOffset-statusOffset)+"px";
		
		mainCont = null;
		dhxcont = null;
		parentObj = null;
		
	}
	this.obj.coverBlocker = function() {
		return this.vs[this.av].dhxcont.childNodes[this.vs[this.av].dhxcont.childNodes.length-1];
	}
	this.obj.showCoverBlocker = function() {
		var t = this.coverBlocker();
		t.style.display = "";
		t = null;
	}
	this.obj.hideCoverBlocker = function() {
		var t = this.coverBlocker();
		t.style.display = "none";
		t = null;
	}
	this.obj.updateNestedObjects = function(fromInit) {

		if (this.skin == "dhx_terrace") {
			
			var mtAttached = (this.vs[this.av].menu != null || this.vs[this.av].toolbar != null);
			
			if (this.vs[this.av].grid) {
				
				var gTop = (mtAttached||this._isWindow?14:0);
				var gBottom = (this._isWindow?14:0); // padding in window only
				var gLeft = (this._isWindow?14:0); // padding in window only
				
				if (fromInit) {
					// init conf
					if (!this._isWindow) {
						this.vs[this.av].grid.entBox.style.border = "0px solid white";
						this.vs[this.av].grid.skin_h_correction = -2;
					}
					
					this.vs[this.av].grid.dontSetSizes = true;
					//
					this.vs[this.av].gridObj.style.position = "absolute";
					
				}
				
				this.vs[this.av].gridObj.style.top = gTop+"px";
				this.vs[this.av].gridObj.style.height = parseInt(this.vs[this.av].dhxcont.mainCont[this.av].style.height)-gTop-gBottom+"px";
				
				this.vs[this.av].gridObj.style.left = gLeft+"px";
				this.vs[this.av].gridObj.style.width = parseInt(this.vs[this.av].dhxcont.mainCont[this.av].style.width)-(gLeft*2)+"px";
				
				this.vs[this.av].grid.setSizes();
			}
			
			if (this.vs[this.av].tree) {
				
				var gTop = (mtAttached||this._isWindow?14:0);
				var gBottom = (this._isWindow?14:0); // padding in window only
				var gLeft = (this._isWindow?14:0); // padding in window only
				
				if (fromInit) {
					this.vs[this.av].treeObj.style.position = "absolute";
				}
				
				this.vs[this.av].treeObj.style.top = gTop+"px";
				this.vs[this.av].treeObj.style.height = parseInt(this.vs[this.av].dhxcont.mainCont[this.av].style.height)-gTop-gBottom+"px";
				
				this.vs[this.av].treeObj.style.left = gLeft+"px";
				this.vs[this.av].treeObj.style.width = parseInt(this.vs[this.av].dhxcont.mainCont[this.av].style.width)-(gLeft*2)+"px";
				
			}
			
			if (this.vs[this.av].form) {
				
				var gTop = (mtAttached||this._isWindow?14:0);
				var gBottom = (this._isWindow?14:0); // padding in window only
				var gLeft = (this._isWindow?14:0); // padding in window only
				
				if (fromInit) {
					this.vs[this.av].formObj.style.position = "absolute";
				}
				
				this.vs[this.av].formObj.style.top = gTop+"px";
				this.vs[this.av].formObj.style.height = parseInt(this.vs[this.av].dhxcont.mainCont[this.av].style.height)-gTop-gBottom+"px";
				
				this.vs[this.av].formObj.style.left = gLeft+"px";
				this.vs[this.av].formObj.style.width = parseInt(this.vs[this.av].dhxcont.mainCont[this.av].style.width)-(gLeft*2)+"px";
				
				this.vs[this.av].form.setSizes();
				
			}
			
			if (this.vs[this.av].layout) {
				
				if (fromInit) {
					// hide cells' borders
					if (!this._isWindow && !this._isCell) this.vs[this.av].layout._hideBorders();
				}
				
				/*
				var gTop = 14; // always
				var gLeft = 14; // always
				*/
				var gTop = (this._isCell&&this._noHeader&&!mtAttached?0:14); // if layout's cell w/o hdr and w/o mt - 0, otherwise always
				var gBottom = (this._isCell&&this._noHeader?0:14)
				var gLeft = (this._isCell&&this._noHeader?0:14); 
				
				
				this.vs[this.av].layoutObj.style.top = gTop+"px";
				this.vs[this.av].layoutObj.style.height = parseInt(this.vs[this.av].dhxcont.mainCont[this.av].style.height)-gTop-gBottom+"px";
				
				this.vs[this.av].layoutObj.style.left = gLeft+"px";
				this.vs[this.av].layoutObj.style.width = parseInt(this.vs[this.av].dhxcont.mainCont[this.av].style.width)-(gLeft*2)+"px";
				
				this.vs[this.av].layout.setSizes();
			}
			
			if (this.vs[this.av].accordion) {
				
				if (fromInit) {
					// hide cells' borders
					this.vs[this.av].accordion._hideBorders = true;
				}
				
				var gTop = (this._isCell&&this._noHeader&&!mtAttached?0:14); // if layout's cell w/o hdr and w/o mt - 0, otherwise always
				var gBottom = (this._isCell&&this._noHeader?0:14)
				var gLeft = (this._isCell&&this._noHeader?0:14); 
				
				this.vs[this.av].accordionObj.style.top = gTop+"px";
				this.vs[this.av].accordionObj.style.height = parseInt(this.vs[this.av].dhxcont.mainCont[this.av].style.height)-gTop-gBottom+"px";
				
				this.vs[this.av].accordionObj.style.left = gLeft+"px";
				this.vs[this.av].accordionObj.style.width = parseInt(this.vs[this.av].dhxcont.mainCont[this.av].style.width)-(gLeft*2)+"px";
				
				this.vs[this.av].accordion.setSizes();
			}
			
			
			if (this.vs[this.av].tabbar != null) {
				
				var gTop = (!mtAttached && this._isCell && this._noHeader ? 0:14); // set to 0 only if no menu/toolbar and in layout w/o hdr
				var gBottom = (this._isCell && this._noHeader ? gTop : 28);
				var gLeft = (this._isCell && this._noHeader ? 0 : 14); // set to 0 only if in layout w/o hdr
				
				this.vs[this.av].tabbarObj.style.top = gTop+"px";
				this.vs[this.av].tabbarObj.style.height = parseInt(this.vs[this.av].dhxcont.mainCont[this.av].style.height)-gBottom+"px";
				
				this.vs[this.av].tabbarObj.style.left = gLeft+"px";
				this.vs[this.av].tabbarObj.style.width = parseInt(this.vs[this.av].dhxcont.mainCont[this.av].style.width)-(gLeft*2)+"px";
				
				this.vs[this.av].tabbar.adjustOuterSize();
			}
			
			if (this.vs[this.av].editor) {
				
				if (fromInit) {
					// hide cells' borders
					//if (this._isWindow) this.vs[this.av].editorObj.style.border = "1px solid #cecece";
					
					if (this.vs[this.av].editor.tb != null && this.vs[this.av].editor.tb instanceof dhtmlXToolbarObject) {
						//this.vs[this.av].editor.tb.cont.style.margin = "0px";
						
					}
					
				}
				
				var gTop = 14; // always
				var gLeft = 14; // always
				
				this.vs[this.av].editorObj.style.top = gTop+"px";
				this.vs[this.av].editorObj.style.height = parseInt(this.vs[this.av].dhxcont.mainCont[this.av].style.height)-(gTop*2)+"px";
				
				this.vs[this.av].editorObj.style.left = gLeft+"px";
				this.vs[this.av].editorObj.style.width = parseInt(this.vs[this.av].dhxcont.mainCont[this.av].style.width)-(gLeft*2)+"px";
				
				if (!_isIE) this.vs[this.av].editor._prepareContent(true);
				this.vs[this.av].editor.setSizes();
				
			}
			
			if (this.vs[this.av].sched) { this.vs[this.av].sched.setSizes(); }	
			
			if (this.vs[this.av].dockedCell) { this.vs[this.av].dockedCell.updateNestedObjects(); }
			
			return;
		}
		if (this.vs[this.av].grid) { this.vs[this.av].grid.setSizes(); }
		if (this.vs[this.av].sched) { this.vs[this.av].sched.setSizes(); }
		if (this.vs[this.av].tabbar) { this.vs[this.av].tabbar.adjustOuterSize(); }
		if (this.vs[this.av].folders) { this.vs[this.av].folders.setSizes(); }
		if (this.vs[this.av].editor) {
			if (!_isIE) this.vs[this.av].editor._prepareContent(true);
			this.vs[this.av].editor.setSizes();
			
		}
		
		//if (_isOpera) { var t = this; window.setTimeout(function(){t.editor.adjustSize();},10); } else { this.vs[this.av].editor.adjustSize(); } }
		if (this.vs[this.av].layout) {
			if ((this._isAcc || this._isTabbarCell) && this.skin == "dhx_skyblue") {
				this.vs[this.av].layoutObj.style.width = parseInt(this.vs[this.av].dhxcont.mainCont[this.av].style.width)+2+"px";
				this.vs[this.av].layoutObj.style.height = parseInt(this.vs[this.av].dhxcont.mainCont[this.av].style.height)+2+"px";
			} else {
				this.vs[this.av].layoutObj.style.width = this.vs[this.av].dhxcont.mainCont[this.av].style.width;
				this.vs[this.av].layoutObj.style.height = this.vs[this.av].dhxcont.mainCont[this.av].style.height;
			}
			this.vs[this.av].layout.setSizes();
		}
		
		if (this.vs[this.av].accordion != null) {
			
			if (this.skin == "dhx_web") {
				this.vs[this.av].accordionObj.style.width = parseInt(this.vs[this.av].dhxcont.mainCont[this.av].style.width)+"px";
				this.vs[this.av].accordionObj.style.height = parseInt(this.vs[this.av].dhxcont.mainCont[this.av].style.height)+"px";
			} else {
				this.vs[this.av].accordionObj.style.width = parseInt(this.vs[this.av].dhxcont.mainCont[this.av].style.width)+2+"px";
				this.vs[this.av].accordionObj.style.height = parseInt(this.vs[this.av].dhxcont.mainCont[this.av].style.height)+2+"px";
			}
			this.vs[this.av].accordion.setSizes();
		}
		// docked layout's cell
		if (this.vs[this.av].dockedCell) { this.vs[this.av].dockedCell.updateNestedObjects(); }
		/*
		if (win.accordion != null) { win.accordion.setSizes(); }
		if (win.layout != null) { win.layout.setSizes(win); }
		*/
		if (this.vs[this.av].form) this.vs[this.av].form.setSizes();
		
		// temp?
		if (this.vs[this.av].carousel) this.vs[this.av].carousel.setSizes();
	}
	/**
	*   @desc: attaches a status bar to a window
	*   @type: public
	*/
	this.obj.attachStatusBar = function() {
		
		if (this.vs[this.av].sb) return;
		
		var sbObj = document.createElement("DIV");
		
		if (this._isCell) {
			sbObj.className = "dhxcont_sb_container_layoutcell";
		} else {
			sbObj.className = "dhxcont_sb_container";
		}
		sbObj.id = "sbobj_"+this._genStr(12);
		sbObj.innerHTML = "<div class='dhxcont_statusbar'></div>";
		
		if (this.cv == this.av) this.vs[this.av].dhxcont.insertBefore(sbObj, this.vs[this.av].dhxcont.childNodes[this.vs[this.av].dhxcont.childNodes.length-1]); else that.st.appendChild(sbObj);
		
		sbObj.setText = function(text) { this.childNodes[0].innerHTML = text; }
		sbObj.getText = function() { return this.childNodes[0].innerHTML; }
		sbObj.onselectstart = function(e) { e=e||event; e.returnValue=false; return false; }
		
		this.vs[this.av].sb = sbObj;
		this.vs[this.av].sbHeight = (this.skin=="dhx_web"?41:(this.skin=="dhx_skyblue"?23:sbObj.offsetHeight));
		this.vs[this.av].sbId = sbObj.id;
		
		if (this._doOnAttachStatusBar) this._doOnAttachStatusBar("init");
		this.adjust();
		
		return this.vs[this._viewRestore()].sb;
	}
	/**
	*   @desc: detaches a status bar from a window
	*   @type: public
	*/
	this.obj.detachStatusBar = function(destruct) {
		if (!this.vs[this.av].sb) return;
		this.vs[this.av].sb.setText = null;
		this.vs[this.av].sb.getText = null;
		this.vs[this.av].sb.onselectstart = null;
		this.vs[this.av].sb.parentNode.removeChild(this.vs[this.av].sb);
		this.vs[this.av].sb = null;
		this.vs[this.av].sbHeight = null;
		this.vs[this.av].sbId = null;
		this._viewRestore();
		if (this._doOnAttachStatusBar && !destruct) this._doOnAttachStatusBar("unload");
	}
	
	this.obj.getFrame = function(){
		return this.getView()._frame;
	};
	
	this.obj.getView = function(name){
		return this.vs[name||this.av];
	};
	
	
	/**
	*   @desc: attaches a dhtmlxMenu to a window
	*   @type: public
	*/
	this.obj.attachMenu = function(skin) {
		
		if (this.vs[this.av].menu) return;
		
		var menuObj = document.createElement("DIV");
		menuObj.style.position = "relative";
		menuObj.style.overflow = "hidden";
		menuObj.id = "dhxmenu_"+this._genStr(12);
		
		if (this.cv == this.av) this.vs[this.av].dhxcont.insertBefore(menuObj, this.vs[this.av].dhxcont.childNodes[0]); else that.st.appendChild(menuObj);
		
		if (typeof(skin) != "object") {
			this.vs[this.av].menu = new dhtmlXMenuObject(menuObj.id, (skin||this.skin));
		} else {
			skin.parent = menuObj.id;
			this.vs[this.av].menu = new dhtmlXMenuObject(skin);
		}
		this.vs[this.av].menuHeight = (this.skin=="dhx_web"?29:menuObj.offsetHeight);
		this.vs[this.av].menuId = menuObj.id;
		
		if (this._doOnAttachMenu) this._doOnAttachMenu("init");
		this.adjust();
		
		return this.vs[this._viewRestore()].menu;
	}
	/**
	*   @desc: detaches a dhtmlxMenu from a window
	*   @type: public
	*/
	this.obj.detachMenu = function(destruct) {
		if (!this.vs[this.av].menu) return;
		var menuObj = document.getElementById(this.vs[this.av].menuId);
		this.vs[this.av].menu.unload();
		this.vs[this.av].menu = null;
		this.vs[this.av].menuId = null;
		this.vs[this.av].menuHeight = null;
		if (menuObj) menuObj.parentNode.removeChild(menuObj);
		menuObj = null;
		this._viewRestore();
		if (this._doOnAttachMenu && !destruct) this._doOnAttachMenu("unload");
	}
	/**
	*   @desc: attaches a dhtmlxToolbar to a window
	*   @type: public
	*/
	this.obj.attachToolbar = function(skin) {
		
		if (this.vs[this.av].toolbar) return;
		
		var toolbarObj = document.createElement("DIV");
		toolbarObj.style.position = "relative";
		toolbarObj.style.overflow = "hidden";
		toolbarObj.id = "dhxtoolbar_"+this._genStr(12);
		
		if (this.cv == this.av) this.vs[this.av].dhxcont.insertBefore(toolbarObj, this.vs[this.av].dhxcont.childNodes[(this.vs[this.av].menu!=null?1:0)]); else that.st.appendChild(toolbarObj);
      
		if (typeof(skin) != "object") {
			this.vs[this.av].toolbar = new dhtmlXToolbarObject(toolbarObj.id, (skin||this.skin));
		} else {
			skin.parent = toolbarObj.id;
			this.vs[this.av].toolbar = new dhtmlXToolbarObject(skin);
		}
		this.vs[this.av].toolbarHeight = toolbarObj.offsetHeight;//(this.skin=="dhx_web"?41:toolbarObj.offsetHeight+(this._isLayout&&this.skin=="dhx_skyblue"?2:0));
		this.vs[this.av].toolbarId = toolbarObj.id;
		
		if (this._doOnAttachToolbar) this._doOnAttachToolbar("init");
		this.adjust();
		
		var t = this;
		this.vs[this.av].toolbar.attachEvent("_onIconSizeChange",function(size){
				
			t.vs[t.av].toolbarHeight = this.cont.offsetHeight;
			t.vs[t.av].toolbarId = this.cont.id;
			t.adjust();
			if (t._doOnAttachToolbar) t._doOnAttachToolbar("iconSizeChange");
			
		});
		if (this.skin != "dhx_terrace") this.vs[this.av].toolbar.callEvent("_onIconSizeChange",[]);
		
		return this.vs[this._viewRestore()].toolbar;
	}
	/**
	*   @desc: detaches a dhtmlxToolbar from a window
	*   @type: public
	*/
	this.obj.detachToolbar = function(destruct) {
		if (!this.vs[this.av].toolbar) return;
		var toolbarObj = document.getElementById(this.vs[this.av].toolbarId);
		this.vs[this.av].toolbar.unload();
		this.vs[this.av].toolbar = null;
		this.vs[this.av].toolbarId = null;
		this.vs[this.av].toolbarHeight = null;
		if (toolbarObj) toolbarObj.parentNode.removeChild(toolbarObj);
		toolbarObj = null;
		this._viewRestore();
		if (this._doOnAttachToolbar && !destruct) this._doOnAttachToolbar("unload");
	}
	/**
	*   @desc: attaches a dhtmlxGrid to a window
	*   @type: public
	*/
	this.obj.attachGrid = function() {
		
		if (this._isWindow && this.skin == "dhx_skyblue") {
			this.vs[this.av].dhxcont.mainCont[this.av].style.border = "#a4bed4 1px solid";
			this._redraw();
		}
		
		var obj = document.createElement("DIV");
		obj.id = "dhxGridObj_"+this._genStr(12);
		obj.style.width = "100%";
		obj.style.height = "100%";
		obj.cmp = "grid";
		document.body.appendChild(obj);
		this.attachObject(obj.id, false, true, false);
		
		this.vs[this.av].grid = new dhtmlXGridObject(obj.id);
		this.vs[this.av].grid.setSkin(this.skin);
		
		if (this.skin == "dhx_skyblue" || this.skin == "dhx_black" || this.skin == "dhx_blue") {
			this.vs[this.av].grid.entBox.style.border = "0px solid white";
			this.vs[this.av].grid._sizeFix = 2;
		}
		this.vs[this.av].gridId = obj.id;
		this.vs[this.av].gridObj = obj;
		
		if (this.skin == "dhx_terrace") {
			this.adjust();
			this.updateNestedObjects(true);
		}
		
		return this.vs[this._viewRestore()].grid;
	}
	/**
	*   @desc: attaches a dhtmlxScheduler to a window
	*   @type: public
	*/	
	this.obj.attachScheduler = function(day,mode,cont_id,scheduler) {
		scheduler = scheduler || window.scheduler;

		var ready = 0;
		if (cont_id){
			obj = document.getElementById(cont_id);
			if (obj) 
				ready = 1;
		}
		if (!ready){
			var tabs = cont_id || '<div class="dhx_cal_tab" name="day_tab" style="right:204px;"></div><div class="dhx_cal_tab" name="week_tab" style="right:140px;"></div><div class="dhx_cal_tab" name="month_tab" style="right:76px;"></div>';
			var obj = document.createElement("DIV");
			obj.id = "dhxSchedObj_"+this._genStr(12);
			obj.innerHTML = '<div id="'+obj.id+'" class="dhx_cal_container" style="width:100%; height:100%;"><div class="dhx_cal_navline"><div class="dhx_cal_prev_button">&nbsp;</div><div class="dhx_cal_next_button">&nbsp;</div><div class="dhx_cal_today_button"></div><div class="dhx_cal_date"></div>'+tabs+'</div><div class="dhx_cal_header"></div><div class="dhx_cal_data"></div></div>';
			document.body.appendChild(obj.firstChild);
		}
		
		this.attachObject(obj.id, false, true, false);
		
		this.vs[this.av].sched = scheduler;
		this.vs[this.av].schedId = obj.id;
		scheduler.setSizes = scheduler.update_view;
		scheduler.destructor=function(){};
		scheduler.init(obj.id,day,mode);
		
		return this.vs[this._viewRestore()].sched;
	}	
	/**
	*   @desc: attaches a dhtmlxTree to a window
	*   @param: rootId - not mandatory, tree super root, see dhtmlxTree documentation for details
	*   @type: public
	*/
	this.obj.attachTree = function(rootId) {
		if (this._isWindow && this.skin == "dhx_skyblue") {
			this.vs[this.av].dhxcont.mainCont[this.av].style.border = "#a4bed4 1px solid";
			this._redraw();
		}
		
		var obj = document.createElement("DIV");
		obj.id = "dhxTreeObj_"+this._genStr(12);
		obj.style.width = "100%";
		obj.style.height = "100%";
		obj.cmp = "tree";
		document.body.appendChild(obj);
		
		this.attachObject(obj.id, false, true, false);
		this.vs[this.av].tree = new dhtmlXTreeObject(obj.id, "100%", "100%", (rootId||0));
		this.vs[this.av].tree.setSkin(this.skin);
		// this.tree.allTree.style.paddingTop = "2px";
		this.vs[this.av].tree.allTree.childNodes[0].style.marginTop = "2px";
		this.vs[this.av].tree.allTree.childNodes[0].style.marginBottom = "2px";
		
		this.vs[this.av].treeId = obj.id;
		this.vs[this.av].treeObj = obj;
		
		if (this.skin == "dhx_terrace") {
			this.adjust();
			this.updateNestedObjects(true);
		}
		
		return this.vs[this._viewRestore()].tree;
	}
	/**
	*   @desc: attaches a dhtmlxTabbar to a window
	*   @type: public
	*/
	this.obj.attachTabbar = function(mode) {
		
		if (this._isWindow && this.skin == "dhx_skyblue") {
			this.vs[this.av].dhxcont.style.border = "none";
			this.setDimension(this.w, this.h);
		}
		
		var obj = document.createElement("DIV");
		obj.id = "dhxTabbarObj_"+this._genStr(12);
		obj.style.width = "100%";
		obj.style.height = "100%";
		obj.style.overflow = "hidden";
		obj.cmp = "tabbar";
		if (!this._isWindow) obj._hideBorders = true;
		document.body.appendChild(obj);
		this.attachObject(obj.id, false, true, false);
		
		// manage dockcell if exists
		if (this._isCell) {
			this.hideHeader();
			obj._hideBorders = false;
			this._padding = false;
		}
		
		this.vs[this.av].tabbar = new dhtmlXTabBar(obj.id, mode||"top", (this.skin=="dhx_terrace"?null:20));
		if (!this._isWindow && this.skin != "dhx_terrace") this.vs[this.av].tabbar._s.expand = true;
		this.vs[this.av].tabbar.setSkin(this.skin);
		this.vs[this.av].tabbar.adjustOuterSize();
		this.vs[this.av].tabbarId = obj.id;
		this.vs[this.av].tabbarObj = obj;
		
		if (this.skin == "dhx_terrace") {
			this.adjust();
			this.updateNestedObjects(true);
		}
		
		return this.vs[this._viewRestore()].tabbar;
	}
	/**
	*   @desc: attaches a dhtmlxFolders to a window
	*   @type: public
	*/
	this.obj.attachFolders = function() {
		if (this._isWindow && this.skin == "dhx_skyblue") {
			this.vs[this.av].dhxcont.mainCont[this.av].style.border = "#a4bed4 1px solid";
			this._redraw();
		}
		var obj = document.createElement("DIV");
		obj.id = "dhxFoldersObj_"+this._genStr(12);
		obj.style.width = "100%";
		obj.style.height = "100%";
		obj.style.overflow = "hidden";
		obj.cmp = "folders";
		document.body.appendChild(obj);
		this.attachObject(obj.id, false, true, false);
		this.vs[this.av].folders = new dhtmlxFolders(obj.id);
		this.vs[this.av].folders.setSizes();
		
		this.vs[this.av].foldersId = obj.id;
		this.vs[this.av].foldersObj = obj;
		
		return this.vs[this._viewRestore()].folders;
	}
	/**
	*   @desc: attaches a dhtmlxAccordion to a window
	*   @type: public
	*/
	this.obj.attachAccordion = function() {
		if (this._isWindow && this.skin == "dhx_skyblue") {
			this.vs[this.av].dhxcont.mainCont[this.av].style.border = "#a4bed4 1px solid";
			this._redraw();
		}
		
		var obj = document.createElement("DIV");
		obj.id = "dhxAccordionObj_"+this._genStr(12);
		
		this._padding = true;
		
		if (this.skin == "dhx_web") {
			obj.style.left = "0px";
			obj.style.top = "0px";
			obj.style.width = parseInt(this.vs[this.av].dhxcont.mainCont[this.av].style.width)+"px";
			obj.style.height = parseInt(this.vs[this.av].dhxcont.mainCont[this.av].style.height)+"px";
		} else if (this.skin != "dhx_terrace") {
			obj.style.left = "-1px";
			obj.style.top = "-1px";
			obj.style.width = parseInt(this.vs[this.av].dhxcont.mainCont[this.av].style.width)+2+"px";
			obj.style.height = parseInt(this.vs[this.av].dhxcont.mainCont[this.av].style.height)+2+"px";
		}
		
		//
		obj.style.position = "relative";
		obj.cmp = "accordion";
		document.body.appendChild(obj);
		this.attachObject(obj.id, false, true, false);
		
		this.vs[this.av].accordion = new dhtmlXAccordion(obj.id, this.skin);
		this.vs[this.av].accordion.setSizes();
		this.vs[this.av].accordionId = obj.id;
		this.vs[this.av].accordionObj = obj;
		
		if (this.skin == "dhx_terrace") {
			this.adjust();
			this.updateNestedObjects(true);
		}
		
		return this.vs[this._viewRestore()].accordion;
	}
	/**
	*   @desc: attaches a dhtmlxLayout to a window
	*   @param: view - layout's pattern
	*   @param: skin - layout's skin
	*   @type: public
	*/
	this.obj.attachLayout = function(view, skin) {
		
		// attach layout to layout
		if (this._isCell && this.skin == "dhx_skyblue") {
			this.hideHeader();
			this.vs[this.av].dhxcont.style.border = "0px solid white";
			this.adjustContent(this.childNodes[0], 0);
		}
		
		if (this._isCell && this.skin == "dhx_web") {
			this.hideHeader();
		}
		
		this._padding = true;
		
		var obj = document.createElement("DIV");
		obj.id = "dhxLayoutObj_"+this._genStr(12);
		obj.style.overflow = "hidden";
		obj.style.position = "absolute";
		
		obj.style.left = "0px";
		obj.style.top = "0px";
		obj.style.width = parseInt(this.vs[this.av].dhxcont.mainCont[this.av].style.width)+"px";
		obj.style.height = parseInt(this.vs[this.av].dhxcont.mainCont[this.av].style.height)+"px";
		
		if ((this._isTabbarCell || this._isAcc) && (this.skin == "dhx_skyblue")) {
			obj.style.left = "-1px";
			obj.style.top = "-1px";
			obj.style.width = parseInt(this.vs[this.av].dhxcont.mainCont[this.av].style.width)+2+"px";
			obj.style.height = parseInt(this.vs[this.av].dhxcont.mainCont[this.av].style.height)+2+"px";
		}
		
		// needed for layout's init
		obj.dhxContExists = true;
		obj.cmp = "layout";
		document.body.appendChild(obj);
		this.attachObject(obj.id, false, true, false);
		
		this.vs[this.av].layout = new dhtmlXLayoutObject(obj, view, (skin||this.skin));
		
		
		// window/layout events configuration
		if (this._isWindow) this.attachEvent("_onBeforeTryResize", this.vs[this.av].layout._defineWindowMinDimension);
		
		this.vs[this.av].layoutId = obj.id;
		this.vs[this.av].layoutObj = obj;
		
		if (this.skin == "dhx_terrace") {
			if (this._isCell) {
				//debugger
				this.style.backgroundColor = "transparent";
				this.vs[this.av].dhxcont.style.backgroundColor = "transparent";
				this.hideHeader();
			}
			this.adjust();
			this.updateNestedObjects(true);
			
		}
		
		return this.vs[this._viewRestore()].layout;
	}
	/**
	*   @desc: attaches a dhtmlxEditor to a window
	*   @param: skin - not mandatory, editor's skin
	*   @type: public
	*/
	this.obj.attachEditor = function(skin) {
		
		if (this._isWindow && this.skin == "dhx_skyblue") {
			this.vs[this.av].dhxcont.mainCont[this.av].style.border = "#a4bed4 1px solid";
			this._redraw();
		}
		
		var obj = document.createElement("DIV");
		obj.id = "dhxEditorObj_"+this._genStr(12);
		obj.style.position = "relative";
		obj.style.display = "none";
		obj.style.overflow = "hidden";
		obj.style.width = "100%";
		obj.style.height = "100%";
		obj.cmp = "editor";
		document.body.appendChild(obj);
		
		if (this.skin == "dhx_terrace") obj._attached = true;
		
		//
		this.attachObject(obj.id, false, true, false);
		//
		this.vs[this.av].editor = new dhtmlXEditor(obj.id, skin||this.skin);
		
		this.vs[this.av].editorId = obj.id;
		this.vs[this.av].editorObj = obj;
		
		
		if (this.skin == "dhx_terrace") {
			this.adjust();
			this.updateNestedObjects(true);
		}
		
		return this.vs[this._viewRestore()].editor;
		
	}
	
	this.obj.attachMap = function(opts) {
		
		var obj = document.createElement("DIV");
		obj.id = "GMapsObj_"+this._genStr(12);
		obj.style.position = "relative";
		obj.style.display = "none";
		obj.style.overflow = "hidden";
		obj.style.width = "100%";
		obj.style.height = "100%";
		obj.cmp = "gmaps";
		document.body.appendChild(obj);
		
		this.attachObject(obj.id, false, true, true);
		
		if (!opts) opts = {center: new google.maps.LatLng(40.719837,-73.992348), zoom: 11, mapTypeId: google.maps.MapTypeId.ROADMAP};
		this.vs[this.av].gmaps = new google.maps.Map(obj, opts);
		
		return this.vs[this.av].gmaps;
		
	}
	
	/**
	*   @desc: attaches an object into a window
	*   @param: obj - object or object id
	*   @param: autoSize - set true to adjust a window to object's dimension
	*   @type: public
	*/
	this.obj.attachObject = function(obj, autoSize, localCall, adjustMT) {
		if (typeof(obj) == "string") obj = document.getElementById(obj);
		if (autoSize) {
			obj.style.visibility = "hidden";
			obj.style.display = "";
			var objW = obj.offsetWidth;
			var objH = obj.offsetHeight;
		}
		this._attachContent("obj", obj);
		if (autoSize && this._isWindow) {
			obj.style.visibility = "";
			this._adjustToContent(objW, objH);
			/* this._engineAdjustWindowToContent(this, objW, objH); */
		}
		
		if (this.skin == "dhx_terrace") {
			if (this.vs[this.av].menu != null || this.vs[this.av].toolbar != null) {
				this.adjust(typeof(adjustMT)=="undefined"||adjustMT==true);
				this.updateNestedObjects(true);
			}
		}
		if (!localCall) {
			this._viewRestore();
		}
		
	}
	/**
	*
	*
	*/
	this.obj.detachObject = function(remove, moveTo) {
		
		// detach dhtmlx components
		
		var p = null;
		var pObj = null;
		
		var t = ["tree","grid","layout","tabbar","accordion","folders","form"];
		for (var q=0; q<t.length; q++) {
			if (this.vs[this.av][t[q]]) {
				p = this.vs[this.av][t[q]];
				pObj = this.vs[this.av][t[q]+"Obj"];
				if (remove) {
					if (p.unload) p.unload();
					if (p.destructor) p.destructor();
					while (pObj.childNodes.length > 0) pObj.removeChild(pObj.childNodes[0]);
					pObj.parentNode.removeChild(pObj);
					pObj = null;
					p = null;
				} else {
					document.body.appendChild(pObj);
					pObj.style.display = "none";
				}
				this.vs[this.av][t[q]] = null;
				this.vs[this.av][t[q]+"Id"] = null;
				this.vs[this.av][t[q]+"Obj"] = null;
			}
		}
		
		if (p != null && pObj != null) return new Array(p, pObj);
		
		// detach any other content
		if (remove && this.vs[this.av]._frame) {
			this._detachURLEvents();
			this.vs[this.av]._frame = null;
		}
		
		var objA = this.vs[this.av].dhxcont.mainCont[this.av];
		while (objA.childNodes.length > 0) {
			if (remove == true) {
				// add frame events removing
				objA.removeChild(objA.childNodes[0]);
			} else {
				var obj = objA.childNodes[0];
				if (moveTo != null) {
					if (typeof(moveTo) != "object") moveTo = document.getElementById(moveTo);
					moveTo.appendChild(obj);
				} else {
					document.body.appendChild(obj);
				}
				obj.style.display = "none";
			}
		}
		
		objA = moveTo = null;
	}
	
	/**
	*   @desc: appends an object into a window
	*   @param: obj - object or object id
	*   @type: public
	*/
	this.obj.appendObject = function(obj) {
		if (typeof(obj) == "string") { obj = document.getElementById(obj); }
		this._attachContent("obj", obj, true);
	}
	/**
	*   @desc: attaches an html string as an object into a window
	*   @param: str - html string
	*   @type: public
	*/
	this.obj.attachHTMLString = function(str) {
		this._attachContent("str", str);
		var z=str.match(/<script[^>]*>[^\f]*?<\/script>/g)||[];
		for (var i=0; i<z.length; i++){
			var s=z[i].replace(/<([\/]{0,1})script[^>]*>/g,"")
			if (s){
				if (window.execScript) window.execScript(s);
				else window.eval(s);	
			}
		}
	}
	/**
	*   @desc: attaches an url into a window
	*   @param: url
	*   @param: ajax - loads an url with ajax
	*   @type: public
	*/
	this.obj.attachURL = function(url, ajax) {
		this._attachContent((ajax==true?"urlajax":"url"), url, false);
		if (this.skin == "dhx_terrace") {
			if (this.vs[this.av].menu != null || this.vs[this.av].toolbar != null) {
				this.adjust(true);
				this.updateNestedObjects(true);
			}
		}		
		this._viewRestore();
	}
	this.obj.adjust = function(adjustMT) {
		if (this.skin == "dhx_skyblue") {
			if (this.vs[this.av].menu) {
				if (this._isWindow || this._isLayout) {
					this.vs[this.av].menu._topLevelOffsetLeft = 0;
					document.getElementById(this.vs[this.av].menuId).style.height = "26px";
					this.vs[this.av].menuHeight = document.getElementById(this.vs[this.av].menuId).offsetHeight;
					if (this._doOnAttachMenu) this._doOnAttachMenu("show");
				}
				if (this._isCell) {
					document.getElementById(this.vs[this.av].menuId).className += " in_layoutcell";
					this.vs[this.av].menuHeight = 25;
				}
				if (this._isAcc) {
					document.getElementById(this.vs[this.av].menuId).className += " in_acccell";
					this.vs[this.av].menuHeight = 25;
				}
				if (this._doOnAttachMenu) this._doOnAttachMenu("adjust");
			}
			if (this.vs[this.av].toolbar) {
				if (this._isWindow) {
					document.getElementById(this.vs[this.av].toolbarId).className += " in_window";
				}
				if (this._isLayout) {
					document.getElementById(this.vs[this.av].toolbarId).className += " in_layout";
				}
				if (this._isCell) {
					document.getElementById(this.vs[this.av].toolbarId).className += " in_layoutcell";
				}
				if (this._isAcc) {
					document.getElementById(this.vs[this.av].toolbarId).className += " in_acccell";
				}
				if (this._isTabbarCell) {
					document.getElementById(this.vs[this.av].toolbarId).className += " in_tabbarcell";
				}
			}
		}
		
		if (this.skin == "dhx_web") {
			if (this.vs[this.av].toolbar) {
				if (this._isWindow) {
					document.getElementById(this.vs[this.av].toolbarId).className += " in_window";
				}
				if (this._isLayout) {
					//this.vs[this.av].toolbarHeight = document.getElementById(this.vs[this.av].toolbarId).offsetHeight+9;
					document.getElementById(this.vs[this.av].toolbarId).className += " in_layout";
				}
				if (this._isCell) {
					document.getElementById(this.vs[this.av].toolbarId).className += " in_layoutcell";
				}
				if (this._isAcc) {
					document.getElementById(this.vs[this.av].toolbarId).className += " in_acccell";
				}
				if (this._isTabbarCell) {
					document.getElementById(this.vs[this.av].toolbarId).className += " in_tabbarcell";
				}
			}
		}
		
		if (this.skin == "dhx_terrace") {
			
			// menu/toolbar paddings
			var mtLRPad = 0;
			if (this._isWindow || this._isCell || this._isAcc || this._isTabbarCell) mtLRPad = 14;
			if (this._isCell && this._noHeader) mtLRPad = 0;
			
			// menu/toolbar top padding
			var mtTPad = 0;
			if (this._isWindow || this._isCell || this._isAcc || this._isTabbarCell) mtTPad = 14;
			if (this._isCell && this._noHeader) mtTPad = 0; // attached to layout w/o border (tabbar mode)
			
			// menu/toolbar bottom padding - only if url or object attached,
			// layout's top
			var mBPad = ((adjustMT == true && !this.vs[this.av].toolbar) || this._isLayout ? 14 : 0);
			var tBPad = (adjustMT == true || this._isLayout ? 14 : 0);
			
			var mtAttached = false;
			
			if (this.vs[this.av].menu) {
				
				document.getElementById(this.vs[this.av].menuId).style.marginLeft = mtLRPad+"px";
				document.getElementById(this.vs[this.av].menuId).style.marginRight = mtLRPad+"px";
				document.getElementById(this.vs[this.av].menuId).style.marginTop = mtTPad+"px";
				document.getElementById(this.vs[this.av].menuId).style.marginBottom = mBPad+"px";
				
				this.vs[this.av].menuHeight = 32+mtTPad+mBPad;
				
				if (this._doOnAttachMenu) this._doOnAttachMenu("show");
				
				mtAttached = true;
			}
			
			if (this.vs[this.av].toolbar) {
				
				if (mtTPad == 0 && this.vs[this.av].menu != null & this._isCell) mtTPad = 14; // if tabbar and menu attached and no header
				
				document.getElementById(this.vs[this.av].toolbarId).style.marginLeft = mtLRPad+"px";
				document.getElementById(this.vs[this.av].toolbarId).style.marginRight = mtLRPad+"px";
				document.getElementById(this.vs[this.av].toolbarId).style.marginTop = mtTPad+"px";
				document.getElementById(this.vs[this.av].toolbarId).style.marginBottom = tBPad+"px";
				
				//this.vs[this.av].toolbarHeight = 32+mtTPad+tBPad;
				this.vs[this.av].toolbarHeight = this.vs[this.av].toolbar.cont.offsetHeight+mtTPad+tBPad;
				
				if (this._doOnAttachToolbar) this._doOnAttachToolbar("show");
				
				mtAttached = true;
				
			}
		}
	}
	
	// attach content obj|url
	this.obj._attachContent = function(type, obj, append) {
		// clear old content
		if (append !== true) {
			if (this.vs[this.av]._frame) {
				this._detachURLEvents();
				this.vs[this.av]._frame = null;
			}
			while (this.vs[this.av].dhxcont.mainCont[this.av].childNodes.length > 0) this.vs[this.av].dhxcont.mainCont[this.av].removeChild(this.vs[this.av].dhxcont.mainCont[this.av].childNodes[0]);
		}
		// attach
		if (type == "url") {
			if (this._isWindow && obj.cmp == null && this.skin == "dhx_skyblue") {
				this.vs[this.av].dhxcont.mainCont[this.av].style.border = "#a4bed4 1px solid";
				this._redraw();
			}
			var fr = document.createElement("IFRAME");
			fr.frameBorder = 0;
			fr.border = 0;
			fr.style.width = "100%";
			fr.style.height = "100%";
			fr.setAttribute("src","javascript:false;");
			this.vs[this.av].dhxcont.mainCont[this.av].appendChild(fr);
			fr.src = obj;
			
			// ?? this._frame = fr;
			this.vs[this.av]._frame = fr;
			this._attachURLEvents();
			
		} else if (type == "urlajax") {
			
			if (this._isWindow && obj.cmp == null && this.skin == "dhx_skyblue") {
				this.vs[this.av].dhxcont.mainCont[this.av].style.border = "#a4bed4 1px solid";
				this.vs[this.av].dhxcont.mainCont[this.av].style.backgroundColor = "#FFFFFF";
				this._redraw();
			}
			var t = this;
			var tav = String(this.av).valueOf();
			var xmlParser = function(){
				var tmp = t.av;
				t.av = tav;
				t.attachHTMLString(this.xmlDoc.responseText, this);
				t.av = tmp;
				//if (t._doOnAttachURL) t._doOnAttachURL(false);
				if (t._doOnFrameContentLoaded) t._doOnFrameContentLoaded();
				this.destructor();
			}
			var xmlLoader = new dtmlXMLLoaderObject(xmlParser, window);
			xmlLoader.dhxWindowObject = this;
			xmlLoader.loadXML(obj);
			
		} else if (type == "obj") {
			
			if (this._isWindow && obj.cmp == null && this.skin == "dhx_skyblue") {
				this.vs[this.av].dhxcont.mainCont[this.av].style.border = "#a4bed4 1px solid";
				this.vs[this.av].dhxcont.mainCont[this.av].style.backgroundColor = "#FFFFFF";
				this._redraw();
			}
			this.vs[this.av].dhxcont._frame = null;
			this.vs[this.av].dhxcont.mainCont[this.av].appendChild(obj);
			// this._engineGetWindowContent(win).style.overflow = (append===true?"auto":"hidden");
			// win._content.childNodes[2].appendChild(obj);
			this.vs[this.av].dhxcont.mainCont[this.av].style.overflow = (append===true?"auto":"hidden");
			obj.style.display = "";
			
		} else if (type == "str") {
			
			if (this._isWindow && obj.cmp == null && this.skin == "dhx_skyblue") {
				this.vs[this.av].dhxcont.mainCont[this.av].style.border = "#a4bed4 1px solid";
				this.vs[this.av].dhxcont.mainCont[this.av].style.backgroundColor = "#FFFFFF";
				this._redraw();
			}
			this.vs[this.av].dhxcont._frame = null;
			this.vs[this.av].dhxcont.mainCont[this.av].innerHTML = obj;
		}
	}
	
	this.obj._attachURLEvents = function() {
		var t = this;
		var fr = this.vs[this.av]._frame;
		if (_isIE) {
			fr.onreadystatechange = function(a) {
				if (fr.readyState == "complete") {
					try {fr.contentWindow.document.body.onmousedown=function(){if(t._doOnFrameMouseDown)t._doOnFrameMouseDown();};}catch(e){};
					try{if(t._doOnFrameContentLoaded)t._doOnFrameContentLoaded();}catch(e){};
				}
			}
		} else {
			fr.onload = function() {
				try{fr.contentWindow.onmousedown=function(){if(t._doOnFrameMouseDown)t._doOnFrameMouseDown();};}catch(e){};
				try{if(t._doOnFrameContentLoaded)t._doOnFrameContentLoaded();}catch(e){};
			}
		}
	}
	
	this.obj._detachURLEvents = function() {
		if (_isIE) {
			try {
				this.vs[this.av]._frame.onreadystatechange = null;
				this.vs[this.av]._frame.contentWindow.document.body.onmousedown = null;
				this.vs[this.av]._frame.onload = null;
			} catch(e) {};
		} else {
			try {
				this.vs[this.av]._frame.contentWindow.onmousedown = null;
				this.vs[this.av]._frame.onload = null;
			} catch(e) {};
		}
	}
	
	this.obj.showMenu = function() {
		if (!(this.vs[this.av].menu && this.vs[this.av].menuId)) return;
		if (document.getElementById(this.vs[this.av].menuId).style.display != "none") return;
		this.vs[this.av].menuHidden = false;
		if (this._doOnAttachMenu) this._doOnAttachMenu("show");
		document.getElementById(this.vs[this.av].menuId).style.display = "";
		this._viewRestore();
	}
	
	this.obj.hideMenu = function() {
		if (!(this.vs[this.av].menu && this.vs[this.av].menuId)) return;
		if (document.getElementById(this.vs[this.av].menuId).style.display == "none") return;
		document.getElementById(this.vs[this.av].menuId).style.display = "none";
		this.vs[this.av].menuHidden = true;
		if (this._doOnAttachMenu) this._doOnAttachMenu("hide");
		this._viewRestore();
	}
	
	this.obj.showToolbar = function() {
		if (!(this.vs[this.av].toolbar && this.vs[this.av].toolbarId)) return;
		if (document.getElementById(this.vs[this.av].toolbarId).style.display != "none") return;
		this.vs[this.av].toolbarHidden = false;
		if (this._doOnAttachToolbar) this._doOnAttachToolbar("show");
		document.getElementById(this.vs[this.av].toolbarId).style.display = "";
		this._viewRestore();
	}
	
	this.obj.hideToolbar = function() {
		if (!(this.vs[this.av].toolbar && this.vs[this.av].toolbarId)) return;
		if (document.getElementById(this.vs[this.av].toolbarId).style.display == "none") return;
		this.vs[this.av].toolbarHidden = true;
		document.getElementById(this.vs[this.av].toolbarId).style.display = "none";
		if (this._doOnAttachToolbar) this._doOnAttachToolbar("hide");
		this._viewRestore();
	}
	
	this.obj.showStatusBar = function() {
		if (!(this.vs[this.av].sb && this.vs[this.av].sbId)) return;
		if (document.getElementById(this.vs[this.av].sbId).style.display != "none") return;
		this.vs[this.av].sbHidden = false;
		if (this._doOnAttachStatusBar) this._doOnAttachStatusBar("show");
		document.getElementById(this.vs[this.av].sbId).style.display = "";
		this._viewRestore();
	}
	
	this.obj.hideStatusBar = function() {
		if (!(this.vs[this.av].sb && this.vs[this.av].sbId)) return;
		if (document.getElementById(this.vs[this.av].sbId).style.display == "none") return;
		this.vs[this.av].sbHidden = true;
		document.getElementById(this.vs[this.av].sbId).style.display = "none";
		if (this._doOnAttachStatusBar) this._doOnAttachStatusBar("hide");
		this._viewRestore();
	}
	
	this.obj._dhxContDestruct = function() {
		
		// clear attached objects
		
		var av = this.av;
		for (var a in this.vs) {
			
			this.av = a;
			
			// menu, toolbar, status
			this.detachMenu(true);
			this.detachToolbar(true);
			this.detachStatusBar(true);
			
			// remove any attached object or dhtmlx component
			this.detachObject(true);
			
			this.vs[a].dhxcont.mainCont[a] = null;
		}
		
		for (var a in this.vs) {
			this.vs[a].dhxcont.mainCont = null;
			this.vs[a].dhxcont.innerHTML = "";
			this.vs[a].dhxcont = null;
			this.vs[a] = null;
		}
		this.vs = null;
		
		this.attachMenu = null;
		this.attachToolbar = null;
		this.attachStatusBar = null;
		this.detachMenu = null;
		this.detachToolbar = null;
		this.detachStatusBar = null;
		this.showMenu = null;
		this.showToolbar = null;
		this.showStatusBar = null;
		this.hideMenu = null;
		this.hideToolbar = null;
		this.hideStatusBar = null;
		
		this.attachGrid = null;
		this.attachScheduler = null;
		this.attachTree = null;
		this.attachTabbar = null;
		this.attachFolders = null;
		this.attachAccordion = null;
		this.attachLayout = null;
		this.attachEditor = null;
		this.attachObject = null;
		this.detachObject = null;
		this.appendObject = null;
		this.attachHTMLString = null;
		this.attachURL = null;
		this.attachMap = null;
		
		this.view = null;
		this.show = null;
		this.adjust = null;
		this.setMinContentSize = null;
		this.moveContentTo = null;
		this.adjustContent = null;
		this.coverBlocker = null;
		this.showCoverBlocker = null;
		this.hideCoverBlocker = null;
		this.updateNestedObjects = null;
		
		this._attachContent = null;
		this._attachURLEvents = null;
		this._detachURLEvents = null;
		this._viewRestore = null;
		this._setPadding = null;
		this._init = null;
		this._genStr = null;
		this._dhxContDestruct = null;
		
		this._getSt = null;
		this.getFrame = null;
		this.getView = null;
		this.setActive = null;
		
		that.st.innerHTML = "";
		that.st.parentNode.removeChild(that.st);
		that.st = null;
		
		that.setContent = null;
		that.dhxcont = null; // no more used at all?
		that.obj = null;
		that = null;
		
		// remove attached components
		/*
		for (var a in this.vs) {
		
			if (this.vs[a].layout) this.vs[a].layout.unlaod();
			if (this.vs[a].accordion) this.vs[a].accordion.unlaod();
			if (this.vs[a].sched) this.vs[a].sched.destructor();
			
			this.vs[a].layout = null;
			this.vs[a].accordion = null;
			this.vs[a].sched = null;
			
		}
		*/
		// extended functionality
		if (dhtmlx.detaches) for (var a in dhtmlx.detaches) dhtmlx.detaches[a](this);
		
	}
	
	// extended functionality
	if (dhtmlx.attaches) for (var a in dhtmlx.attaches) this.obj[a] = dhtmlx.attaches[a];
	
	return this;
	
}
