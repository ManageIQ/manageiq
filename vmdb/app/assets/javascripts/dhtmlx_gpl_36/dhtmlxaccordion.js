//v.3.6 build 131108

/*
Copyright DHTMLX LTD. http://www.dhtmlx.com
You allowed to use this component or parts of it under GPL terms
To use it on other terms or get Professional edition of the component please contact us at sales@dhtmlx.com
*/
/**
*	@desc: constructor, creates an accordion item under dhtmlxaccordion
*	@pseudonym: item
*	@type: public
*/
function dhtmlXAccordionItem(){
	
}

/**
*	@desc: constructor, creates a dhtmlXAccordion object
*	@param: baseId - object/objectId
*	@param: skin - used skin
*	@type: public
*/
function dhtmlXAccordion(baseId, skin) {
	
	if (!window.dhtmlXContainer) {
		alert(this.i18n.dhxcontalert);
		return;
	}
	
	var that = this;
	
	this.skin = (skin != null ? skin : (typeof(dhtmlx) != "undefined" && typeof(dhtmlx.skin) == "string" ? dhtmlx.skin : "dhx_skyblue"));
	
	if (baseId == document.body) {
		//
		this._isAccFS = true;
		
		document.body.className += " dhxacc_fullscreened";
		
		var contObj = document.createElement("DIV");
		contObj.className = "dhxcont_global_layout_area";
		baseId.appendChild(contObj);
		
		this.cont = new dhtmlXContainer(baseId);
		this.cont.setContent(contObj);
		
		baseId.adjustContent(baseId, 0);
		
		this.base = document.createElement("DIV");
		this.base.className = "dhx_acc_base_"+this.skin;
		this.base.style.overflow = "hidden";
		this.base.style.position = "absolute";
		
		this._adjustToFullScreen = function() {
			this.base.style.left = "2px";
			this.base.style.top = "2px";
			this.base.style.width = parseInt(contObj.childNodes[0].style.width)-4+"px";
			this.base.style.height = parseInt(contObj.childNodes[0].style.height)-4+"px";
		}
		this._adjustToFullScreen();
		contObj.childNodes[0].appendChild(this.base);
		
		// resize events
		this._resizeTM = null;
		this._resizeTMTime = 400;
		this._doOnResize = function() {
			window.clearTimeout(that._resizeTM);
			that._resizeTM = window.setTimeout(function(){that._adjustAccordion();}, that._resizeTMTime);
		}
		this._adjustAccordion = function() {
			document.body.adjustContent(document.body, 0);
			this._adjustToFullScreen();
			this.setSizes();
		}
		dhtmlxEvent(window, "resize", this._doOnResize);
		
	} else {
		this.base = (typeof(baseId)=="string"?document.getElementById(baseId):baseId);
		this.base.className = "dhx_acc_base_"+this.skin;
		this.base.innerHTML = "";
	}
	this.w = this.base.offsetWidth;
	this.h = this.base.offsetHeight;
	
	//alert(this.h+" "+this.base.parentNode.offsetHeight)
	
	this.skinParams = { "dhx_blue":		{ "cell_height": 24, "cell_space": 1, "content_offset": 1 },
			    "dhx_skyblue":	{ "cell_height": 27, "cell_space":-1, "content_offset":-1 },
			    "dhx_black":	{ "cell_height": 24, "cell_space": 1, "content_offset": 1 },
			    "dhx_web":		{ "cell_height": 26, "cell_space": 9, "content_offset": 0, "cell_pading_max": 1, "cell_pading_min": 0 },
			    "dhx_terrace":	{ "cell_height": 37, "cell_space":-1, "content_offset": -1 }
	};
	
	this.sk = this.skinParams[this.skin];
	
	this.setSkinParameters = function(cellSpace, contentOffset) {
		if (!isNaN(cellSpace)) this.sk["cell_space"] = cellSpace;
		if (!isNaN(contentOffset)) this.sk["content_offset"] = contentOffset;
		this._reopenItem();
	}
	
	this.setSkin = function(skin) {
		if (!this.skinParams[skin]) return;
		this.skin = skin;
		this.sk = this.skinParams[this.skin];
		this.base.className = "dhx_acc_base_"+this.skin+(this._r?" dhx_acc_rtl":"");
		for (var a in this.idPull) this.idPull[a].skin = this.skin;
		this._reopenItem();
	}
	
	this.idPull = {};
	
	this.opened = null;
	
	/**
	*	@desc: returns the handler to an item by id
	*	@param: itemId - id
	*	@type: public
	*/
	this.cells = function(itemId) {
		if (this.idPull[itemId] == null) { return null; }
		return this.idPull[itemId];//._win;
	}
	
	
	this.itemH = 90;
	this.multiMode = false;
	/**
	*	@desc: enable multimode in accordion (disabled by the default)
	*	@type: public
	*/
	this.enableMultiMode = function() {
		var totalItems = 0;
		for (var a in this.idPull) totalItems++;
		if (totalItems == 0) {
			if (!this.userOffset) this.skinParams["dhx_skyblue"]["cell_space"] = 3;
			this.multiMode = true;
		}
		if (this.skin == "dhx_terrace") {
			this.skinParams["dhx_terrace"]["cell_space"] = 12;
		}
	}
	
	this.userOffset = false;
	this.setOffset = function(cellOffset, contentOffset) {
		this.userOffset = true;
		if (!isNaN(cellOffset)) this.skinParams[this.skin]["cell_space"] = cellOffset;
		if (!isNaN(contentOffset)) this.skinParams[this.skin]["content_offset"] = contentOffset;
		this.setSizes();
	}
	// path to icons
	this.imagePath = "";
	/**
	*	@desc: set path to icons
	*	@param: path - path on the hard disk
	*	@type: public
	*/
	this.setIconsPath = function(path) {
		this.imagePath = path;
	}
	
	/**
	*	@desc: adds a new item
	*	@param: itemId - item's id
	*	@param: itemText - item's text
	*	@type: public
	*/
	this.addItem = function(itemId, itemText) {
		
		if (this.multiMode) {
			var lastVis = this._lastVisible();
		} else {
			
		}
		
		// adding new item
		var item = document.createElement("DIV");
		item.className = "dhx_acc_item";
		item.dir = "ltr";
		item._isAcc = true;
		item.skin = this.skin;
		this.base.appendChild(item);
		
		// set default height for multimode
		if (this.multiMode) item.h = this.itemH;
		
		
		// adding label
		
		var label = document.createElement("DIV");
		label._idd = itemId;
		label.className = "dhx_acc_item_label";
		label.innerHTML = "<span>"+itemText+"</span><div class='dhx_acc_item_label_btmbrd'>&nbsp;</div>"+
					"<div class='dhx_acc_item_arrow'></div>"+
					"<div class='dhx_acc_hdr_line_l'></div>"+
					"<div class='dhx_acc_hdr_line_r'></div>";
		label.onselectstart = function(e) { e = e||event; e.returnValue = false; }
		label.onclick = function() {
			// already opened item
			if (!that.multiMode && that.idPull[this._idd]._isActive) return;
			// multimode
			if (that.multiMode) {
				if (that.idPull[this._idd]._isActive) {
					if (that.checkEvent("onBeforeActive")) {
						if (that.callEvent("onBeforeActive", [this._idd, "close"])) that.closeItem(this._idd, "dhx_accord_outer_event");
					} else {
						that.closeItem(this._idd, "dhx_accord_outer_event");
					}
				} else {
					if (that.checkEvent("onBeforeActive")) {
						if (that.callEvent("onBeforeActive", [this._idd, "open"])) that.openItem(this._idd, "dhx_accord_outer_event");
					} else {
						that.openItem(this._idd, "dhx_accord_outer_event");
					}
				}
				if (that._autoHeightEnabled) that.setSizes();
				return;
			}
			// single mode
			if (that.checkEvent("onBeforeActive")) {
				if (that.callEvent("onBeforeActive", [this._idd, "open"])) that.openItem(this._idd, "dhx_accord_outer_event");
			} else {
				that.openItem(this._idd, "dhx_accord_outer_event");
			}
		}
		label.onmouseover = function() {
			this.className = "dhx_acc_item_label dhx_acc_item_lavel_hover";
		}
		label.onmouseout = function() {
			this.className = "dhx_acc_item_label";
		}
		item.appendChild(label);
		// content
		var contObj = document.createElement("DIV");
		contObj.className = "dhxcont_global_content_area";
		item.appendChild(contObj);
		var cont = new dhtmlXContainer(item);
		cont.setContent(contObj);
		
		if (this.skin == "dhx_terrace" && this._hideBorders === true) {
			item._setPadding([0,-1,2,0]); // top, left, width, height
		}
		
		item.adjustContent(item, this.sk["cell_height"]+this.sk["content_offset"]);
		
		
		// add to storage
		item._id = itemId;
		
		this.idPull[itemId] = item;
		/**
		*	@desc: returns item's id
		*	@type: public
		*/
		item.getId = function() {
			return this._id;
		}
		/**
		*	@desc: sets item's text
		*	@param: text - new text
		*	@type: public
		*/
		item.setText = function(text) {
			that.setText(this._id, text);
		}
		/**
		*	@desc: returns item's text
		*	@type: public
		*/
		item.getText = function() {
			return that.getText(this._id);
		}
		/**
		*	@desc: opens an item
		*	@type: public
		*/
		item.open = function() {
			that.openItem(this._id);
		}
		/**
		*	@desc: return true if item is opened
		*	@type: public
		*/
		item.isOpened = function() {
			return that.isActive(this._id);
		}
		/**
		*	@desc: closes an item
		*	@type: public
		*/
		item.close = function() {
			that.closeItem(this._id);
		}
		/**
		*	@desc: sets item's icon (header icon)
		*	@param: icon - filepath
		*	@type: public
		*/
		item.setIcon = function(icon) {
			that.setIcon(this._id, icon);
		}
		/**
		*	@desc: clears item's icon
		*	@type: public
		*/
		item.clearIcon = function() {
			that.clearIcon(this._id);
		}
		/**
		*	@desc: docks an item from a window
		*	@type: public
		*/
		item.dock = function() {
			that.dockItem(this._id);
		}
		/**
		*	@desc: undocks an item to a window
		*	@type: public
		*/
		item.undock = function() {
			that.undockItem(this._id);
		}
		/**
		*	@desc: shows an item
		*	@type: public
		*/
		item.show = function() {
			that.showItem(this._id);
		}
		/**
		*	@desc: hides an item
		*	@type: public
		*/
		item.hide = function() {
			that.hideItem(this._id);
		}
		/**
		*	@desc: set item's height for multimode
		*	@param: height - height for whole item (with header)
		*	@type: public
		*/
		item.setHeight = function(height) {
			that.setItemHeight(this._id, height);
		}
		item.moveOnTop = function() {
			that.moveOnTop(this._id);
		}
		//
		item._doOnAttachMenu = function() {
			that._reopenItem();
		}
		item._doOnAttachToolbar = function() {
			that._reopenItem();
		}
		item._doOnAttachStatusBar = function() {
			that._reopenItem();
		}
		// onContentLoaded event
		item._doOnFrameContentLoaded = function(){
			that.callEvent("onContentLoaded",[this]);
		}
		//
		if (this.multiMode && lastVis != null) {
			if (lastVis._isActive == true) {
				this.idPull[lastVis._id].adjustContent(this.idPull[lastVis._id], this.sk["cell_height"]+this.sk["content_offset"], null, null, this.sk["cell_space"]);
				this.idPull[lastVis._id].updateNestedObjects();
			} else {
				this.idPull[lastVis._id].style.height = this.sk["cell_height"]+this.sk["cell_space"]+"px";
			}
			lastVis = null;
		}
		
		//
		var e = this._enableOpenEffect;
		this._enableOpenEffect = false;
		
		this.openItem(itemId);
		
		this._enableOpenEffect = e;
		//
		if (!this.multiMode) this._defineLastItem(); else this.setSizes();
		//
		
		return item;
	}
	
	this.openItem = function(itemId, callEvent, reOpenItem) {
		if (this.multiMode) this._checkAutoHeight();
		// check if open/close state buzy
		if (this._openBuzy) return;
		// open with effect
		if (this._enableOpenEffect && !reOpenItem) {
			if (this.multiMode && this.idPull[itemId]._isActive) return;
			this._openWithEffect(itemId, null, null, null, null, callEvent);
			return;
		}
		// default open
		// multimode
		if (this.multiMode) {
			for (var a in this.idPull) {
				if (this.idPull[a]._isActive || a == itemId) {
					this.idPull[a].style.height = this.idPull[a].h+"px";
					this.idPull[a].childNodes[1].style.display = "";
					if (this.skin == "dhx_web") this.idPull[a]._setPadding(this.skinParams[this.skin]["cell_pading_max"], "dhxcont_acc_dhx_web");
					this.idPull[a].adjustContent(this.idPull[a], this.sk["cell_height"]+this.sk["content_offset"], null, null, (this.idPull[a]==this._lastVisible()&&this.skin!="dhx_web"?0:this.sk["cell_space"]));
					this.idPull[a].updateNestedObjects();
					this.idPull[a]._isActive = true;
					this._updateArrows();
					if (callEvent == "dhx_accord_outer_event" && a == itemId) this.callEvent("onActive", [itemId,true]);
				}
			}
			return;
		}
		// single mode
		// already active
		if (itemId) {
			if (this.idPull[itemId]._isActive && !reOpenItem) return;
		}
		// calculate available height
		var h = 0;
		for (var a in this.idPull) {
			this.idPull[a].style.height = this.sk["cell_height"]+(this.idPull[a]!=this._lastVisible()&&a!=itemId?this.sk["cell_space"]:0)+"px";
			if (a != itemId) {
				this.idPull[a].childNodes[1].style.display = "none";
				if (this.skin == "dhx_web") this.idPull[a]._setPadding(this.skinParams[this.skin]["cell_pading_min"], "");
				this.idPull[a]._isActive = false;
				h += this.idPull[a].offsetHeight;
			}
		}
		h = this.base.offsetHeight - h;
		// open item if it set (redraw struc call available only if no item set)
		if (itemId) {
			this.idPull[itemId].style.height = h+"px";
			this.idPull[itemId].childNodes[1].style.display = "";
			if (this.skin == "dhx_web") this.idPull[itemId]._setPadding(this.skinParams[this.skin]["cell_pading_max"], "dhxcont_acc_dhx_web");
			this.idPull[itemId].adjustContent(this.idPull[itemId], this.sk["cell_height"]+this.sk["content_offset"], null, null, (this.idPull[itemId]==this._lastVisible()?0:this.sk["cell_space"]));
			this.idPull[itemId].updateNestedObjects();
			this.idPull[itemId]._isActive = true;
			if (callEvent == "dhx_accord_outer_event") this.callEvent("onActive", [itemId,true]);
		}
		this._updateArrows();
		return;
	}
	
	// return last visible item (used for correct skin render)
	this._lastVisible = function() {
		var item = null;
		for (var q=this.base.childNodes.length-1; q>=0; q--) if (!this.base.childNodes[q]._isHidden && !item) item = this.base.childNodes[q];
		return item;
	}
	
	this.closeItem = function(itemId, callEvent) {
		if (this.idPull[itemId] == null) return;
		if (!this.idPull[itemId]._isActive) return;
		// check if open/close state buzy
		if (this._openBuzy) return;
		if (this._enableOpenEffect) {
			// multimode, switch state
			// default mode, close active, open none
			this._openWithEffect(this.multiMode?itemId:null, null, null, null, null, callEvent);
			return;
		}
		// default close
		this.idPull[itemId].style.height = this.sk["cell_height"]+(this.idPull[itemId]!=this._lastVisible()?this.sk["cell_space"]:0)+"px";
		this.idPull[itemId].childNodes[1].style.display = "none";
		if (this.skin == "dhx_web") this.idPull[itemId]._setPadding(this.skinParams[this.skin]["cell_pading_min"], "");
		this.idPull[itemId]._isActive = false;
		if (callEvent == "dhx_accord_outer_event") this.callEvent("onActive", [itemId,false]);
		this._updateArrows();
	}
	
	this._updateArrows = function() {
		for (var a in this.idPull) {
			var label = this.idPull[a].childNodes[0];
			var arrow = null;
			for (var q=0; q<label.childNodes.length; q++) {
				if (String(label.childNodes[q].className).search("dhx_acc_item_arrow") != -1) arrow = label.childNodes[q];
			}
			if (arrow != null) {
				arrow.className = "dhx_acc_item_arrow "+(this.idPull[a]._isActive?"item_opened":"item_closed");
				arrow = null;
			}
		}
	}
	
	this.setText = function(itemId, itemText, moveLabel) {
		if (that.idPull[itemId] == null) return;
		var label = that.idPull[itemId].childNodes[0];
		var tObj = null;
		for (var q=0; q<label.childNodes.length; q++) {
			if (label.childNodes[q].tagName != null) {
				if (String(label.childNodes[q].tagName).toLowerCase() == "span") tObj = label.childNodes[q];
			}
		}
		if (!isNaN(moveLabel)) {
			tObj.style.paddingLeft = moveLabel+"px";
			tObj.style.paddingRight = moveLabel+"px";
		} else {
			tObj.innerHTML = itemText;
		}
	}
	
	this.getText = function(itemId) {
		if (that.idPull[itemId] == null) return;
		var label = that.idPull[itemId].childNodes[0];
		var tObj = null;
		for (var q=0; q<label.childNodes.length; q++) {
			if (label.childNodes[q].tagName != null) {
				if (String(label.childNodes[q].tagName).toLowerCase() == "span") tObj = label.childNodes[q];
			}
		}
		return tObj.innerHTML;
	}
	
	this._initWindows = function(id) {
		if (!window.dhtmlXWindows) return;
		if (!this.dhxWins) {
			this.dhxWins = new dhtmlXWindows();
			this.dhxWins.setSkin(this.skin);
			this.dhxWins.setImagePath(this.imagePath);
			this.dhxWinsIdPrefix = "";//this.cont.obj._genStr(12);
			if (!id) return;
		}
		var idd = this.dhxWinsIdPrefix+id;
		if (!this.dhxWins.window(idd)) {
			var self = this;
			var w1 = this.dhxWins.createWindow(idd, 20, 20, 320, 200);
			w1.setText(this.getText(id));
			w1.button("close").hide();
			w1.attachEvent("onClose", function(win){win.hide();});
			w1.addUserButton("dock", 99, this.dhxWins.i18n.dock, "dock");
			w1.button("dock").attachEvent("onClick", function(win){self.cells(id).dock();});
			//w1.dockedCell = this.polyObj[id];
		} else {
			this.dhxWins.window(idd).show();
		}
		// this.dhxWins.dhxLayout = this;
	}
	
	this.dockWindow = function(itemId) {
		if (!this.idPull[itemId]._isUnDocked) return;
		if (!this.dhxWins) return;
		if (!this.dhxWins.window(this.dhxWinsIdPrefix+itemId)) return;
		this.dhxWins.window(this.dhxWinsIdPrefix+itemId).moveContentTo(this.idPull[itemId]);
		this.dhxWins.window(this.dhxWinsIdPrefix+itemId).close();
		this.idPull[itemId]._isUnDocked = false;
		this.showItem(itemId);
		this.callEvent("onDock", [itemId]);
	}
	
	this.undockWindow = function(itemId) {
		if (this.idPull[itemId]._isUnDocked) return;
		this._initWindows(itemId);
		this.idPull[itemId].moveContentTo(this.dhxWins.window(this.dhxWinsIdPrefix+itemId));
		this.idPull[itemId]._isUnDocked = true;
		this.hideItem(itemId);
		this.callEvent("onUnDock", [itemId]);
	}
	
	/**
	*	@desc: changes object instance's size according to the outer container
	*	@type: public
	*/
	this.setSizes = function() {
		this._reopenItem();
	}
	
	this.showItem = function(itemId) {
		if (this.idPull[itemId] == null) return;
		if (!this.idPull[itemId]._isHidden) return;
		if (this.idPull[itemId]._isUnDocked) {
			this.dockItem(itemId);
			return;
		}
		this.idPull[itemId].className = "dhx_acc_item";
		this.idPull[itemId]._isHidden = false;
		this._defineLastItem();
		this._reopenItem();
	}
	
	this.hideItem = function(itemId) {
		if (this.idPull[itemId] == null) return;
		if (this.idPull[itemId]._isHidden) return;
		this.closeItem(itemId);
		this.idPull[itemId].className = "dhx_acc_item_hidden";
		this.idPull[itemId]._isHidden = true;
		this._defineLastItem();
		this._reopenItem();
	}
	
	this.isItemHidden = function(itemId) {
		if (this.idPull[itemId] == null) return;
		return (this.idPull[itemId]._isHidden == true);
	}
	
	this._reopenItem = function() {
		var toOpen = null;
		for (var a in this.idPull) if (this.idPull[a]._isActive && !this.idPull[a]._isHidden) toOpen = a;
		this.openItem(toOpen, null, true);
	}
	
	/**
	*	@desc: iterator, calls a user-defined function n-times
	*	@param: handler - user defined-function, item's object is passed as an incoming argument
	*	@type: public
	*/
	this.forEachItem = function(handler) {
		for (var a in this.idPull) handler(this.idPull[a]);
	}
	
	this._enableOpenEffect = false;
	this._openStep = 10;
	this._openStepIncrement = 5;
	this._openStepTimeout = 10;
	
	this._openBuzy = false;
	
	this.setEffect = function(state) {
		this._enableOpenEffect = (state==true?true:false);
	}
	
	this._openWithEffect = function(toOpen, toClose, minH, maxH, step, callEvent) {
		// multimode
		if (this.multiMode) {
			// first call
			if (!step) {
				this._openBuzy = true;
				step = this._openStep;
				// check if item shoul be opened/closed
				if (this.idPull[toOpen]._isActive) {
					// item shoul be closed
					toClose = toOpen;
					toOpen = null;
					minH = this.sk["cell_height"]+(this.idPull[toClose]!=this._lastVisible()?this.sk["cell_space"]:0);
					this.idPull[toClose].childNodes[1].style.display = "";
				} else {
					// item should be opened
					maxH = this.idPull[toOpen].h;
					this.idPull[toOpen].childNodes[1].style.display = "";
				}
			}
			var stopOpen = false;
			// opening item
			if (toOpen) {
				var newH = parseInt(this.idPull[toOpen].style.height||0)+step;
				if (newH > maxH) { newH = maxH; stopOpen = true; }
				this.idPull[toOpen].style.height = newH+"px";
			}
			// closing item
			if (toClose) {
				var newH = parseInt(this.idPull[toClose].style.height)-step;
				if (newH < minH) { newH = minH; stopOpen = true; }
				this.idPull[toClose].style.height = newH+"px";
			}
			step += this._openStepIncrement;
			if (stopOpen) {
				if (toOpen) {
					this.idPull[toOpen].adjustContent(this.idPull[toOpen], this.sk["cell_height"]+this.sk["content_offset"], null, null, (this.idPull[toOpen]==this._lastVisible()?0:this.sk["cell_space"]));
					this.idPull[toOpen].updateNestedObjects();
					this.idPull[toOpen]._isActive = true;
				}
				if (toClose) {
					this.idPull[toClose].childNodes[1].style.display = "none";
					this.idPull[toClose]._isActive = false;
				}
				this._updateArrows();
				this._openBuzy = false;
				// events
				if (toOpen && callEvent == "dhx_accord_outer_event") this.callEvent("onActive", [toOpen,true]);
				if (toClose && callEvent == "dhx_accord_outer_event") this.callEvent("onActive", [toClose,false]);
			} else {
				var that = this;
				window.setTimeout(function(){that._openWithEffect(toOpen, toClose, minH, maxH, step, callEvent);},this._openStepTimeout);
			}
			return;
		}
		// default mode
		// first call
		if (!step) {
			this._openBuzy = true;
			step = this._openStep;
			if (toOpen) this.idPull[toOpen].childNodes[1].style.display = "";
		}
		if (!toClose || !minH || !maxH) {
			minH = 0;
			maxH = 0;
			// detect toClose and min/max height for cells
			for (var a in this.idPull) {
				var th = this.sk["cell_height"]+(this.idPull[a]!=this._lastVisible()&&a!=toOpen?this.sk["cell_space"]:0); // same as in somple open
				if (this.idPull[a]._isActive && toOpen != a) { toClose = a; minH = th; }
				if (a != toOpen) maxH += th;
			}
			maxH = this.base.offsetHeight - maxH;
		}
		var stopOpen = false;
		if (toOpen) {
			// define new toOpen size
			var ha = parseInt(this.idPull[toOpen].style.height)+step;
			if (ha > maxH) stopOpen = true;
		}
		if (toClose) {
			// define new toClose size
			var hb = parseInt(this.idPull[toClose].style.height)-step;
			if (hb < minH) stopOpen = true;
		}
		step += this._openStepIncrement;
		if (stopOpen) {
			// set min/max sizes when open finished
			ha = maxH;
			hb = minH;
		}
		if (toClose) this.idPull[toClose].style.height = hb+"px";
		if (toOpen) this.idPull[toOpen].style.height = ha+"px";
		if (stopOpen) {
			if (toClose) {
				this.idPull[toClose].childNodes[1].style.display = "none";
				this.idPull[toClose]._isActive = false;
			}
			if (toOpen) {
				this.idPull[toOpen].adjustContent(this.idPull[toOpen], this.sk["cell_height"]+this.sk["content_offset"], null, null, (this.idPull[toOpen]==this._lastVisible()?0:this.sk["cell_space"]));
				this.idPull[toOpen].updateNestedObjects();
				this.idPull[toOpen]._isActive = true;
			}
			this._updateArrows();
			this._openBuzy = false;
			if (callEvent == "dhx_accord_outer_event" && toOpen) this.callEvent("onActive", [toOpen,true]);
		} else {
			var that = this;
			window.setTimeout(function(){that._openWithEffect(toOpen, toClose, minH, maxH, step, callEvent);},this._openStepTimeout);
		}
	}
	
	this.setActive = function(itemId) {
		this.openItem(itemId);
	}
	this.isActive = function(itemId) {
		return (this.idPull[itemId]._isActive === true?true:false);
	}
	this.dockItem = function(itemId) {
		this.dockWindow(itemId);
	}
	
	this.undockItem = function(itemId) {
		this.undockWindow(itemId);
	}
	
	this.setItemHeight = function(itemId, height) {
		if (!this.multiMode) return;
		if (height == "*") {
			this.idPull[itemId].h_auto = true;
		} else {
			if (isNaN(height)) return;
			this.idPull[itemId].h_auto = false;
			this.idPull[itemId].h = height;
		}
		this._reopenItem();
	}
	
	this._checkAutoHeight = function() {
		
		var h = this.base.offsetHeight; // main parent
		
		this._autoHeightEnabled = false;
		
		// find items with * and check avail size for them
		var k = [];
		for (var a in this.idPull) {
			
			if (!this._autoHeightEnabled && this.idPull[a].h_auto) this._autoHeightEnabled = true;
			
			if (this.idPull[a].h_auto && this.idPull[a]._isActive) {
				k.push(a);
			} else {
				if (this.idPull[a]._isActive) {
					h = Math.max(0, h-this.idPull[a].h);
				} else {
					h = Math.max(0, h-this.idPull[a].offsetHeight);
				}
			}
		}
		
		if (k.length > 0) {
			var h1 = Math.floor(h/k.length);
			for (var q=0; q<k.length; q++) {
				if (q == k.length-1) h1 = h; else h -= h1; // last item will take all height
				this.idPull[k[q]].h = h1;
				
			}
		}
		
	}
	
	this.setIcon = function(itemId, icon) {
		if (this.idPull[itemId] == null) return;
		var label = this.idPull[itemId].childNodes[0];
		var iconObj = null;
		for (var q=0; q<label.childNodes.length; q++) {
			if (label.childNodes[q].className == "dhx_acc_item_icon") iconObj = label.childNodes[q];
		}
		if (iconObj == null) {
			iconObj = document.createElement("IMG");
			iconObj.className = "dhx_acc_item_icon";
			label.insertBefore(iconObj, label.childNodes[0]);
			// move label to right
			this.setText(itemId, null, 20);
		}
		iconObj.src = this.imagePath+icon;
	}
	
	this.clearIcon = function(itemId) {
		if (this.idPull[itemId] == null) return;
		var label = this.idPull[itemId].childNodes[0];
		var iconObj = null;
		for (var q=0; q<label.childNodes.length; q++) {
			if (label.childNodes[q].className == "dhx_acc_item_icon") iconObj = label.childNodes[q];
		}
		if (iconObj != null) {
			label.removeChild(iconObj);
			iconObj = null;
			// move label to right
			this.setText(itemId, null, 0);
		}
	}
	
	this.moveOnTop = function(itemId) {
		if (!this.idPull[itemId]) return;
		if (this.base.childNodes.length <= 1) return;
		this.base.insertBefore(this.idPull[itemId], this.base.childNodes[0])
		this.setSizes();
	}
	
	this._defineLastItem = function() {
		
		if (this.multiMode) return;
		
		var done = false;
		for (var q=this.base.childNodes.length-1; q>=0; q--) {
			
			if ((this.base.childNodes[q].className).search("last_item") >= 0) {
				
				if (this.base.childNodes[q]._isHidden || done) {
					this.base.childNodes[q].className = String(this.base.childNodes[q].className).replace(/last_item/gi,"");
				} else {
					done = true;
				}
				
			} else {
				
				if (!this.base.childNodes[q]._isHidden && !done) {
					this.base.childNodes[q].className += " last_item";
					done = true;
				}
				
			}
		}
		
		
	}
	
	/**
	*	@desc: remove an existing item
	*	@param: itemId - item's id
	*	@type: public
	*/
	this.removeItem = function(itemId) {
		var item = this.idPull[itemId];
		var label = item.childNodes[0];
		label.onclick = null;
		label.onmouseover = null;
		label.onmouseout = null;
		label.onselectstart = null;
		label._idd = null;
		label.className = "";
		item._dhxContDestruct();
		while (label.childNodes.length > 0) label.removeChild(label.childNodes[0]);
		if (label.parentNode) label.parentNode.removeChild(label);
		label = null;
		while (item.childNodes.length > 0) item.removeChild(item.childNodes[0]);
		item._dhxContDestruct = null;
		item._doOnAttachMenu = null;
		item._doOnAttachToolbar = null;
		item._doOnAttachStatusBar = null;
		item.clearIcon = null;
		item.close = null;
		item.dock = null;
		item.getId = null;
		item.getText = null;
		item.hide = null;
		item.isOpened = null;
		item.open = null;
		item.setHeight = null;
		item.setIcon = null;
		item.setText = null;
		item.show = null;
		item.undock = null;
		if (item.parentNode) item.parentNode.removeChild(item);
		item = null;
		
		this.idPull[itemId] = null;
		try { delete this.idPull[itemId]; } catch(e){}
		
	}
	
	this.unload = function() {
		for (var a in this.skinParams) {
			this.skinParams[a] = null;
			try { delete this.skinParams[a]; } catch(e){}
		}
		this.skinParams = null;
		// remove items
		for (var a in this.idPull) this.removeItem(a);
		this.idPull = null;
		//
		this.sk = null;
		this._initWindows = null;
		this._lastVisible = null;
		this._reopenItem = null;
		this._updateArrows = null;
		this.addItem = null;
		this.attachEvent = null;
		this.callEvent = null;
		this.cells = null;
		this.checkEvent = null;
		this.clearIcon = null;
		this.closeItem = null;
		this.detachEvent = null;
		this.dockItem = null;
		this.dockWindow = null;
		this.enableMultiMode = null;
		this.eventCatcher = null;
		this.forEachItem = null;
		this.getText = null;
		this.h = null;
		this.hideItem = null;
		this.imagePath = null;
		this.isActive = null;
		this.itemH = null;
		this.multiMode = null;
		this.openItem = null;
		this.removeItem = null;
		this.setActive = null;
		this.setEffect = null;
		this.setIcon = null;
		this.setIconsPath = null;
		this.setItemHeight = null;
		this.setOffset = null;
		this.setSizes = null;
		this.setSkin = null;
		this.setSkinParameters = null;
		this.setText = null;
		this.showItem = null;
		this.skin = null;
		this.w = null;
		this.undockItem = null;
		this.undockWindow = null;
		this.undockWindowunload = null;
		this.unload = null;
		this.userOffset = null;
		//
		
		if (this._isAccFS == true) {
			
			if (typeof(window.addEventListener) == "function") {
				window.removeEventListener("resize", this._doOnResize, false);
			} else {
				window.detachEvent("onresize", this._doOnResize);
			}
			this._isAccFS = null;
			this._doOnResize = null;
			this._adjustAccordion = null;
			this._adjustToFullScreen = null;
			this._resizeTM = null;
			this._resizeTMTime = null;
			document.body.className = String(document.body.className).replace("dhxacc_fullscreened","");
			//
			this.cont.obj._dhxContDestruct();
			if (this.cont.dhxcont.parentNode) this.cont.dhxcont.parentNode.removeChild(this.cont.dhxcont);
			this.cont.dhxcont = null;
			this.cont.setContent = null;
			this.cont = null;
		}
		
		if (this.dhxWins) {
			this.dhxWins.unload();
			this.dhxWins = null;
		}
		
		this.base.className = "";
		this.base = null;
		
		for (var a in this) try { delete this[a]; } catch(e){};
	}
	
	this._initWindows();
	dhtmlxEventable(this);
	
	return this;
	
};

dhtmlXAccordion.prototype.i18n = {
	dhxcontalert: "dhtmlxcontainer.js is missed on the page"
};

//accordion
(function(){
	dhtmlx.extend_api("dhtmlXAccordion",{
		_init:function(obj){
			return [obj.parent, obj.skin];
		},
		icon_path:"setIconsPath",
		items:"_items",
		effect: "setEffect",
		multi_mode:"enableMultiMode"
	},{
		_items:function(arr){
			var toOpen = [];
			var toClose = [];
			for (var i=0; i < arr.length; i++) {
				var item=arr[i];
				this.addItem(item.id, item.text);
				if (item.img) this.cells(item.id).setIcon(item.img);
				if (item.height) this.cells(item.id).setHeight(item.height);
				if (item.open === true) toOpen[toOpen.length] = item.id;
				if (item.open === false) toClose[toClose.length] = item.id;
			}
			for (var q=0; q<toOpen.length; q++) this.cells(toOpen[q]).open();
			for (var q=0; q<toClose.length; q++) this.cells(toClose[q]).close();
		}
	});
})();

dhtmlXAccordion.prototype.loadJSON = function(t) {
	
	// main params
	var k = {skin:"setSkin",icons_path:"setIconsPath",multi_mode:"enableMultiMode",effect:"setEffect"};
	for (var a in k) if (typeof(t[a]) != "undefined") this[k[a]](t[a]);
	
	// cells
	var toOpen = null;
	for (var q=0; q<t.cells.length; q++) {
		this.addItem(t.cells[q].id, t.cells[q].text);
		if (typeof(t.cells[q].icon) != "undefined") this.setIcon(t.cells[q].id, t.cells[q].icon);
		if (typeof(t.cells[q].height) != "undefined") this.setItemHeight(t.cells[q].id, t.cells[q].height);
		if (typeof(t.cells[q].open) != "undefined") toOpen = t.cells[q].id;
	}
	
	if (toOpen != null) this.openItem(toOpen);
	
};

dhtmlXAccordion.prototype.loadXML = function(url, onLoad) {
	
	var that = this;
	
	this.callEvent("onXLS", []);
	
	dhtmlxAjax.get(url, function(r){
		// init
		var root = r.xmlDoc.responseXML.getElementsByTagName("accordion")[0];
		
		var k = {0:false,"true":true,"1":true,"y":true,"yes":true};
		
		var t = {cells:[]};
		// conf
		if (root.getAttribute("skin") != null) t.skin = root.getAttribute("skin"); //that.setSkin(root.getAttribute("skin"));
		if (root.getAttribute("iconsPath") != null) t.icons_path = root.getAttribute("iconsPath"); //that.setIconsPath(root.getAttribute("iconsPath"));
		if (root.getAttribute("mode") == "multi") t.multi_mode = true;//that.enableMultiMode(true);
		if (k[root.getAttribute("openEffect")||0]) t.effect = true; //that.setEffect(true);
		
		// cells
		var toOpen = null;
		for (var q=0; q<root.childNodes.length; q++) {
			if (typeof(root.childNodes[q].tagName) != "indefined" && String(root.childNodes[q].tagName).toLowerCase() == "cell") {
				var id = (root.childNodes[q].getAttribute("id")||that._genStr(12));
				var text = (root.childNodes[q].firstChild.nodeValue||"");
				t.cells.push({id:id,text:text});
				
				if (root.childNodes[q].getAttribute("icon") != null) t.cells[t.cells.length-1].icon = root.childNodes[q].getAttribute("icon");
				if (root.childNodes[q].getAttribute("height") != null) t.cells[t.cells.length-1].height = root.childNodes[q].getAttribute("height");
				if (k[root.childNodes[q].getAttribute("open")||0]) t.cells[t.cells.length-1].open = true;
			}
		}
		that.loadJSON(t);
		
		// callbacks
		that.callEvent("onXLE",[]);
		if (typeof(onLoad) == "function") onLoad();
		that = onLoad = null;
	});
	
};
