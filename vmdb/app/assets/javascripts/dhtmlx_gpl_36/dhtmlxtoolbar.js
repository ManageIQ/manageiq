//v.3.6 build 131108

/*
Copyright DHTMLX LTD. http://www.dhtmlx.com
You allowed to use this component or parts of it under GPL terms
To use it on other terms or get Professional edition of the component please contact us at sales@dhtmlx.com
*/
/**
*   @desc: constructor, creates a new dhtmlxToolbar object
*   @param: baseId - id of html element to which webmenu will attached
*   @type: public
*/
function dhtmlXToolbarObject(baseId, skin) {
	
	var main_self = this;
	
	this.cont = (typeof(baseId)!="object")?document.getElementById(baseId):baseId;
	while (this.cont.childNodes.length > 0) this.cont.removeChild(this.cont.childNodes[0]);
	
	this.cont.dir = "ltr";
	this.cont.innerHTML += "<div class='dhxtoolbar_hdrline_ll'></div><div class='dhxtoolbar_hdrline_rr'></div>"+
				"<div class='dhxtoolbar_hdrline_l'></div><div class='dhxtoolbar_hdrline_r'></div>";
	
	this.base = document.createElement("DIV");
	this.base.className = "float_left";
	this.cont.appendChild(this.base);
	
	this.align = "left";
	this.setAlign = function(align) {
		this.align = (align=="right"?"right":"left");
		this.base.className = (align=="right"?"float_right":"float_left");
		if (this._spacer) this._spacer.className = "dhxtoolbar_spacer "+(align=="right"?" float_left":" float_right");
	}
	
	this._isIE6 = false;
	if (_isIE) this._isIE6 = (window.XMLHttpRequest==null?true:false);
	
	this._isIPad = (navigator.userAgent.search(/iPad/gi)>=0);
	
	if (this._isIPad) {
		this.cont.ontouchstart = function(e){
			e = e||event;
			if((String(e.target.tagName||"").toLowerCase()=="input"))
				return true;
			e.returnValue = false;
			e.cancelBubble = true;
			return false;
		}
	}
	
	this.iconSize = 18;
	this.setIconSize = function(size) {
		this.iconSize = ({18:true,24:true,32:true,48:true}[size]?size:18);
		this.setSkin(this.skin, true);
		this.callEvent("_onIconSizeChange",[this.iconSize]);
	}
	
	this.selectPolygonOffsetTop = 0;
	this.selectPolygonOffsetLeft = 0;
	
	this._improveTerraceSkin = function() {
		
		var p = [];
		var bn = {buttonInput: true, separator: true, text: true}; // border-less items
		
		var e = [this.base];
		if (this._spacer != null) e.push(this._spacer);
		for (var w=0; w<e.length; w++) {
			p[w] = [];
			for (var q=0; q<e[w].childNodes.length; q++) {
				if (e[w].childNodes[q].idd != null && e[w].childNodes[q].style.display != "none") {
					var a = this.idPrefix+e[w].childNodes[q].idd;
					if (this.objPull[a] != null && this.objPull[a].obj == e[w].childNodes[q]) {
						p[w].push({a:a,type:this.objPull[a].type,node:this.objPull[a][this.objPull[a].type=="buttonSelect"?"arw":"obj"]});
					}
				}
			}
			e[w] = null;
		}
		
		for (var w=0; w<p.length; w++) {
			for (var q=0; q<p[w].length; q++) {
			
				var t = p[w][q];
			
				if (t.type == "buttonInput") {
					t.node.className = t.node.className.replace(/dhx_toolbar_btn/,"dhx_toolbar_inp");
				}
				
				// check if border-right/border-left needed
				var br = false;
				var bl = false;
				
				if (!bn[t.type]) {
					
					// right side - check if item last-child or next-sibling is borderless item
					if (q == p[w].length-1 || (p[w][q+1] != null && bn[p[w][q+1].type])) br = true;
					
					// left side, check if item first-child or prev-sibling is borderless item
					if (q == 0 || (q-1 >= 0 && p[w][q-1] != null && bn[p[w][q-1].type])) bl = true;
					
				}
				
				t.node.style.borderRight = (br?"1px solid #cecece":"0px solid white");
				t.node.style.borderTopRightRadius = t.node.style.borderBottomRightRadius = (br?"5px":"0px");
				
				if (t.type == "buttonSelect") {
					t.node.previousSibling.style.borderTopLeftRadius = t.node.previousSibling.style.borderBottomLeftRadius = (bl?"5px":"0px");
					t.node.previousSibling._br = br;
					t.node.previousSibling._bl = bl;
				} else {
					t.node.style.borderTopLeftRadius = t.node.style.borderBottomLeftRadius = (bl?"5px":"0px");
				}
				
				t.node._br = br;
				t.node._bl = bl;
				
			}
		}
		
		for (var w=0; w<p.length; w++) {
			for (var q=0; q<p[w].length; q++) {
				for (var a in p[w][q]) p[w][q][a] = null;
				p[w][q] = null;
			}
			p[w] = null;
		}
		
		p = e = null;
	}
	
	// enable/disable riunded corners when sublist opened
	this._improveTerraceButtonSelect = function(id, state) {
		var item = this.objPull[id];
		if (state == true) {
			item.obj.style.borderBottomLeftRadius = (item.obj._bl?"5px":"0px");
			item.arw.style.borderBottomRightRadius = (item.obj._br?"5px":"0px");
		} else {
			item.obj.style.borderBottomLeftRadius = "0px";
			item.arw.style.borderBottomRightRadius = "0px";
		}
		item = null;
	}
	
	this.setSkin = function(skin, onlyIcons) {
		if (onlyIcons === true) {
			// prevent of removing skin postfixes when attached to layout/acc/etc
			this.cont.className = this.cont.className.replace(/dhx_toolbar_base_\d{1,}_/,"dhx_toolbar_base_"+this.iconSize+"_");
		} else {
			this.skin = skin;
			if (this.skin == "dhx_skyblue") {
				this.selectPolygonOffsetTop = 1;
			}
			if (this.skin == "dhx_web") {
				this.selectPolygonOffsetTop = 1;
				this.selectPolygonOffsetLeft = 1;
			}
			if (this.skin == "dhx_terrace") {
				this.selectPolygonOffsetTop = -1;
				this.selectPolygonOffsetLeft = 0;
			}
			this.cont.className = "dhx_toolbar_base_"+this.iconSize+"_"+this.skin+(this.rtl?" rtl":"");
		}
		
		for (var a in this.objPull) {
			var item = this.objPull[a];
			if (item["type"] == "slider") {
				item.pen._detectLimits();
				item.pen._definePos();
				item.label.className = "dhx_toolbar_slider_label_"+this.skin+(this.rtl?" rtl":"");
			}
			if (item["type"] == "buttonSelect") {
				item.polygon.className = "dhx_toolbar_poly_"+this.iconSize+"_"+this.skin+(this.rtl?" rtl":"");
			}
		}
		if (skin == "dhx_terrace") this._improveTerraceSkin();
	}
	this.setSkin(skin != null ? skin : (typeof(dhtmlx) != "undefined" && typeof(dhtmlx.skin) == "string" ? dhtmlx.skin : "dhx_skyblue"));
	
	this.objPull = {};
	this.anyUsed = "none";
	
	/* images */
	this.imagePath = "";
	/**
	*   @desc: set path to used images
	*   @param: path - path to images on harddisk
	*   @type: public
	*/
	this.setIconsPath = function(path) { this.imagePath = path; }
	/**
	*   @desc: alias of setIconsPath
	*   @type: public
	*/
	this.setIconPath = this.setIconsPath;
	/* load */
	this._doOnLoad = function() {}
	/**
	*   @desc: loads data to object from xml file
	*   @param: xmlFile - file with dta to load
	*   @param: onLoadFunction - function to call after data will loaded
	*   @type: public
	*/
	this.loadXML = function(xmlFile, onLoadFunction) {
		if (onLoadFunction != null) this._doOnLoad = function() { onLoadFunction(); }
		this.callEvent("onXLS", []);
		this._xmlLoader = new dtmlXMLLoaderObject(this._xmlParser, window);
		this._xmlLoader.loadXML(xmlFile);
	}
	/**
	*   @desc: loads data to object from xml string
	*   @param: xmlString - xml string with data to load
	*   @param: onLoadFunction - function to call after data will loaded
	*   @type: public
	*/
	this.loadXMLString = function(xmlString, onLoadFunction) {
		if (onLoadFunction != null) { this._doOnLoad = function() { onLoadFunction(); } }
		this._xmlLoader = new dtmlXMLLoaderObject(this._xmlParser, window);
		this._xmlLoader.loadXMLString(xmlString);
	}
	this._xmlParser = function() {
		var root = this.getXMLTopNode("toolbar");
		/*
			common: id, type
			---
			separator: hidden, title
			text: hidden, title, text
			button: enabled, img, imgdis, hidden, action, title, text
			buttonSelect: enabled, img, imgdis, hidden, action, title, openAll, renderSelect, text
			input: hidden, width, title, value
			buttonTwoState: enabled, img, imgdis, selected, action, title, text
			slider: enabled, length, textMin, textMax, toolTip, valueMin, valueMax, valueNow
			---
			buttonSelect nested item: enabled, disabled, action, selected, img, text, itemText(nested), userdata(nested)
			
		*/
		var t = ["id", "type", "hidden", "title", "text", "enabled", "img", "imgdis", "action", "openAll", "renderSelect", "mode", "maxOpen", "width", "value", "selected", "length", "textMin", "textMax", "toolTip", "valueMin", "valueMax", "valueNow"];
		var p = ["id", "type", "enabled", "disabled", "action", "selected", "img", "text"];
		//
		for (var q=0; q<root.childNodes.length; q++) {
			if (root.childNodes[q].tagName == "item") {
				var itemData = {};
				for (var w=0; w<t.length; w++) itemData[t[w]] = root.childNodes[q].getAttribute(t[w]);
				
				itemData.items = [];
				itemData.userdata = [];
				
				for (var e=0; e<root.childNodes[q].childNodes.length; e++) {
					if (root.childNodes[q].childNodes[e].tagName == "item" && itemData.type == "buttonSelect") {
						var u = {};
						for (var w=0; w<p.length; w++) u[p[w]] = root.childNodes[q].childNodes[e].getAttribute(p[w]);
						var t0 = root.childNodes[q].childNodes[e].getElementsByTagName("itemText");
						if (t0 != null && t0[0] != null) u.itemText = t0[0].firstChild.nodeValue;
						// listed options userdata
						var h = root.childNodes[q].childNodes[e].getElementsByTagName("userdata");
						for (var w=0; w<h.length; w++) {
							if (!u.userdata) u.userdata = {};
							var r = {};
							try { r.name = h[w].getAttribute("name"); } catch(k) { r.name = ""; }
							try { r.value = h[w].firstChild.nodeValue; } catch(k) { r.value = ""; }
							if (r.name != "") u.userdata[r.name] = r.value;
						}
						//
						itemData.items[itemData.items.length] = u;
					}
					// items userdata
					if (root.childNodes[q].childNodes[e].tagName == "userdata") {
						var u = {};
						try { u.name = root.childNodes[q].childNodes[e].getAttribute("name"); } catch(k) { u.name = ""; }
						try { u.value = root.childNodes[q].childNodes[e].firstChild.nodeValue; } catch(k) { u.value = ""; }
						itemData.userdata[itemData.userdata.length] = u;
					}
				}
				main_self._addItemToStorage(itemData);
			}
		}
		if (main_self.skin == "dhx_terrace") main_self._improveTerraceSkin();
		main_self.callEvent("onXLE", []);
		main_self._doOnLoad();
		this.destructor();
	}
	this._addItemToStorage = function(itemData, pos) {
		var id = (itemData.id||this._genStr(24));
		var type = (itemData.type||"");
		if (type != "") {
			if (this["_"+type+"Object"] != null) {
				if ((typeof(itemData.openAll) == "undefined" || itemData.openAll == null) && this.skin == "dhx_terrace") itemData.openAll = true;
				this.objPull[this.idPrefix+id] = new this["_"+type+"Object"](this, id, itemData);
				this.objPull[this.idPrefix+id]["type"] = type;
				this.setPosition(id, pos);
			}
		}
		// userdata
		if (itemData.userdata) { for (var q=0; q<itemData.userdata.length; q++) this.setUserData(id, itemData.userdata[q].name, itemData.userdata[q].value); }
	}
	/* random prefix */
	this._genStr = function(w) {
		var s = ""; var z = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
		for (var q=0; q<w; q++) s += z.charAt(Math.round(Math.random() * (z.length-1)));
		return s;
	}
	this.rootTypes = new Array("button", "buttonSelect", "buttonTwoState", "separator", "label", "slider", "text", "buttonInput");
	this.idPrefix = this._genStr(12);
	//
	dhtmlxEventable(this);
	//
	// return obj if exists by tagname
	this._getObj = function(obj, tag) {
		var targ = null;
		for (var q=0; q<obj.childNodes.length; q++) {
			if (obj.childNodes[q].tagName != null) {
				if (String(obj.childNodes[q].tagName).toLowerCase() == String(tag).toLowerCase()) targ = obj.childNodes[q];
			}
		}
		return targ;
	}
	// create and return image object
	this._addImgObj = function(obj) {
		var imgObj = document.createElement("IMG");
		if (obj.childNodes.length > 0) obj.insertBefore(imgObj, obj.childNodes[0]); else obj.appendChild(imgObj);
		return imgObj;
	}
	// set/clear item image/imagedis
	this._setItemImage = function(item, url, dis) {
		if (dis == true) item.imgEn = url; else item.imgDis = url;
		if ((!item.state && dis == true) || (item.state && dis == false)) return;
		var imgObj = this._getObj(item.obj, "img");
		if (imgObj == null) imgObj = this._addImgObj(item.obj);
		imgObj.src = this.imagePath+url;
	}
	this._clearItemImage = function(item, dis) {
		if (dis == true) item.imgEn = ""; else item.imgDis = "";
		if ((!item.state && dis == true) || (item.state && dis == false)) return;
		var imgObj = this._getObj(item.obj, "img");
		if (imgObj != null) imgObj.parentNode.removeChild(imgObj);
	}
	// set/get item text
	this._setItemText = function(item, text) {
		var txtObj = this._getObj(item.obj, "div");
		if (text == null || text.length == 0) {
			if (txtObj != null) txtObj.parentNode.removeChild(txtObj);
			return;
		}
		if (txtObj == null) { txtObj = document.createElement("DIV"); item.obj.appendChild(txtObj); }
		txtObj.innerHTML = text;
	}
	this._getItemText = function(item) {
		var txtObj = this._getObj(item.obj, "div");
		if (txtObj != null) return txtObj.innerHTML;
		return "";
	}
	
	// enable/disable btn
	this._enableItem = function(item) {
		if (item.state) return;
		item.state = true;
		if (this.objPull[item.id]["type"] == "buttonTwoState" && this.objPull[item.id]["obj"]["pressed"] == true) {
			item.obj.className = "dhx_toolbar_btn pres";
			item.obj.renderAs = "dhx_toolbar_btn over";
		} else {
			item.obj.className = "dhx_toolbar_btn def";
			item.obj.renderAs = item.obj.className;
		}
		if (item.arw) item.arw.className = String(item.obj.className).replace("btn","arw");
		var imgObj = this._getObj(item.obj, "img");
		if (item.imgEn != "") {
			if (imgObj == null) imgObj = this._addImgObj(item.obj);
			imgObj.src = this.imagePath+item.imgEn;
		} else {
			if (imgObj != null) imgObj.parentNode.removeChild(imgObj);
		}
	}
	this._disableItem = function(item) {
		if (!item.state) return;
		item.state = false;
		item.obj.className = "dhx_toolbar_btn "+(this.objPull[item.id]["type"]=="buttonTwoState"&&item.obj.pressed?"pres_":"")+"dis";
		item.obj.renderAs = "dhx_toolbar_btn def";
		if (item.arw) item.arw.className = String(item.obj.className).replace("btn","arw");
		var imgObj = this._getObj(item.obj, "img");
		if (item.imgDis != "") {
			if (imgObj == null) imgObj = this._addImgObj(item.obj);
			imgObj.src = this.imagePath+item.imgDis;
		} else {
			if (imgObj != null) imgObj.parentNode.removeChild(imgObj);
		}
		// if (this.objPull[item.id]["type"] == "buttonTwoState") this.objPull[item.id]["obj"]["pressed"] = false;
		// hide opened polygon if any
		if (item.polygon != null) {
			if (item.polygon.style.display != "none") {
				item.polygon.style.display = "none";
				if (item.polygon._ie6cover) item.polygon._ie6cover.style.display = "none";
				// fix border
				if (this.skin == "dhx_terrace") this._improveTerraceButtonSelect(item.id, true);
			}
		}
		this.anyUsed = "none";
	}
	
	/**
	*   @desc: remove all existing items
	*   @type: public
	*/
	this.clearAll = function() {
		for (var a in this.objPull) this._removeItem(String(a).replace(this.idPrefix,""));
	}
	
	
	//
	this._isWebToolbar = true;
	
	this._doOnClick = function(e) {
		if (main_self && main_self.forEachItem) {
			main_self.forEachItem(function(itemId){
				if (main_self.objPull[main_self.idPrefix+itemId]["type"] == "buttonSelect") {
					// hide any opened buttonSelect's polygons, clear selection if any
					var item = main_self.objPull[main_self.idPrefix+itemId];
					if (item.arw._skip === true) {
						item.arw._skip = false;
					} else if (item.polygon.style.display != "none") {
						item.obj.renderAs = "dhx_toolbar_btn def";
						item.obj.className = item.obj.renderAs;
						item.arw.className = String(item.obj.renderAs).replace("btn","arw");
						main_self.anyUsed = "none";
						item.polygon.style.display = "none";
						if (item.polygon._ie6cover) item.polygon._ie6cover.style.display = "none";
						// fix border
						if (main_self.skin == "dhx_terrace") main_self._improveTerraceButtonSelect(item.id, true);
					}
				}
			});
		}
	}
	if (this._isIPad) {
		document.addEventListener("touchstart", this._doOnClick, false);
	} else {
		if (typeof(window.addEventListener) != "undefined") {
			window.addEventListener("mousedown", this._doOnClick, false);
		} else {
			document.body.attachEvent("onmousedown", this._doOnClick);
		}
	}
	
	//
	return this;
}
dhtmlXToolbarObject.prototype.addSpacer = function(nextToId) {
	var nti = this.idPrefix+nextToId;
	if (this._spacer != null) {
		// spacer already at specified position
		if (this._spacer.idd == nextToId) return;
		// if current spacer contain nextToId item
		// move all items from first to nextToId to this.base
		if (this._spacer == this.objPull[nti].obj.parentNode) {
			var doMove = true;
			while (doMove) {
				var idd = this._spacer.childNodes[0].idd;
				this.base.appendChild(this._spacer.childNodes[0]);
				if (idd == nextToId || this._spacer.childNodes.length == 0) {
					if (this.objPull[nti].arw != null) this.base.appendChild(this.objPull[nti].arw);
					doMove = false;
				}
			}
			this._spacer.idd = nextToId;
			this._fixSpacer();
			return;
		}
		// if this.base contain nextToId item, move (insertBefore[0])
		if (this.base == this.objPull[nti].obj.parentNode) {
			var doMove = true;
			var chArw = (this.objPull[nti].arw!=null);
			while (doMove) {
				var q = this.base.childNodes.length-1;
				if (chArw == true) if (this.base.childNodes[q] == this.objPull[nti].arw) doMove = false;
				if (this.base.childNodes[q].idd == nextToId) doMove = false;
				if (doMove) { if (this._spacer.childNodes.length > 0) this._spacer.insertBefore(this.base.childNodes[q], this._spacer.childNodes[0]); else this._spacer.appendChild(this.base.childNodes[q]); }
			}
			this._spacer.idd = nextToId;
			this._fixSpacer();
			return;
		}
		
	} else {
		var np = null;
		for (var q=0; q<this.base.childNodes.length; q++) {
			if (this.base.childNodes[q] == this.objPull[this.idPrefix+nextToId].obj) {
				np = q;
				if (this.objPull[this.idPrefix+nextToId].arw != null) np = q+1;
			}
		}
		if (np != null) {
			this._spacer = document.createElement("DIV");
			this._spacer.className = "dhxtoolbar_spacer "+(this.align=="right"?" float_left":" float_right");
			this._spacer.dir = "ltr";
			this._spacer.idd = nextToId;
			while (this.base.childNodes.length > np+1) this._spacer.appendChild(this.base.childNodes[np+1]);
			this.cont.appendChild(this._spacer);
			this._fixSpacer();
		}
	}
	if (this.skin == "dhx_terrace") this._improveTerraceSkin();
}
dhtmlXToolbarObject.prototype.removeSpacer = function() {
	if (!this._spacer) return;
	while (this._spacer.childNodes.length > 0) this.base.appendChild(this._spacer.childNodes[0]);
	this._spacer.parentNode.removeChild(this._spacer);
	this._spacer = null;
	if (this.skin == "dhx_terrace") this._improveTerraceSkin();
}
dhtmlXToolbarObject.prototype._fixSpacer = function() {
	// IE icons mixing fix
	if (_isIE && this._spacer != null) {
		this._spacer.style.borderLeft = "1px solid #a4bed4";
		var k = this._spacer;
		window.setTimeout(function(){k.style.borderLeft="0px solid #a4bed4";k=null;},1);
	}
}

/**
*	@desc: return item type by item id
*	@param: itemId
*	@type: public
*/
dhtmlXToolbarObject.prototype.getType = function(itemId) {
	var parentId = this.getParentId(itemId);
	if (parentId != null) {
		var typeExt = null;
		var itemData = this.objPull[this.idPrefix+parentId]._listOptions[itemId];
		if (itemData != null) if (itemData.sep != null) typeExt = "buttonSelectSeparator"; else typeExt = "buttonSelectButton";
		return typeExt;
	} else {
		if (this.objPull[this.idPrefix+itemId] == null) return null;
		return this.objPull[this.idPrefix+itemId]["type"];
	}
}
/**
*	@desc: deprecated; return extended item type by item id (button select node)
*	@param: itemId
*	@type: public
*/
dhtmlXToolbarObject.prototype.getTypeExt = function(itemId) {
	var type = this.getType(itemId);
	if (type == "buttonSelectButton" || type == "buttonSelectSeparator") {
		if (type == "buttonSelectButton") type = "button"; else type = "separator";
		return type;
	}
	return null;
}
dhtmlXToolbarObject.prototype.inArray = function(array, value) {
	for (var q=0; q<array.length; q++) { if (array[q]==value) return true; }
	return false;
}
dhtmlXToolbarObject.prototype.getParentId = function(listId) {
	var parentId = null;
	for (var a in this.objPull) if (this.objPull[a]._listOptions) for (var b in this.objPull[a]._listOptions) if (b == listId) parentId = String(a).replace(this.idPrefix,"");
	return parentId;
}
/* adding items */
dhtmlXToolbarObject.prototype._addItem = function(itemData, pos) {
	this._addItemToStorage(itemData, pos);
	if (this.skin == "dhx_terrace") this._improveTerraceSkin();
}
/**
*   @desc: adds a button to webbar
*   @param: id - id of a button
*   @param: pos - position of a button
*   @param: text - text for a button (null for no text)
*   @param: imgEnabled - image for enabled state (null for no image)
*   @param: imgDisabled - image for desabled state (null for no image)
*   @type: public
*/
dhtmlXToolbarObject.prototype.addButton = function(id, pos, text, imgEnabled, imgDisabled) {
	this._addItem({id:id, type:"button", text:text, img:imgEnabled, imgdis:imgDisabled}, pos);
}
/**
*   @desc: adds a text item to webbar
*   @param: id - id of a text item
*   @param: pos - position of a text item
*   @param: text - text for a text item
*   @type: public
*/
dhtmlXToolbarObject.prototype.addText = function(id, pos, text) {
	this._addItem({id:id,type:"text",text:text}, pos);
}
//#tool_list:06062008{
/**
*   @desc: adds a select button to webbar
*   @param: id - id of a select button
*   @param: pos - position of a select button
*   @param: text - text for a select button (null for no text)
*   @param: opts - listed options for a select button
*   @param: imgEnabled - image for enabled state (null for no image)
*   @param: imgDisabled - image for desabled state (null for no image)
*   @param: renderSelect - set to false to prevent list options selection by click
*   @param: openAll - open options list when click main button (not only arrow)
*   @param: maxOpen - specify count of visible items (for long lists)
*   @param: mode - keep empty or use "select" for select mode
*   @type: public
*/
dhtmlXToolbarObject.prototype.addButtonSelect = function(id, pos, text, opts, imgEnabled, imgDisabled, renderSelect, openAll, maxOpen, mode) { 
	var items = [];
	for (var q=0; q<opts.length; q++) {
		var u = {};
		if (opts[q] instanceof Array) {
			u.id = opts[q][0];
			u.type = (opts[q][1]=="obj"?"button":"separator");
			u.text = (opts[q][2]||null);
			u.img = (opts[q][3]||null);
		} else if (opts[q] instanceof Object && opts[q] != null && typeof(opts[q].id) != "undefined" && typeof(opts[q].type) != "undefined") {
			u.id = opts[q].id;
			u.type = (opts[q].type=="obj"?"button":"separator");
			u.text = opts[q].text;
			u.img = opts[q].img;
		}
		items[items.length] = u;
	}
	this._addItem({id:id, type:"buttonSelect", text:text, img:imgEnabled, imgdis:imgDisabled, renderSelect:renderSelect, openAll:openAll, items:items, maxOpen:maxOpen, mode:mode}, pos);
}
//#}
//#tool_2state:06062008{
/**
*   @desc: adds a two-state button to webbar
*   @param: id - id of a two-state button
*   @param: pos - position of a two-state button
*   @param: text - text for a two-state button (null for no text)
*   @param: imgEnabled - image for enabled state (null for no image)
*   @param: imgDisabled - image for desabled state (null for no image)
*   @type: public
*/
dhtmlXToolbarObject.prototype.addButtonTwoState = function(id, pos, text, imgEnabled, imgDisabled) {
	this._addItem({id:id, type:"buttonTwoState", img:imgEnabled, imgdis:imgDisabled, text:text}, pos);
}
//#}
/**
*   @desc: adds a separator to webbar
*   @param: id - id of a separator
*   @param: pos - position of a separator
*   @type: public
*/
dhtmlXToolbarObject.prototype.addSeparator = function(id, pos) {
	this._addItem({id:id,type:"separator"}, pos);
}
//#tool_slider:06062008{
/**
*   @desc: adds a slider to webbar
*   @param: id - id of a slider
*   @param: pos - position of a slider
*   @param: len - length (width) of a slider (px)
*   @param: valueMin - minimal available value of a slider
*   @param: valueMax - maximal available value of a slider
*   @param: valueNow - initial current value of a slider
*   @param: textMin - label for minimal value side (on the left side)
*   @param: textMax - label for maximal value side (on the right side)
*   @param: tip - tooltip template (%v will replaced with current value)
*   @type: public
*/
dhtmlXToolbarObject.prototype.addSlider = function(id, pos, len, valueMin, valueMax, valueNow, textMin, textMax, tip) {
	this._addItem({id:id, type:"slider", length:len, valueMin:valueMin, valueMax:valueMax, valueNow:valueNow, textMin:textMin, textMax:textMax, toolTip:tip}, pos);
}
//#}
/**
*   @desc: adds an input item to webbar
*   @param: id - id of an input item
*   @param: pos - position of an input item
*   @param: value - value (text) in an input item by the default
*   @param: width - width of an input item (px)
*   @type: public
*/
dhtmlXToolbarObject.prototype.addInput = function(id, pos, value, width) {
	this._addItem({id:id,type:"buttonInput",value:value,width:width}, pos);
}
/**
*   @desc: iterator, calls user handler for each item
*   @param: handler - user function, will take item id as an argument
*   @type: public
*/
dhtmlXToolbarObject.prototype.forEachItem = function(handler) {
	for (var a in this.objPull) {
		if (this.inArray(this.rootTypes, this.objPull[a]["type"])) {
			handler(this.objPull[a]["id"].replace(this.idPrefix,""));
		}
	}
};
(function(){
	var list="isVisible,enableItem,disableItem,isEnabled,setItemText,getItemText,setItemToolTip,getItemToolTip,getInput,setItemImage,setItemImageDis,clearItemImage,clearItemImageDis,setItemState,getItemState,setItemToolTipTemplate,getItemToolTipTemplate,setValue,getValue,setMinValue,getMinValue,setMaxValue,getMaxValue,setWidth,getWidth,setMaxOpen".split(",")
	var ret=[false,"","",false,"","","","","","","","","",false,"","","",null,"",[null,null],"",[null,null],"",null]
	var functor=function(name,res){
		return function(itemId,a,b){
			itemId = this.idPrefix+itemId;
			if (this.objPull[itemId][name] != null) return this.objPull[itemId][name].call(this.objPull[itemId],a,b); else return res;
		};
	}
	for (var i=0; i<list.length; i++){
		var name=list[i];
		var res=ret[i];
		dhtmlXToolbarObject.prototype[name] = functor(name,res);
	}
})();


/**
*   @desc: shows a specified item
*   @param: itemId - id of an item to show
*   @type: public
*/
dhtmlXToolbarObject.prototype.showItem = function(itemId) {
	itemId = this.idPrefix+itemId;
	if (this.objPull[itemId] != null && this.objPull[itemId].showItem != null) {
		this.objPull[itemId].showItem();
		if (this.skin == "dhx_terrace") this._improveTerraceSkin();
	}
}
/**
*   @desc: hides a specified item
*   @param: itemId - id of an item to hide
*   @type: public
*/
dhtmlXToolbarObject.prototype.hideItem = function(itemId) {
	itemId = this.idPrefix+itemId;
	if (this.objPull[itemId] != null && this.objPull[itemId].hideItem != null) {
		this.objPull[itemId].hideItem();
		if (this.skin == "dhx_terrace") this._improveTerraceSkin();
	}
}
/**
*   @desc: returns true if a specified item is visible
*   @param: itemId - id of an item to check
*   @type: public
*/
//dhtmlXToolbarObject.prototype.isVisible = function(itemId) {
/**
*   @desc: enables a specified item
*   @param: itemId - id of an item to enable
*   @type: public
*/
//dhtmlXToolbarObject.prototype.enableItem = function(itemId) {
/**
*   @desc: disables a specified item
*   @param: itemId - id of an item to disable
*   @type: public
*/
//dhtmlXToolbarObject.prototype.disableItem = function(itemId) {
/**
*   @desc: returns true if a specified item is enabled
*   @param: itemId - id of an item to check
*   @type: public
*/
//dhtmlXToolbarObject.prototype.isEnabled = function(itemId) {
/**
*   @desc: sets new text for an item
*   @param: itemId - id of an item
*   @param: text - new text for an item
*   @type: public
*/
//dhtmlXToolbarObject.prototype.setItemText = function(itemId, text) {
/**
*   @desc: return cureent item's text
*   @param: itemId - id of an item
*   @type: public
*/
//dhtmlXToolbarObject.prototype.getItemText = function(itemId) {
/**
*   @desc: sets a tooltip for an item
*   @param: itemId - id of an item
*   @param: tip - tooltip (empty for clear)
*   @type: public
*/
//dhtmlXToolbarObject.prototype.setItemToolTip = function(itemId, tip) {
/**
*   @desc: return current item's tooltip
*   @param: itemId - id of an item
*   @type: public
*/
//dhtmlXToolbarObject.prototype.getItemToolTip = function(itemId) {
/**
*   @desc: sets an image for an item in enabled state
*   @param: itemId - id of an item
*   @param: url - url of an image
*   @type: public
*/
//dhtmlXToolbarObject.prototype.setItemImage = function(itemId, url) {
/**
*   @desc: sets an image for an item in disabled state
*   @param: itemId - id of an item
*   @param: url - url of an image
*   @type: public
*/
//dhtmlXToolbarObject.prototype.setItemImageDis = function(itemId, url) {
/**
*   @desc: removes an image of an item in enabled state
*   @param: itemId - id of an item
*   @type: public
*/
//dhtmlXToolbarObject.prototype.clearItemImage = function(itemId) {
/**
*   @desc: removes an image of an item in disabled state
*   @param: itemId - id of an item
*   @type: public
*/
//dhtmlXToolbarObject.prototype.clearItemImageDis = function(itemId) {
/**
*   @desc: sets a pressed/released state for a two-state button
*   @param: itemId - id of a two-state item
*   @param: state - state, true for pressed, false for released
*   @type: public
*/
//dhtmlXToolbarObject.prototype.setItemState = function(itemId, state) {
/**
*   @desc: returns current state of a two-state button
*   @param: itemId - id of a two-state item to check
*   @type: public
*/
//dhtmlXToolbarObject.prototype.getItemState = function(itemId) {
/**
*   @desc: sets a tooltip template for a slider
*   @param: itemId - id of a slider
*   @param: template - tooltip template (%v will replaced with current value)
*   @type: public
*/
//dhtmlXToolbarObject.prototype.setItemToolTipTemplate = function(itemId, template) {
/**
*   @desc: returns a current tooltip template of a slider
*   @param: itemId - id of a slider
*   @type: public
*/
//dhtmlXToolbarObject.prototype.getItemToolTipTemplate = function(itemId) {
/**
*   @desc: sets a value for a slider or an input item
*   @param: itemId - id of a slider or an input item
*   @param: value - value (int for slider, any for input item)
*   @type: public
*/
//dhtmlXToolbarObject.prototype.setValue = function(itemId, value, callEvent) {
/**
*   @desc: returns a current value of a slider or an input item
*   @param: itemId - id of a slider or an input item
*   @type: public
*/
//dhtmlXToolbarObject.prototype.getValue = function(itemId) {
/**
*   @desc: sets minimal value and label for a slider
*   @param: itemId - id of a slider
*   @param: value - value (int)
*   @param: label - label for value (empty for no label)
*   @type: public
*/
//dhtmlXToolbarObject.prototype.setMinValue = function(itemId, value, label) {
/**
*   @desc: return current minimal value and label of a slider
*   @param: itemId - id of a slider
*   @type: public
*/
//dhtmlXToolbarObject.prototype.getMinValue = function(itemId) {
/**
*   @desc: sets maximal value and label for a slider
*   @param: itemId - id of a slider
*   @param: value - value (int)
*   @param: label - label for value (empty for no label)
*   @type: public
*/
//dhtmlXToolbarObject.prototype.setMaxValue = function(itemId, value, label) {
/**
*   @desc: returns current maximal value and label of a slider
*   @param: itemId - id of a slider
*   @type: public
*/
//dhtmlXToolbarObject.prototype.getMaxValue = function(itemId) {
/**
*   @desc: sets a width for an text/input/buttonSelect item
*   @param: itemId - id of an text/input/buttonSelect item
*   @param: width - new width (px)
*   @type: public
*/
//dhtmlXToolbarObject.prototype.setWidth = function(itemId, width) {
/**
*   @desc: returns a current width of an input item
*   @param: itemId - id of an input item
*   @type: public
*/
//dhtmlXToolbarObject.prototype.getWidth = function(itemId) {
/**
*   @desc: returns a current position of an item
*   @param: itemId - id of an item
*   @type: public
*/
dhtmlXToolbarObject.prototype.getPosition = function(itemId) {
	return this._getPosition(itemId);
}
dhtmlXToolbarObject.prototype._getPosition = function(id, getRealPosition) {
	
	if (this.objPull[this.idPrefix+id] == null) return null;
	
	var pos = null;
	var w = 0;
	for (var q=0; q<this.base.childNodes.length; q++) {
		if (this.base.childNodes[q].idd != null) {
			if (this.base.childNodes[q].idd == id) pos = w;
			w++;
		}
	}
	if (!pos && this._spacer != null) {
		for (var q=0; q<this._spacer.childNodes.length; q++) {
			if (this._spacer.childNodes[q].idd != null) {
				if (this._spacer.childNodes[q].idd == id) pos = w;
				w++;
			}
		}
	}
	return pos;
}
/**
*   @desc: sets a new position for an item (moves item to desired position)
*   @param: itemId - id of an item
*   @param: pos - new position
*   @type: public
*/
dhtmlXToolbarObject.prototype.setPosition = function(itemId, pos) {
	this._setPosition(itemId, pos);
}
dhtmlXToolbarObject.prototype._setPosition = function(id, pos) {
	
	if (this.objPull[this.idPrefix+id] == null) return;
	
	if (isNaN(pos)) pos = this.base.childNodes.length;
	if (pos < 0) pos = 0;
	
	var spacerId = null;
	if (this._spacer) {
		spacerId = this._spacer.idd;
		this.removeSpacer();
	}
	
	var item = this.objPull[this.idPrefix+id];
	this.base.removeChild(item.obj);
	if (item.arw) this.base.removeChild(item.arw);
	
	var newPos = this._getIdByPosition(pos, true);
	
	if (newPos[0] == null) {
		this.base.appendChild(item.obj);
		if (item.arw) this.base.appendChild(item.arw);
	} else {
		this.base.insertBefore(item.obj, this.base.childNodes[newPos[1]]);
		if (item.arw) this.base.insertBefore(item.arw, this.base.childNodes[newPos[1]+1]);
	}
	if (spacerId != null) this.addSpacer(spacerId);
	
}
dhtmlXToolbarObject.prototype._getIdByPosition = function(pos, retRealPos) {
	
	var id = null;
	var w = 0;
	var realPos = 0;
	for (var q=0; q<this.base.childNodes.length; q++) {
		if (this.base.childNodes[q]["idd"] != null && id == null) {
			if ((w++) == pos) id = this.base.childNodes[q]["idd"];
		}
		if (id == null) realPos++;
	}
	realPos = (id==null?null:realPos);
	return (retRealPos==true?new Array(id, realPos):id);
}

/**
*   @desc: completely removes an item for a webbar
*   @param: itemId - id of an item
*   @type: public
*/
dhtmlXToolbarObject.prototype.removeItem = function(itemId) {
	this._removeItem(itemId);
	if (this.skin == "dhx_terrace") this._improveTerraceSkin();
};

dhtmlXToolbarObject.prototype._removeItem = function(itemId) {
	
	var t = this.getType(itemId);
	
	itemId = this.idPrefix+itemId;
	var p = this.objPull[itemId];
	
	
	if (t == "button") {
		
		p.obj._doOnMouseOver = null;
		p.obj._doOnMouseOut = null;
		p.obj._doOnMouseUp = null;
		p.obj._doOnMouseUpOnceAnywhere = null;
		
		p.obj.onclick = null;
		p.obj.onmouseover = null;
		p.obj.onmouseout = null;
		p.obj.onmouseup = null;
		p.obj.onmousedown = null;
		p.obj.onselectstart = null;
		
		p.obj.renderAs = null;
		p.obj.idd = null;
		p.obj.parentNode.removeChild(p.obj);
		p.obj = null;

		p.id = null;
		p.state = null;
		p.img = null;
		p.imgEn = null;
		p.imgDis = null;
		p.type = null;
		
		p.enableItem = null;
		p.disableItem = null;
		p.isEnabled = null;
		p.showItem = null;
		p.hideItem = null;
		p.isVisible = null;
		p.setItemText = null;
		p.getItemText = null;
		p.setItemImage = null;
		p.clearItemImage = null;
		p.setItemImageDis = null;
		p.clearItemImageDis = null;
		p.setItemToolTip = null;
		p.getItemToolTip = null;
		
	}
	
	if (t == "buttonTwoState") {
		
		p.obj._doOnMouseOver = null;
		p.obj._doOnMouseOut = null;
		
		p.obj.onmouseover = null;
		p.obj.onmouseout = null;
		p.obj.onmousedown = null;
		p.obj.onselectstart = null;
		
		p.obj.renderAs = null;
		p.obj.idd = null;
		p.obj.parentNode.removeChild(p.obj);
		p.obj = null;
		
		p.id = null;
		p.state = null;
		p.img = null;
		p.imgEn = null;
		p.imgDis = null;
		p.type = null;
		
		p.enableItem = null;
		p.disableItem = null;
		p.isEnabled = null;
		p.showItem = null;
		p.hideItem = null;
		p.isVisible = null;
		p.setItemText = null;
		p.getItemText = null;
		p.setItemImage = null;
		p.clearItemImage = null;
		p.setItemImageDis = null;
		p.clearItemImageDis = null;
		p.setItemToolTip = null;
		p.getItemToolTip = null;
		p.setItemState = null;
		p.getItemState = null;
		
	}
	
	if (t == "buttonSelect") {
		
		for (var a in p._listOptions) this.removeListOption(itemId, a);
		p._listOptions = null;
		
		if (p.polygon._ie6cover) {
			document.body.removeChild(p.polygon._ie6cover);
			p.polygon._ie6cover = null;
		}
		
		p.p_tbl.removeChild(p.p_tbody);
		p.polygon.removeChild(p.p_tbl);
		p.polygon.onselectstart = null;
		document.body.removeChild(p.polygon);
		
		p.p_tbody = null;
		p.p_tbl = null;
		p.polygon = null;
		
		p.obj.onclick = null;
		p.obj.onmouseover = null;
		p.obj.onmouseout = null;
		p.obj.onmouseup = null;
		p.obj.onmousedown = null;
		p.obj.onselectstart = null;
		p.obj.idd = null;
		p.obj.iddPrefix = null;
		p.obj.parentNode.removeChild(p.obj);
		p.obj = null;
		
		p.arw.onclick = null;
		p.arw.onmouseover = null;
		p.arw.onmouseout = null;
		p.arw.onmouseup = null;
		p.arw.onmousedown = null;
		p.arw.onselectstart = null;
		p.arw.parentNode.removeChild(p.arw);
		p.arw = null;
		
		p.renderSelect = null;
		p.state = null;
		p.type = null;
		p.id = null;
		p.img = null;
		p.imgEn = null;
		p.imgDis = null;
		p.openAll = null;
		
		p._isListButton = null;
		p._separatorButtonSelectObject = null;
		p._buttonButtonSelectObject = null;
		p.setWidth = null;
		p.enableItem = null;
		p.disableItem = null;
		p.isEnabled = null;
		p.showItem = null;
		p.hideItem = null;
		p.isVisible = null;
		p.setItemText = null;
		p.getItemText = null;
		p.setItemImage = null;
		p.clearItemImage = null;
		p.setItemImageDis = null;
		p.clearItemImageDis = null;
		p.setItemToolTip = null;
		p.getItemToolTip = null;
		p.addListOption = null;
		p.removeListOption = null;
		p.showListOption = null;
		p.hideListOption = null;
		p.isListOptionVisible = null;
		p.enableListOption = null;
		p.disableListOption = null;
		p.isListOptionEnabled = null;
		p.setListOptionPosition = null;
		p.getListOptionPosition = null;
		p.setListOptionImage = null;
		p.getListOptionImage = null;
		p.clearListOptionImage = null;
		p.setListOptionText = null;
		p.getListOptionText = null;
		p.setListOptionToolTip = null;
		p.getListOptionToolTip = null;
		p.forEachListOption = null;
		p.getAllListOptions = null;
		p.setListOptionSelected = null;
		p.getListOptionSelected = null;
		
	}
	
	if (t == "buttonInput") {
		
		p.obj.childNodes[0].onkeydown = null;
		p.obj.removeChild(p.obj.childNodes[0]);
		
		p.obj.w = null;
		p.obj.idd = null;
		p.obj.parentNode.removeChild(p.obj);
		p.obj = null;
		
		p.id = null;
		p.type = null;
		
		p.enableItem = null;
		p.disableItem = null;
		p.isEnabled = null;
		p.showItem = null;
		p.hideItem = null;
		p.isVisible = null;
		p.setItemToolTip = null;
		p.getItemToolTip = null;
		p.setWidth = null;
		p.getWidth = null;
		p.setValue = null;
		p.getValue = null;
		p.setItemText = null;
		p.getItemText = null;
		
	}
	
	if (t == "slider") {
		
		if (this._isIPad) {
			document.removeEventListener("touchmove", pen._doOnMouseMoveStart, false);
			document.removeEventListener("touchend", pen._doOnMouseMoveEnd, false);
		} else {
			if (typeof(window.addEventListener) == "function") {
				window.removeEventListener("mousemove", p.pen._doOnMouseMoveStart, false);
				window.removeEventListener("mouseup", p.pen._doOnMouseMoveEnd, false);
			} else {
				document.body.detachEvent("onmousemove", p.pen._doOnMouseMoveStart);
				document.body.detachEvent("onmouseup", p.pen._doOnMouseMoveEnd);
			}
		}
		
		p.pen.allowMove = null;
		p.pen.initXY = null;
		p.pen.maxX = null;
		p.pen.minX = null;
		p.pen.nowX = null;
		p.pen.newNowX = null;
		p.pen.valueMax = null;
		p.pen.valueMin = null;
		p.pen.valueNow = null;
		
		p.pen._definePos = null;
		p.pen._detectLimits = null;
		p.pen._doOnMouseMoveStart = null;
		p.pen._doOnMouseMoveEnd = null;
		p.pen.onmousedown = null;
		
		p.obj.removeChild(p.pen);
		p.pen = null;
		
		p.label.tip = null;
		document.body.removeChild(p.label);
		p.label = null;
		
		p.obj.onselectstart = null;
		p.obj.idd = null;
		while (p.obj.childNodes.length > 0) p.obj.removeChild(p.obj.childNodes[0]);
		p.obj.parentNode.removeChild(p.obj);
		p.obj = null;
		
		p.id = null;
		p.type = null;
		p.state = null;
		
		p.enableItem = null;
		p.disableItem = null;
		p.isEnabled = null;
		p.setItemToolTipTemplate = null;
		p.getItemToolTipTemplate = null;
		p.setMaxValue = null;
		p.setMinValue = null;
		p.getMaxValue = null;
		p.getMinValue = null;
		p.setValue = null;
		p.getValue = null;
		p.showItem = null;
		p.hideItem = null;
		p.isVisible = null;
		
	}
	
	if (t == "separator") {
		
		p.obj.onselectstart = null;
		p.obj.idd = null;
		p.obj.parentNode.removeChild(p.obj);
		p.obj = null;
		
		p.id = null;
		p.type = null;
		
		p.showItem = null;
		p.hideItem = null;
		p.isVisible = null;
		
	}
	
	if (t == "text") {
		
		p.obj.onselectstart = null;
		p.obj.idd = null;
		p.obj.parentNode.removeChild(p.obj);
		p.obj = null;
		
		p.id = null;
		p.type = null;
		
		p.showItem = null;
		p.hideItem = null;
		p.isVisible = null;
		p.setWidth = null;
		p.setItemText = null;
		p.getItemText = null;
		
	}
	
	t = null;
	p = null;
	this.objPull[this.idPrefix+itemId] = null;
	delete this.objPull[this.idPrefix+itemId];
	
	
};
//#tool_list:06062008{
(function(){
	var list="addListOption,removeListOption,showListOption,hideListOption,isListOptionVisible,enableListOption,disableListOption,isListOptionEnabled,setListOptionPosition,getListOptionPosition,setListOptionText,getListOptionText,setListOptionToolTip,getListOptionToolTip,setListOptionImage,getListOptionImage,clearListOptionImage,forEachListOption,getAllListOptions,setListOptionSelected,getListOptionSelected".split(",")
	var functor = function(name){
				return function(parentId,a,b,c,d,e){
				parentId = this.idPrefix+parentId;
				if (this.objPull[parentId] == null) return;
				if (this.objPull[parentId]["type"] != "buttonSelect") return;
				return this.objPull[parentId][name].call(this.objPull[parentId],a,b,c,d,e);
			}
		}
	for (var i=0; i<list.length; i++){
		var name=list[i];
		dhtmlXToolbarObject.prototype[name]=functor(name)
	}
})()
/**
*   @desc: adds a listed option to a select button
*   @param: parentId - id of a select button
*   @param: optionId - id of a listed option
*   @param: pos - position of a listed option
*   @param: type - type of a listed option (button|separator)
*   @param: text - text for a listed option
*   @param: img - image for a listed option
*   @type: public
*/
//dhtmlXToolbarObject.prototype.addListOption = function(parentId, optionId, pos, type, text, img) {
/**
*   @desc: completely removes a listed option from a select button
*   @param: parentId - id of a select button
*   @param: optionId - id of a listed option
*   @type: public
*/
//dhtmlXToolbarObject.prototype.removeListOption = function(parentId, optionId) {
/**
*   @desc: shows a listed option
*   @param: parentId - id of a select button
*   @param: optionId - id of a listed option
*   @type: public
*/
//dhtmlXToolbarObject.prototype.showListOption = function(parentId, optionId) {
/**
*   @desc: hides a listed option
*   @param: parentId - id of a select button
*   @param: optionId - id of a listed option
*   @type: public
*/
//dhtmlXToolbarObject.prototype.hideListOption = function(parentId, optionId) {
/**
*   @desc: return true if a listed option is visible
*   @param: parentId - id of a select button
*   @param: optionId - id of a listed option
*   @type: public
*/
//dhtmlXToolbarObject.prototype.isListOptionVisible = function(parentId, optionId) {
/**
*   @desc: enables a listed option
*   @param: parentId - id of a select button
*   @param: optionId - id of a listed option
*   @type: public
*/
//dhtmlXToolbarObject.prototype.enableListOption = function(parentId, optionId) {
/**
*   @desc: disables a listed option
*   @param: parentId - id of a select button
*   @param: optionId - id of a listed option
*   @type: public
*/
//dhtmlXToolbarObject.prototype.disableListOption = function(parentId, optionId) {
/**
*   @desc: return true if a listed option is enabled
*   @param: parentId - id of a select button
*   @param: optionId - id of a listed option
*   @type: public
*/
//dhtmlXToolbarObject.prototype.isListOptionEnabled = function(parentId, optionId) {
/**
*   @desc: sets a position of a listed option (moves listed option)
*   @param: parentId - id of a select button
*   @param: optionId - id of a listed option
*   @param: pos - position of a listed option
*   @type: public
*/
//dhtmlXToolbarObject.prototype.setListOptionPosition = function(parentId, optionId, pos) {
/**
*   @desc: returns a position of a listed option
*   @param: parentId - id of a select button
*   @param: optionId - id of a listed option
*   @type: public
*/
//dhtmlXToolbarObject.prototype.getListOptionPosition = function(parentId, optionId) {
/**
*   @desc: sets a text for a listed option
*   @param: parentId - id of a select button
*   @param: optionId - id of a listed option
*   @param: text - text for a listed option
*   @type: public
*/
//dhtmlXToolbarObject.prototype.setListOptionText = function(parentId, optionId, text) {
/**
*   @desc: returns a text of a listed option
*   @param: parentId - id of a select button
*   @param: optionId - id of a listed option
*   @type: public
*/
//dhtmlXToolbarObject.prototype.getListOptionText = function(parentId, optionId) {
/**
*   @desc: sets a tooltip for a listed option
*   @param: parentId - id of a select button
*   @param: optionId - id of a listed option
*   @param: tip - tooltip for a listed option
*   @type: public
*/
//dhtmlXToolbarObject.prototype.setListOptionToolTip = function(parentId, optionId, tip) {
/**
*   @desc: returns a tooltip of a listed option
*   @param: parentId - id of a select button
*   @param: optionId - id of a listed option
*   @type: public
*/
//dhtmlXToolbarObject.prototype.getListOptionToolTip = function(parentId, optionId) {
/**
*   @desc: sets an image for a listed option
*   @param: parentId - id of a select button
*   @param: optionId - id of a listed option
*   @param: img - image for a listed option
*   @type: public
*/
//dhtmlXToolbarObject.prototype.setListOptionImage = function(parentId, optionId, img) {
/**
*   @desc: returns an image of a listed option
*   @param: parentId - id of a select button
*   @param: optionId - id of a listed option
*   @type: public
*/
//dhtmlXToolbarObject.prototype.getListOptionImage = function(parentId, optionId) {
/**
*   @desc: removes an image (if exists) of a listed option
*   @param: parentId - id of a select button
*   @param: optionId - id of a listed option
*   @type: public
*/
//dhtmlXToolbarObject.prototype.clearListOptionImage = function(parentId, optionId) {
/**
*   @desc: calls user defined handler for each listed option of parentId
*   @param: parentId - id of a select button
*   @param: handler - user defined function, listed option id will passed as an argument
*   @type: public
*/
//dhtmlXToolbarObject.prototype.forEachListOption = function(parentId, handler) {
/**
*   @desc: returns array with ids of all listed options for parentId
*   @param: parentId - id of a select button
*   @type: public
*/
//dhtmlXToolbarObject.prototype.getAllListOptions = function(parentId) {
/**
*   @desc: sets listed option selected
*   @param: parentId - id of a select button
*   @param: optionId - id of a listed option
*   @type: public
*/
//dhtmlXToolbarObject.prototype.setListOptionSelected = function(parentId, optionId) {
/**
*   @desc: returns selected listed option
*   @param: parentId - id of a select button
*   @type: public
*/
//dhtmlXToolbarObject.prototype.getListOptionSelected = function(parentId) {
//#}
dhtmlXToolbarObject.prototype._rtlParseBtn = function(t1, t2) {
	return t1+t2;
}
/*****************************************************************************************************************************************************************
	object: separator
*****************************************************************************************************************************************************************/
dhtmlXToolbarObject.prototype._separatorObject = function(that, id, data) {
	//
	this.id = that.idPrefix+id;
	this.obj = document.createElement("DIV");
	this.obj.className = "dhx_toolbar_sep";
	this.obj.style.display = (data.hidden!=null?"none":"");
	this.obj.idd = String(id);
	this.obj.title = (data.title||"");
	this.obj.onselectstart = function(e) { e = e||event; e.returnValue = false; }
	if (that._isIPad) {
		this.obj.ontouchstart = function(e){
			e = e||event;
			e.returnValue = false;
			e.cancelBubble = true;
			return false;
		}
	}
	//
	// add object
	that.base.appendChild(this.obj);
	
	// functions
	this.showItem = function() {
		this.obj.style.display = "";
	}
	this.hideItem = function() {
		this.obj.style.display = "none";
	}
	this.isVisible = function() {
		return (this.obj.style.display == "");
	}
	//
	return this;
}
/*****************************************************************************************************************************************************************
	object: text
*****************************************************************************************************************************************************************/
dhtmlXToolbarObject.prototype._textObject = function(that, id, data) {
	this.id = that.idPrefix+id;
	this.obj = document.createElement("DIV");
	this.obj.className = "dhx_toolbar_text";
	this.obj.style.display = (data.hidden!=null?"none":"");
	this.obj.idd = String(id);
	this.obj.title = (data.title||"");
	this.obj.onselectstart = function(e) { e = e||event; e.returnValue = false; }
	if (that._isIPad) {
		this.obj.ontouchstart = function(e){
			e = e||event;
			e.returnValue = false;
			e.cancelBubble = true;
			return false;
		}
	}
	//
	this.obj.innerHTML = (data.text||"");
	//
	that.base.appendChild(this.obj);
	//
	this.showItem = function() {
		this.obj.style.display = "";
	}
	this.hideItem = function() {
		this.obj.style.display = "none";
	}
	this.isVisible = function() {
		return (this.obj.style.display == "");
	}
	this.setItemText = function(text) {
		this.obj.innerHTML = text;
	}
	this.getItemText = function() {
		return this.obj.innerHTML;
	}
	this.setWidth = function(width) {
		this.obj.style.width = width+"px";
	}
	this.setItemToolTip = function(t) {
		this.obj.title = t;
	}
	this.getItemToolTip = function() {
		return this.obj.title;
	}
	//
	return this;
}
/*****************************************************************************************************************************************************************
	object: button
******************************************************************************************************************************************************************/
dhtmlXToolbarObject.prototype._buttonObject = function(that, id, data) {
	
	this.id = that.idPrefix+id;
	this.state = (data.enabled!=null?false:true);
	this.imgEn = (data.img||"");
	this.imgDis = (data.imgdis||"");
	this.img = (this.state?(this.imgEn!=""?this.imgEn:""):(this.imgDis!=""?this.imgDis:""));
	
	//
	this.obj = document.createElement("DIV");
	this.obj.className = "dhx_toolbar_btn "+(this.state?"def":"dis");
	this.obj.style.display = (data.hidden!=null?"none":"");
	this.obj.allowClick = false;
	this.obj.extAction = (data.action||null);
	this.obj.renderAs = this.obj.className;
	this.obj.idd = String(id);
	this.obj.title = (data.title||"");
	this.obj.pressed = false;
	//
	this.obj.innerHTML = that._rtlParseBtn((this.img!=""?"<img src='"+that.imagePath+this.img+"'>":""), (data.text!=null?"<div>"+data.text+"</div>":""));
	
	var obj = this;
	
	this.obj.onselectstart = function(e) { e = e||event; e.returnValue = false; }
	this.obj.onmouseover = function() { this._doOnMouseOver(); }
	this.obj.onmouseout = function() { this._doOnMouseOut(); }
	this.obj._doOnMouseOver = function() {
		this.allowClick = true;
		if (obj.state == false) return;
		if (that.anyUsed != "none") return;
		this.className = "dhx_toolbar_btn over";
		this.renderAs = this.className;
	}
	this.obj._doOnMouseOut = function() {
		this.allowClick = false;
		if (obj.state == false) return;
		if (that.anyUsed != "none") return;
		this.className = "dhx_toolbar_btn def";
		this.renderAs = this.renderAs;
	}
	
	this.obj.onclick = function(e) {
		if (obj.state == false) return;
		if (this.allowClick == false) return;
		e = e||event;
		// event
		var id = this.idd.replace(that.idPrefix,"");
		if (this.extAction) try {window[this.extAction](id);} catch(e){};
		if(that&&that.callEvent) that.callEvent("onClick", [id]);
	}
	
	this.obj[that._isIPad?"ontouchstart":"onmousedown"] = function(e) {
		if (obj.state == false) { e = e||event; e.returnValue = false; e.cancelBubble = true; return false; }
		if (that.anyUsed != "none") return;
		that.anyUsed = this.idd;
		this.className = "dhx_toolbar_btn pres";
		this.pressed = true;
		this.onmouseover = function() { this._doOnMouseOver(); }
		this.onmouseout = function() { that.anyUsed = "none"; this._doOnMouseOut(); }
		return false;
	}
	this.obj[that._isIPad?"ontouchend":"onmouseup"] = function(e) {
		if (obj.state == false) return;
		if (that.anyUsed != "none") { if (that.anyUsed != this.idd) return; }
		var t = that.anyUsed;
		this._doOnMouseUp();
		if (that._isIPad && t != "none") that.callEvent("onClick", [this.idd.replace(that.idPrefix,"")]);
	}
	if (that._isIPad) {
		this.obj.ontouchmove = function(e) {
			this._doOnMouseUp();
		}
	}
	this.obj._doOnMouseUp = function() {
		that.anyUsed = "none";
		this.className = this.renderAs;
		this.pressed = false;
	}
	this.obj._doOnMouseUpOnceAnywhere = function() {
		this._doOnMouseUp();
		this.onmouseover = function() { this._doOnMouseOver(); }
		this.onmouseout = function() { this._doOnMouseOut(); }
	}
	
	// add object
	that.base.appendChild(this.obj);
	//
	// functions
	this.enableItem = function() {
		that._enableItem(this);
	}
	this.disableItem = function() {
		that._disableItem(this);
	}
	this.isEnabled = function() {
		return this.state;
	}
	this.showItem = function() {
		this.obj.style.display = "";
	}
	this.hideItem = function() {
		this.obj.style.display = "none";
	}
	this.isVisible = function() {
		return (this.obj.style.display == "");
	}
	this.setItemText = function(text) {
		that._setItemText(this, text);
	}
	this.getItemText = function() {
		return that._getItemText(this);
	}
	this.setItemImage = function(url) {
		that._setItemImage(this, url, true);
	}
	this.clearItemImage = function() {
		that._clearItemImage(this, true);
	}
	this.setItemImageDis = function(url) {
		that._setItemImage(this, url, false);
	}
	this.clearItemImageDis = function() {
		that._clearItemImage(this, false);
	}
	this.setItemToolTip = function(tip) {
		this.obj.title = tip;
	}
	this.getItemToolTip = function() {
		return this.obj.title;
	}
	return this;
}
//#tool_list:06062008{
/* ****************************************************************************************************************************************************************
	object: buttonSelect
***************************************************************************************************************************************************************** */
dhtmlXToolbarObject.prototype._buttonSelectObject = function(that, id, data) {
	this.id = that.idPrefix+id;
	this.state = (data.enabled!=null?(data.enabled=="true"?true:false):true);
	this.imgEn = (data.img||"");
	this.imgDis = (data.imgdis||"");
	this.img = (this.state?(this.imgEn!=""?this.imgEn:""):(this.imgDis!=""?this.imgDis:""));
	
	this.mode = (data.mode||"button"); // button, select
	if (this.mode == "select") {
		this.openAll = true;
		this.renderSelect = false;
		if (!data.text||data.text.length==0) data.text = "&nbsp;"
	} else {
		this.openAll = (data.openAll=="true"||data.openAll==true||data.openAll==1||data.openAll=="1"||data.openAll=="yes"||data.openAll=="on");
		this.renderSelect = (data.renderSelect!=null?(data.renderSelect=="false"||data.renderSelect=="disabled"?false:true):true);
	}
	this.maxOpen = (!isNaN(data.maxOpen?data.maxOpen:"")?data.maxOpen:null);
	
	
	
	this._maxOpenTest = function() {
		if (!isNaN(this.maxOpen)) {
			if (!that._sbw) {
				var t = document.createElement("DIV");
				t.className = "dhxtoolbar_maxopen_test";
				document.body.appendChild(t);
				var k = document.createElement("DIV");
				k.className = "dhxtoolbar_maxopen_test2";
				t.appendChild(k);
				that._sbw = t.offsetWidth-k.offsetWidth;
				t.removeChild(k);
				k = null;
				document.body.removeChild(t);
				t = null;
			}
		}
	}
	this._maxOpenTest();
	
	//
	this.obj = document.createElement("DIV");
	this.obj.allowClick = false;
	this.obj.extAction = (data.action||null);
	this.obj.className = "dhx_toolbar_btn "+(this.state?"def":"dis");
	this.obj.style.display = (data.hidden!=null?"none":"");
	this.obj.renderAs = this.obj.className;
	this.obj.onselectstart = function(e) { e = e||event; e.returnValue = false; }
	this.obj.idd = String(id);
	this.obj.title = (data.title||"");
	this.obj.pressed = false;
	
	this.callEvent = false;
	
	
	
	this.obj.innerHTML = that._rtlParseBtn((this.img!=""?"<img src='"+that.imagePath+this.img+"'>":""),(data.text!=null?"<div>"+data.text+"</div>":""));
	
	// add object
	that.base.appendChild(this.obj);
	
	this.arw = document.createElement("DIV");
	this.arw.className = "dhx_toolbar_arw "+(this.state?"def":"dis");;
	this.arw.style.display = this.obj.style.display;
	this.arw.innerHTML = "<div class='arwimg'>&nbsp;</div>";
	
	this.arw.title = this.obj.title;
	this.arw.onselectstart = function(e) { e = e||event; e.returnValue = false; }
	that.base.appendChild(this.arw);
	
	var self = this;
	
	this.obj.onmouseover = function(e) {
		e = e||event;
		if (that.anyUsed != "none") return;
		if (!self.state) return;
		self.obj.renderAs = "dhx_toolbar_btn over";
		self.obj.className = self.obj.renderAs;
		self.arw.className = String(self.obj.renderAs).replace("btn","arw");
	}
	this.obj.onmouseout = function() {
		self.obj.allowClick = false;
		if (that.anyUsed != "none") return;
		if (!self.state) return;
		self.obj.renderAs = "dhx_toolbar_btn def";
		self.obj.className = self.obj.renderAs;
		self.arw.className = String(self.obj.renderAs).replace("btn","arw");
		self.callEvent = false;
	}
	this.arw.onmouseover = this.obj.onmouseover;
	this.arw.onmouseout = this.obj.onmouseout;
	
	if (this.openAll == true) {
		
	} else {
	
		this.obj.onclick = function(e) {
			e = e||event;
			if (!self.obj.allowClick) return;
			if (!self.state) return;
			if (that.anyUsed != "none") return;
			// event
			var id = self.obj.idd.replace(that.idPrefix,"");
			if (self.obj.extAction) try {window[self.obj.extAction](id);} catch(e){};
			that.callEvent("onClick", [id]);
		}
		this.obj[that._isIPad?"ontouchstart":"onmousedown"] = function(e) {
			e = e||event;
			if (that.anyUsed != "none") return;
			if (!self.state) return;
			self.obj.allowClick = true;
			self.obj.className = "dhx_toolbar_btn pres";
			self.arw.className = "dhx_toolbar_arw pres";
			self.callEvent = true;
		}
		this.obj[that._isIPad?"ontouchend":"onmouseup"] = function(e) {
			e = e||event;
			e.cancelBubble = true;
			if (that.anyUsed != "none") return;
			if (!self.state) return;
			self.obj.className = self.obj.renderAs;
			self.arw.className = String(self.obj.renderAs).replace("btn","arw");
			if (that._isIPad && self.callEvent) {
				var id = self.obj.idd.replace(that.idPrefix,"");
				that.callEvent("onClick", [id]);
			}
		}
		
	}
	
	if (that._isIPad) {
		this.obj.ontouchmove = this.obj.onmouseout;
	}
	
	this.arw[that._isIPad?"ontouchstart":"onmousedown"] = function(e) {
		e = e||event;
		
		//clickfix
		var st = (this.className.indexOf("dhx_toolbar_arw") === 0 ? this:this.nextSibling);
		if (st._skip) { e = e||event; e.cancelBubble = true; } else { st._skip = true; }
		st = null;
		
		if (!self.state) return;
		if (that.anyUsed == self.obj.idd) {
			// hide
			self.obj.className = self.obj.renderAs;
			self.arw.className = String(self.obj.renderAs).replace("btn","arw");
			that.anyUsed = "none";
			self.polygon.style.display = "none";
			if (self.polygon._ie6cover) self.polygon._ie6cover.style.display = "none";
			// fix border
			if (that.skin == "dhx_terrace") that._improveTerraceButtonSelect(self.id, true);
		} else { 
			if (that.anyUsed != "none") {
				if (that.objPull[that.idPrefix+that.anyUsed]["type"] == "buttonSelect") {
					var item = that.objPull[that.idPrefix+that.anyUsed];
					if (item.polygon.style.display != "none") {
						item.obj.renderAs = "dhx_toolbar_btn def";
						item.obj.className = item.obj.renderAs;
						item.arw.className = String(self.obj.renderAs).replace("btn","arw");
						item.polygon.style.display = "none";
						if (item.polygon._ie6cover) item.polygon._ie6cover.style.display = "none";
						// fix border
						if (that.skin == "dhx_terrace") that._improveTerraceButtonSelect(item.id, true);
					}
				}
			}
			self.obj.className = "dhx_toolbar_btn over";
			self.arw.className = "dhx_toolbar_arw pres";
			that.anyUsed = self.obj.idd;
			// show
			self.polygon.style.top = "0px";
			self.polygon.style.visibility = "hidden";
			self.polygon.style.display = "";
			// fix border
			if (that.skin == "dhx_terrace") that._improveTerraceButtonSelect(self.id, false);
			// check maxOpen
			self._fixMaxOpenHeight(self.maxOpen||null);
			// detect overlay by Y axis
			that._autoDetectVisibleArea();
			// calculate top position
			var newTop = getAbsoluteTop(self.obj)+self.obj.offsetHeight+that.selectPolygonOffsetTop;
			var newH = self.polygon.offsetHeight;
			if (newTop + newH > that.tY2) {
				// if maxOpen mode enabled, check if at bottom at least one item can be shown
				// and show it, if no space - show on top. in maxOpen mode not enabled, show at top
				var k0 = (self.maxOpen!=null?Math.floor((that.tY2-newTop)/22):0); // k0 = count of items that can be visible
				if (k0 >= 1) {
					self._fixMaxOpenHeight(k0);
				} else {
					newTop = getAbsoluteTop(self.obj)-newH-that.selectPolygonOffsetTop;
					if (newTop < 0) newTop = 0;
				}
			}
			self.polygon.style.top = newTop+"px";
			// calculate left position
			if (that.rtl) {
				self.polygon.style.left = getAbsoluteLeft(self.obj)+self.obj.offsetWidth-self.polygon.offsetWidth+that.selectPolygonOffsetLeft+"px";
			} else {
				var x1 = document.body.scrollLeft;
				var x2 = x1+(window.innerWidth||document.body.clientWidth);
				var newLeft = getAbsoluteLeft(self.obj)+that.selectPolygonOffsetLeft;
				if (newLeft+self.polygon.offsetWidth > x2) newLeft = getAbsoluteLeft(self.arw)+self.arw.offsetWidth-self.polygon.offsetWidth;
				self.polygon.style.left = newLeft+"px";
			}
			self.polygon.style.visibility = "visible";
			// show IE6 cover if needed
			if (self.polygon._ie6cover) {
				self.polygon._ie6cover.style.left = self.polygon.style.left;
				self.polygon._ie6cover.style.top = self.polygon.style.top;
				self.polygon._ie6cover.style.width = self.polygon.offsetWidth+"px";
				self.polygon._ie6cover.style.height = self.polygon.offsetHeight+"px";
				self.polygon._ie6cover.style.display = "";
			}
		}
		return false;
	}
	this.arw.onclick = function(e) {
		e = e||event;
		e.cancelBubble = true;
	}
	this.arw[that._isIPad?"ontouchend":"onmouseup"] = function(e) {
		e = e||event;
		e.cancelBubble = true;
	}
	
	
	if (this.openAll === true) {
		this.obj.onclick = this.arw.onclick;
		this.obj.onmousedown = this.arw.onmousedown;
		this.obj.onmouseup = this.arw.onmouseup;
		if (that._isIPad) {
			this.obj.ontouchstart = this.arw.ontouchstart;
			this.obj.ontouchend = this.arw.ontouchend;
		}
	}
	
	this.obj.iddPrefix = that.idPrefix;
	this._listOptions = {};
	
	this._fixMaxOpenHeight = function(maxOpen) {
		var h = "auto";
		var h0 = false;
		if (maxOpen !== null) {
			var t = 0;
			for (var a in this._listOptions) t++;
			if (t > maxOpen) {
				this._ph = 22*maxOpen;
				h = this._ph+"px";
			} else {
				h0 = true;
			}
		}
		this.polygon.style.width = "auto";
		this.polygon.style.height = "auto";
		if (!h0 && self.maxOpen != null) {
			this.polygon.style.width = this.p_tbl.offsetWidth+that._sbw+"px";
			this.polygon.style.height = h;
		}
	}
	
	// inner objects: separator
	this._separatorButtonSelectObject = function(id, data, pos) {
		
		this.obj = {};
		this.obj.tr = document.createElement("TR");
		this.obj.tr.className = "tr_sep";
		this.obj.tr.onselectstart = function(e) { e = e||event; e.returnValue = false; return false; }
		this.obj.td = document.createElement("TD");
		this.obj.td.colSpan = "2";
		this.obj.td.className = "td_btn_sep";
		this.obj.td.onselectstart = function(e) { e = e||event; e.returnValue = false; return false; }
		
		if (isNaN(pos)) pos = self.p_tbody.childNodes.length+1; else if (pos < 1) pos = 1;
		if (pos > self.p_tbody.childNodes.length) self.p_tbody.appendChild(this.obj.tr); else self.p_tbody.insertBefore(this.obj.tr, self.p_tbody.childNodes[pos-1]);
		
		this.obj.tr.appendChild(this.obj.td);
		
		this.obj.sep = document.createElement("DIV");
		this.obj.sep.className = "btn_sep";
		this.obj.sep.onselectstart = function(e) { e = e||event; e.returnValue = false; return false; }
		this.obj.td.appendChild(this.obj.sep);
		
		self._listOptions[id] = this.obj;
		return this;
	}
	// inner objects: button
	this._buttonButtonSelectObject = function(id, data, pos) {
		
		this.obj = {};
		this.obj.tr = document.createElement("TR");
		this.obj.tr.en = (data.enabled=="false"?false:(data.disabled=="true"?false:true));
		this.obj.tr.extAction = (data.action||null);
		this.obj.tr._selected = (data.selected!=null);
		this.obj.tr.className = "tr_btn"+(this.obj.tr.en?(this.obj.tr._selected&&self.renderSelect?" tr_btn_selected":""):" tr_btn_disabled");
		this.obj.tr.onselectstart = function(e) { e = e||event; e.returnValue = false; return false; }
		this.obj.tr.idd = String(id);
		
		if (data.userdata) this.obj.userData = data.userdata;
		
		if (isNaN(pos)) pos = self.p_tbody.childNodes.length+1; else if (pos < 1) pos = 1;
		if (pos > self.p_tbody.childNodes.length) self.p_tbody.appendChild(this.obj.tr); else self.p_tbody.insertBefore(this.obj.tr, self.p_tbody.childNodes[pos-1]);
		
		this.obj.td_a = document.createElement("TD");
		this.obj.td_a.className = "td_btn_img";
		this.obj.td_a.onselectstart = function(e) { e = e||event; e.returnValue = false; return false; }
		this.obj.td_b = document.createElement("TD");
		this.obj.td_b.className = "td_btn_txt";
		this.obj.td_b.onselectstart = function(e) { e = e||event; e.returnValue = false; return false; }
		
		if (that.rtl) {
			this.obj.tr.appendChild(this.obj.td_b);
			this.obj.tr.appendChild(this.obj.td_a);
		} else {
			this.obj.tr.appendChild(this.obj.td_a);
			this.obj.tr.appendChild(this.obj.td_b);
		}
		
		// image
		if (data.img != null) {
			this.obj.td_a.innerHTML = "<img class='btn_sel_img' src='"+that.imagePath+data.img+"' border='0'>";
			this.obj.tr._img = data.img;
		}
		
		// text
		var itemText = (data.text!=null?data.text:(data.itemText||""));
		/*
		if (itemText == null) {
			var itm = data.getElementsByTagName("itemText");
			itemText = (itm[0]!=null?itm[0].firstChild.nodeValue:"");
		}
		*/
		this.obj.td_b.innerHTML = "<div class='btn_sel_text'>"+itemText+"</div>";
		
		this.obj.tr[that._isIPad?"ontouchstart":"onmouseover"] = function() {
			if (!this.en || (this._selected && self.renderSelect)) return;
			this.className = "tr_btn tr_btn_over";
		}
		
		this.obj.tr.onmouseout = function() {
			if (!this.en) return;
			if (this._selected && self.renderSelect) {
				if (String(this.className).search("tr_btn_selected") == -1) this.className = "tr_btn tr_btn_selected";
			} else {
				this.className = "tr_btn";
			}
		}
		
		this.obj.tr[that._isIPad?"ontouchend":"onclick"] = function(e) {
			
			e = e||event;
			e.cancelBubble = true;
			if (!this.en) return;
			
			self.setListOptionSelected(this.idd.replace(that.idPrefix,""));
			//
			self.obj.renderAs = "dhx_toolbar_btn def";
			self.obj.className = self.obj.renderAs;
			self.arw.className = String(self.obj.renderAs).replace("btn","arw");
			self.polygon.style.display = "none";
			if (self.polygon._ie6cover) self.polygon._ie6cover.style.display = "none";
			// fix border
			if (that.skin == "dhx_terrace") that._improveTerraceButtonSelect(self.id, true);			
			that.anyUsed = "none";
			// event
			var id = this.idd.replace(that.idPrefix,"");
			if (this.extAction) try {window[this.extAction](id);} catch(e){};
			that.callEvent("onClick", [id]);
		}		
		self._listOptions[id] = this.obj;
		
		return this;
		
	}
	
	// add polygon
	this.polygon = document.createElement("DIV");
	this.polygon.dir = "ltr";
	this.polygon.style.display = "none";
	this.polygon.style.zIndex = 101;
	this.polygon.className = "dhx_toolbar_poly_"+that.iconSize+"_"+that.skin+(that.rtl?" rtl":"");
	this.polygon.onselectstart = function(e) { e = e||event; e.returnValue = false; }
	this.polygon.onmousedown = function(e) { e = e||event; e.cancelBubble = true; }
	this.polygon.style.overflowY = "auto";
	
	if (that._isIPad) {
		this.polygon.ontouchstart = function(e){
			e = e||event;
			e.returnValue = false;
			e.cancelBubble = true;
			return false;
		}
	}
	
	
	
	this.p_tbl = document.createElement("TABLE");
	this.p_tbl.className = "buttons_cont";
	this.p_tbl.cellSpacing = "0";
	this.p_tbl.cellPadding = "0";
	this.p_tbl.border = "0";
	this.polygon.appendChild(this.p_tbl);
	
	this.p_tbody = document.createElement("TBODY");
	this.p_tbl.appendChild(this.p_tbody);
	
	//
	if (data.items) {
		for (var q=0; q<data.items.length; q++) {
			var t = "_"+(data.items[q].type||"")+"ButtonSelectObject";
			if (typeof(this[t]) == "function") new this[t](data.items[q].id||that._genStr(24),data.items[q]);
		}
	}
	
	document.body.appendChild(this.polygon);
	
	// add poly ie6cover
	if (that._isIE6) {
		this.polygon._ie6cover = document.createElement("IFRAME");
		this.polygon._ie6cover.frameBorder = 0;
		this.polygon._ie6cover.style.position = "absolute";
		this.polygon._ie6cover.style.border = "none";
		this.polygon._ie6cover.style.backgroundColor = "#000000";
		this.polygon._ie6cover.style.filter = "alpha(opacity=100)";
		this.polygon._ie6cover.style.display = "none";
		this.polygon._ie6cover.setAttribute("src","javascript:false;");
		document.body.appendChild(this.polygon._ie6cover);
	}
	
	// functions
	// new engine
	this.setWidth = function(width) {
		this.obj.style.width = width-this.arw.offsetWidth+"px";
		this.polygon.style.width = this.obj.offsetWidth+this.arw.offsetWidth-2+"px";
		this.p_tbl.style.width = this.polygon.style.width;
	}
	this.enableItem = function() {
		that._enableItem(this);
	}
	this.disableItem = function() {
		that._disableItem(this);
	}
	this.isEnabled = function() {
		return this.state;
	}
	this.showItem = function() {
		this.obj.style.display = "";
		this.arw.style.display = "";
	}
	this.hideItem = function() {
		this.obj.style.display = "none";
		this.arw.style.display = "none";
	}
	this.isVisible = function() {
		return (this.obj.style.display == "");
	}
	this.setItemText = function(text) {
		that._setItemText(this, text);
	}
	this.getItemText = function() {
		return that._getItemText(this);
	}
	this.setItemImage = function(url) {
		that._setItemImage(this, url, true);
	}
	this.clearItemImage = function() {
		that._clearItemImage(this, true);
	}
	this.setItemImageDis = function(url) {
		that._setItemImage(this, url, false);
	}
	this.clearItemImageDis = function() {
		that._clearItemImage(this, false);
	}
	this.setItemToolTip = function(tip) {
		this.obj.title = tip;
		this.arw.title = tip;
	}
	this.getItemToolTip = function() {
		return this.obj.title;
	}
	/* list option functions */
	// new engine
	this.addListOption = function(id, pos, type, text, img) {
		if (!(type == "button" || type == "separator")) return;
		var dataItem = {id:id,type:type,text:text,img:img};
		new this["_"+type+"ButtonSelectObject"](id, dataItem, pos);
	}
	// new engine
	this.removeListOption = function(id) {
		if (!this._isListButton(id, true)) return;
		var item = this._listOptions[id];
		if (item.td_a != null && item.td_b != null) {
			// button
			item.td_a.onselectstart = null;
			item.td_b.onselectstart = null;
			while (item.td_a.childNodes.length > 0) item.td_a.removeChild(item.td_a.childNodes[0]);
			while (item.td_b.childNodes.length > 0) item.td_b.removeChild(item.td_b.childNodes[0]);
			item.tr.onselectstart = null;
			item.tr.onmouseover = null;
			item.tr.onmouseout = null;
			item.tr.onclick = null;
			while (item.tr.childNodes.length > 0) item.tr.removeChild(item.tr.childNodes[0]);
			item.tr.parentNode.removeChild(item.tr);
			item.td_a = null;
			item.td_b = null;
			item.tr = null;
		} else {
			// separator
			item.sep.onselectstart = null;
			item.td.onselectstart = null;
			item.tr.onselectstart = null;
			while (item.td.childNodes.length > 0) item.td.removeChild(item.td.childNodes[0]);
			while (item.tr.childNodes.length > 0) item.tr.removeChild(item.tr.childNodes[0]);
			item.tr.parentNode.removeChild(item.tr);
			item.sep = null;
			item.td = null;
			item.tr = null;
		}
		item = null;
		this._listOptions[id] = null;
		try { delete this._listOptions[id]; } catch(e) {}
	}
	// new engine
	this.showListOption = function(id) {
		if (!this._isListButton(id, true)) return;
		this._listOptions[id].tr.style.display = "";
	}
	// new engine
	this.hideListOption = function(id) {
		if (!this._isListButton(id, true)) return;
		this._listOptions[id].tr.style.display = "none";
	}
	// new engine
	this.isListOptionVisible = function(id) {
		if (!this._isListButton(id, true)) return;
		return (this._listOptions[id].tr.style.display != "none");
	}
	// new engine
	this.enableListOption = function(id) {
		if (!this._isListButton(id)) return;
		this._listOptions[id].tr.en = true;
		this._listOptions[id].tr.className = "tr_btn"+(this._listOptions[id].tr._selected&&that.renderSelect?" tr_btn_selected":"");
	}
	// new engine
	this.disableListOption = function(id) {
		if (!this._isListButton(id)) return;
		this._listOptions[id].tr.en = false;
		this._listOptions[id].tr.className = "tr_btn tr_btn_disabled";
	}
	// new engine
	this.isListOptionEnabled = function(id) {
		if (!this._isListButton(id)) return;
		return this._listOptions[id].tr.en;
	}
	// new engine
	this.setListOptionPosition = function(id, pos) {
		if (!this._listOptions[id] || this.getListOptionPosition(id) == pos || isNaN(pos)) return;
		if (pos < 1) pos = 1;
		var tr = this._listOptions[id].tr;
		this.p_tbody.removeChild(tr);
		if (pos > this.p_tbody.childNodes.length) this.p_tbody.appendChild(tr); else this.p_tbody.insertBefore(tr, this.p_tbody.childNodes[pos-1]);
		tr = null;
	}
	// new engine
	this.getListOptionPosition = function(id) {
		var pos = -1;
		if (!this._listOptions[id]) return pos;
		for (var q=0; q<this.p_tbody.childNodes.length; q++) if (this.p_tbody.childNodes[q] == this._listOptions[id].tr) pos=q+1;
		return pos;
	}
	// new engine
	this.setListOptionImage = function(id, img) {
		if (!this._isListButton(id)) return;
		var td = this._listOptions[id].tr.childNodes[(that.rtl?1:0)];
		if (td.childNodes.length > 0) {
			td.childNodes[0].src = that.imagePath+img;
		} else {
			var imgObj = document.createElement("IMG");
			imgObj.className = "btn_sel_img";
			imgObj.src = that.imagePath+img;
			td.appendChild(imgObj);
		}
		td = null;
	}
	// new engine
	this.getListOptionImage = function(id) {
		if (!this._isListButton(id)) return;
		var td = this._listOptions[id].tr.childNodes[(that.rtl?1:0)];
		var src = null;
		if (td.childNodes.length > 0) src = td.childNodes[0].src;
		td = null;
		return src;
	}
	// new engine
	this.clearListOptionImage = function(id) {
		if (!this._isListButton(id)) return;
		var td = this._listOptions[id].tr.childNodes[(that.rtl?1:0)];
		while (td.childNodes.length > 0) td.removeChild(td.childNodes[0]);
		td = null;
	}
	// new engine
	this.setListOptionText = function(id, text) {
		if (!this._isListButton(id)) return;
		this._listOptions[id].tr.childNodes[(that.rtl?0:1)].childNodes[0].innerHTML = text;
	}
	// new engine
	this.getListOptionText = function(id) {
		if (!this._isListButton(id)) return;
		return this._listOptions[id].tr.childNodes[(that.rtl?0:1)].childNodes[0].innerHTML;
	}
	// new engine
	this.setListOptionToolTip = function(id, tip) {
		if (!this._isListButton(id)) return;
		this._listOptions[id].tr.title = tip;
	}
	// new engine
	this.getListOptionToolTip = function(id) {
		if (!this._isListButton(id)) return;
		return this._listOptions[id].tr.title;
	}
	// works
	this.forEachListOption = function(handler) {
		for (var a in this._listOptions) handler(a);
	}
	// works, return array with ids
	this.getAllListOptions = function() {
		var listData = new Array();
		for (var a in this._listOptions) listData[listData.length] = a;
		return listData;
	}
	// new engine
	this.setListOptionSelected = function(id) {
		for (var a in this._listOptions) {
			var item = this._listOptions[a];
			if (item.td_a != null && item.td_b != null && item.tr.en) {
				if (a == id) {
					item.tr._selected = true;
					item.tr.className = "tr_btn"+(this.renderSelect?" tr_btn_selected":"");
					//
					if (this.mode == "select") {
						if (item.tr._img) this.setItemImage(item.tr._img); else this.clearItemImage();
						this.setItemText(this.getListOptionText(id));
					}
				} else {
					item.tr._selected = false;
					item.tr.className = "tr_btn";
				}
			}
			item = null;
		}
	}
	// new engine
	this.getListOptionSelected = function() {
		var id = null;
		for (var a in this._listOptions) if (this._listOptions[a].tr._selected == true) id = a;
		return id;
	}
	// inner, return tru if list option is button and is exists
	this._isListButton = function(id, allowSeparator) {
		if (this._listOptions[id] == null) return false;
		if (!allowSeparator && this._listOptions[id].tr.className == "tr_sep") return false;
		return true;
	}
	
	this.setMaxOpen = function(r) {
		this._ph = null;
		if (typeof(r) == "number") {
			this.maxOpen = r;
			this._maxOpenTest();
			return;
		}
		this.maxOpen = null;
	}
	
	if (data.width) this.setWidth(data.width);
	
	if (this.mode == "select" && typeof(data.selected) != "undefined") this.setListOptionSelected(data.selected);
	
	//
	return this;
}
//#}
	
//#tool_input:06062008{
/*****************************************************************************************************************************************************************
	object: buttonInput
***************************************************************************************************************************************************************** */
dhtmlXToolbarObject.prototype._buttonInputObject = function(that, id, data) {
	//
	this.id = that.idPrefix+id;
	this.obj = document.createElement("DIV");
	this.obj.className = "dhx_toolbar_btn def";
	this.obj.style.display = (data.hidden!=null?"none":"");
	this.obj.idd = String(id);
	this.obj.w = (data.width!=null?data.width:100);
	this.obj.title = (data.title!=null?data.title:"");
	//
	this.obj.innerHTML = "<input class='inp' type='text' style='-moz-user-select:text;width:"+this.obj.w+"px;'"+(data.value!=null?" value='"+data.value+"'":"")+">";
	
	var th = that;
	var self = this;
	this.obj.childNodes[0].onkeydown = function(e) {
		e = e||event;
		if (e.keyCode == 13) { th.callEvent("onEnter", [self.obj.idd, this.value]); }
	}
	// add
	that.base.appendChild(this.obj);
	//
	this.enableItem = function() {
		this.obj.childNodes[0].disabled = false;
	}
	this.disableItem = function() {
		this.obj.childNodes[0].disabled = true;
	}
	this.isEnabled = function() {
		return (!this.obj.childNodes[0].disabled);
	}
	this.showItem = function() {
		this.obj.style.display = "";
	}
	this.hideItem = function() {
		this.obj.style.display = "none";
	}
	this.isVisible = function() {
		return (this.obj.style.display != "none");
	}
	this.setValue = function(value) {
		this.obj.childNodes[0].value = value;
	}
	this.getValue = function() {
		return this.obj.childNodes[0].value;
	}
	this.setWidth = function(width) {
		this.obj.w = width;
		this.obj.childNodes[0].style.width = this.obj.w+"px";
	}
	this.getWidth = function() {
		return this.obj.w;
	}
	this.setItemToolTip = function(tip) {
		this.obj.title = tip;
	}
	this.getItemToolTip = function() {
		return this.obj.title;
	}
	this.getInput = function() {
		return this.obj.firstChild;
	}
	//
	return this;
}
//#}
//#tool_2state:06062008{
/*****************************************************************************************************************************************************************
	object: buttonTwoState
***************************************************************************************************************************************************************** */
dhtmlXToolbarObject.prototype._buttonTwoStateObject = function(that, id, data) {
	this.id = that.idPrefix+id;
	this.state = (data.enabled!=null?false:true);
	this.imgEn = (data.img!=null?data.img:"");
	this.imgDis = (data.imgdis!=null?data.imgdis:"");
	this.img = (this.state?(this.imgEn!=""?this.imgEn:""):(this.imgDis!=""?this.imgDis:""));
	//
	this.obj = document.createElement("DIV");
	this.obj.pressed = (data.selected!=null);
	this.obj.extAction = (data.action||null);
	this.obj.className = "dhx_toolbar_btn "+(this.obj.pressed?"pres"+(this.state?"":"_dis"):(this.state?"def":"dis"));
	this.obj.style.display = (data.hidden!=null?"none":"");
	this.obj.renderAs = this.obj.className;
	this.obj.idd = String(id);
	this.obj.title = (data.title||"");
	if (this.obj.pressed) { this.obj.renderAs = "dhx_toolbar_btn over"; }
	
	this.obj.innerHTML = that._rtlParseBtn((this.img!=""?"<img src='"+that.imagePath+this.img+"'>":""),(data.text!=null?"<div>"+data.text+"</div>":""));
	
	// add object
	that.base.appendChild(this.obj);
	
	var obj = this;
	
	this.obj.onselectstart = function(e) { e = e||event; e.returnValue = false; }
	this.obj.onmouseover = function() { this._doOnMouseOver(); }
	this.obj.onmouseout = function() { this._doOnMouseOut(); }
	this.obj._doOnMouseOver = function() {
		if (obj.state == false) return;
		if (that.anyUsed != "none") return;
		if (this.pressed) {
			this.renderAs = "dhx_toolbar_btn over";
			return;
		}
		this.className = "dhx_toolbar_btn over";
		this.renderAs = this.className;
	}
	this.obj._doOnMouseOut = function() {
		if (obj.state == false) return;
		if (that.anyUsed != "none") return;
		if (this.pressed) {
			this.renderAs = "dhx_toolbar_btn def";
			return;
		}
		this.className = "dhx_toolbar_btn def";
		this.renderAs = this.className;
	}
	this.obj[that._isIPad?"ontouchstart":"onmousedown"] = function(e) {
		
		if (that.checkEvent("onBeforeStateChange")) if (!that.callEvent("onBeforeStateChange", [this.idd.replace(that.idPrefix, ""), this.pressed])) return;
		//
		if (obj.state == false) return;
		if (that.anyUsed != "none") return;
		this.pressed = !this.pressed;
		this.className = (this.pressed?"dhx_toolbar_btn pres":this.renderAs);
		
		// event
		var id = this.idd.replace(that.idPrefix, "");
		if (this.extAction) try {window[this.extAction](id, this.pressed);} catch(e){};
		that.callEvent("onStateChange", [id, this.pressed]);
		//this._doOnMouseOut();
		return false;
	}
	
	// functions
	this.setItemState = function(state, callEvent) {
		if (this.obj.pressed != state) {
			if (state == true) {
				this.obj.pressed = true;
				this.obj.className = "dhx_toolbar_btn pres"+(this.state?"":"_dis");
				this.obj.renderAs = "dhx_toolbar_btn over";
			} else {
				this.obj.pressed = false;
				this.obj.className = "dhx_toolbar_btn "+(this.state?"def":"dis");
				this.obj.renderAs = this.obj.className;
			}
			if (callEvent == true) {
				var id = this.obj.idd.replace(that.idPrefix, "");
				if (this.obj.extAction) try {window[this.obj.extAction](id, this.obj.pressed);} catch(e){};
				that.callEvent("onStateChange", [id, this.obj.pressed]);
			}
		}
	}
	this.getItemState = function() {
		return this.obj.pressed;
	}
	this.enableItem = function() {
		that._enableItem(this);
	}
	this.disableItem = function() {
		that._disableItem(this);
	}
	this.isEnabled = function() {
		return this.state;
	}
	this.showItem = function() {
		this.obj.style.display = "";
	}
	this.hideItem = function() {
		this.obj.style.display = "none";
	}
	this.isVisible = function() {
		return (this.obj.style.display == "");
	}
	this.setItemText = function(text) {
		that._setItemText(this, text);
	}
	this.getItemText = function() {
		return that._getItemText(this);
	}
	this.setItemImage = function(url) {
		that._setItemImage(this, url, true);
	}
	this.clearItemImage = function() {
		that._clearItemImage(this, true);
	}
	this.setItemImageDis = function(url) {
		that._setItemImage(this, url, false);
	}
	this.clearItemImageDis = function() {
		that._clearItemImage(this, false);
	}
	this.setItemToolTip = function(tip) {
		this.obj.title = tip;
	}
	this.getItemToolTip = function() {
		return this.obj.title;
	}
	//
	return this;
}
//#}
//#tool_slider:06062008{
/*****************************************************************************************************************************************************************
	object: slider
***************************************************************************************************************************************************************** */
dhtmlXToolbarObject.prototype._sliderObject = function(that, id, data) {
	this.id = that.idPrefix+id;
	this.state = (data.enabled!=null?(data.enabled=="true"?true:false):true);
	this.obj = document.createElement("DIV");
	this.obj.className = "dhx_toolbar_btn "+(this.state?"def":"dis");
	this.obj.style.display = (data.hidden!=null?"none":"");
	this.obj.onselectstart = function(e) { e = e||event; e.returnValue = false; }
	this.obj.idd = String(id);
	this.obj.len = (data.length!=null?Number(data.length):50);
	//
	this.obj.innerHTML = "<div>"+(data.textMin||"")+"</div>"+
				"<div class='sl_bg_l'></div>"+
				"<div class='sl_bg_m' style='width:"+this.obj.len+"px;'></div>"+
				"<div class='sl_bg_r'></div>"+
				"<div>"+(data.textMax||"")+"</div>";
	// add object
	that.base.appendChild(this.obj);
	var self = this;
	
	this.pen = document.createElement("DIV");
	this.pen.className = "sl_pen";
	this.obj.appendChild(this.pen);
	var pen = this.pen;
	
	this.label = document.createElement("DIV");
	this.label.dir = "ltr";
	this.label.className = "dhx_toolbar_slider_label_"+that.skin+(that.rtl?"_rtl":"");
	this.label.style.display = "none";
	this.label.tip = (data.toolTip||"%v");
	document.body.appendChild(this.label);
	var label = this.label;
	
	// mix-max value
	this.pen.valueMin = (data.valueMin!=null?Number(data.valueMin):0);
	this.pen.valueMax = (data.valueMax!=null?Number(data.valueMax):100);
	if (this.pen.valueMin > this.pen.valueMax) this.pen.valueMin = this.pen.valueMax;
	
	// init value
	this.pen.valueNow = (data.valueNow!=null?Number(data.valueNow):this.pen.valueMax);
	if (this.pen.valueNow > this.pen.valueMax) this.pen.valueNow = this.pen.valueMax;
	if (this.pen.valueNow < this.pen.valueMin) this.pen.valueNow = this.pen.valueMin;
	
	// min/max x coordinate
	this.pen._detectLimits = function() {
		this.minX = self.obj.childNodes[1].offsetLeft-4;
		this.maxX = self.obj.childNodes[3].offsetLeft-this.offsetWidth+1;
	}
	this.pen._detectLimits();
	
	// position
	this.pen._definePos = function() {
		this.nowX = Math.round((this.valueNow-this.valueMin)*(this.maxX-this.minX)/(this.valueMax-this.valueMin)+this.minX);
		this.style.left = this.nowX+"px";
		this.newNowX = this.nowX;
	}
	this.pen._definePos();

	this.pen.initXY = 0;
	this.pen.allowMove = false;
	this.pen[that._isIPad?"ontouchstart":"onmousedown"] = function(e) {
		if (self.state == false) return;
		e = e||event;
		this.initXY = (that._isIPad?e.touches[0].clientX:e.clientX); //e.clientX;
		this.newValueNow = this.valueNow;
		this.allowMove = true;
		this.className = "sl_pen over";
		if (label.tip != "") {
			label.style.visibility = "hidden";
			label.style.display = "";
			label.innerHTML = label.tip.replace("%v", this.valueNow);
			label.style.left = Math.round(getAbsoluteLeft(this)+this.offsetWidth/2-label.offsetWidth/2)+"px";
			label.style.top = getAbsoluteTop(this)-label.offsetHeight-3+"px";
			label.style.visibility = "";
		}
	}
	
	this.pen._doOnMouseMoveStart = function(e) {
		// optimized for destructor
		e=e||event;
		if (!pen.allowMove) return;
		var ecx = (that._isIPad?e.touches[0].clientX:e.clientX);
		var ofst = ecx - pen.initXY;
		
		// mouse goes out to left/right from pen
		if (ecx < getAbsoluteLeft(pen)+Math.round(pen.offsetWidth/2) && pen.nowX == pen.minX) return;
		if (ecx > getAbsoluteLeft(pen)+Math.round(pen.offsetWidth/2) && pen.nowX == pen.maxX) return;
		
		pen.newNowX = pen.nowX + ofst;
		
		if (pen.newNowX < pen.minX) pen.newNowX = pen.minX;
		if (pen.newNowX > pen.maxX) pen.newNowX = pen.maxX;
		pen.nowX = pen.newNowX;
		pen.style.left = pen.nowX+"px";
		pen.initXY = ecx;
		pen.newValueNow = Math.round((pen.valueMax-pen.valueMin)*(pen.newNowX-pen.minX)/(pen.maxX-pen.minX)+pen.valueMin);
		if (label.tip != "") {
			label.innerHTML = label.tip.replace(/%v/gi, pen.newValueNow);
			label.style.left = Math.round(getAbsoluteLeft(pen)+pen.offsetWidth/2-label.offsetWidth/2)+"px";
			label.style.top = getAbsoluteTop(pen)-label.offsetHeight-3+"px";
		}
		e.cancelBubble = true;
		e.returnValue = false;
		return false;
	}
	this.pen._doOnMouseMoveEnd = function() {
		if (!pen.allowMove) return;
		pen.className = "sl_pen";
		pen.allowMove = false;
		pen.nowX = pen.newNowX;
		pen.valueNow = pen.newValueNow;
		if (label.tip != "") label.style.display = "none";
		that.callEvent("onValueChange", [self.obj.idd.replace(that.idPrefix, ""), pen.valueNow]);
	}
	
	if (that._isIPad) {
		document.addEventListener("touchmove", pen._doOnMouseMoveStart, false);
		document.addEventListener("touchend", pen._doOnMouseMoveEnd, false);
	} else {
		if (typeof(window.addEventListener) != "undefined") {
			window.addEventListener("mousemove", pen._doOnMouseMoveStart, false);
			window.addEventListener("mouseup", pen._doOnMouseMoveEnd, false);
		} else {
			document.body.attachEvent("onmousemove", pen._doOnMouseMoveStart);
			document.body.attachEvent("onmouseup", pen._doOnMouseMoveEnd);
		}
	}
	// functions
	this.enableItem = function() {
		if (this.state) return;
		this.state = true;
		this.obj.className = "dhx_toolbar_btn def";
	}
	this.disableItem = function() {
		if (!this.state) return;
		this.state = false;
		this.obj.className = "dhx_toolbar_btn dis";
	}
	this.isEnabled = function() {
		return this.state;
	}
	this.showItem = function() {
		this.obj.style.display = "";
	}
	this.hideItem = function() {
		this.obj.style.display = "none";
	}
	this.isVisible = function() {
		return (this.obj.style.display == "");
	}
	this.setValue = function(value, callEvent) {
		value = Number(value);
		if (value < this.pen.valueMin) value = this.pen.valueMin;
		if (value > this.pen.valueMax) value = this.pen.valueMax;
		this.pen.valueNow = value;
		this.pen._definePos();
		if (callEvent == true) that.callEvent("onValueChange", [this.obj.idd.replace(that.idPrefix, ""), this.pen.valueNow]);
	}
	this.getValue = function() {
		return this.pen.valueNow;
	}
	this.setMinValue = function(value, label) {
		value = Number(value);
		if (value > this.pen.valueMax) return;
		this.obj.childNodes[0].innerHTML = label;
		this.obj.childNodes[0].style.display = (label.length>0?"":"none");
		this.pen.valueMin = value;
		if (this.pen.valueNow < this.pen.valueMin) this.pen.valueNow = this.pen.valueMin;
		this.pen._detectLimits();
		this.pen._definePos();
	}
	this.setMaxValue = function(value, label) {
		value = Number(value);
		if (value < this.pen.valueMin) return;
		this.obj.childNodes[4].innerHTML = label;
		this.obj.childNodes[4].style.display = (label.length>0?"":"none");
		this.pen.valueMax = value;
		if (this.pen.valueNow > this.pen.valueMax) this.pen.valueNow = this.pen.valueMax;
		this.pen._detectLimits();
		this.pen._definePos();
	}
	this.getMinValue = function() {
		var label = this.obj.childNodes[0].innerHTML;
		var value = this.pen.valueMin;
		return new Array(value, label);
	}
	this.getMaxValue = function() {
		var label = this.obj.childNodes[4].innerHTML;
		var value = this.pen.valueMax;
		return new Array(value, label);
	}
	this.setItemToolTipTemplate = function(template) {
		this.label.tip = template;
	}
	this.getItemToolTipTemplate = function() {
		return this.label.tip;
	}
	//
	return this;
}
//#}
dhtmlXToolbarObject.prototype.unload = function() {
	
	if (this._isIPad) {
		document.removeEventListener("touchstart", this._doOnClick, false);
	} else {
		if (typeof(window.addEventListener) == "function") {
			window.removeEventListener("mousedown", this._doOnClick, false);
		} else {
			document.body.detachEvent("onmousedown", this._doOnClick);
		}
	}
	this._doOnClick = null;
	
	this.clearAll();
	this.objPull = null;
	
	if (this._xmlLoader) {
		this._xmlLoader.destructor();
		this._xmlLoader = null;
	}
	
	while (this.base.childNodes.length > 0) this.base.removeChild(this.base.childNodes[0]);
	this.cont.removeChild(this.base);
	this.base = null;
	
	while (this.cont.childNodes.length > 0) this.cont.removeChild(this.cont.childNodes[0]);
	this.cont.className = "";
	this.cont = null;
	
	this.detachAllEvents();
	
	this.tX1 = null;
	this.tX2 = null;
	this.tY1 = null;
	this.tY2 = null;
	
	this._isIE6 = null;
	this._isWebToolbar = null;
	
	this.align = null;
	this.anyUsed = null;
	this.idPrefix = null;
	this.imagePath = null;
	this.rootTypes = null;
	this.selectPolygonOffsetLeft = null;
	this.selectPolygonOffsetTop = null;
	this.skin = null;
	
	this._rtl = null;
	this._rtlParseBtn = null;
	this.setRTL = null;
	
	this._sbw = null;
	this._getObj = null;
	this._addImgObj = null;
	this._setItemImage = null;
	this._clearItemImage = null;
	this._setItemText = null;
	this._getItemText = null;
	this._enableItem = null;
	this._disableItem = null;
	this._xmlParser = null;
	this._doOnLoad = null;
	this._addItemToStorage = null;
	this._genStr = null;
	this._addItem = null;
	this._getPosition = null;
	this._setPosition = null;
	this._getIdByPosition = null;
	this._separatorObject = null;
	this._textObject = null;
	this._buttonObject = null;
	this._buttonSelectObject = null;
	this._buttonInputObject = null;
	this._buttonTwoStateObject = null;
	this._sliderObject = null;
	this._autoDetectVisibleArea = null;
	this._removeItem = null;
	// this._parseXMLUserData = null;
	this.setAlign = null;
	this.setSkin = null;
	this.setIconsPath = null;
	this.setIconPath = null;
	this.loadXML = null;
	this.loadXMLString = null;
	this.attachEvent = null;
	this.callEvent = null;
	this.checkEvent = null;
	this.eventCatcher = null;
	this.detachEvent = null;
	this.detachAllEvents = null;
	this.clearAll = null;
	this.addSpacer = null;
	this.removeSpacer = null;
	this.getType = null;
	this.getTypeExt = null;
	this.inArray = null;
	this.getParentId = null;
	this.addButton = null;
	this.addText = null;
	this.addButtonSelect = null;
	this.addButtonTwoState = null;
	this.addSeparator = null;
	this.addSlider = null;
	this.addInput = null;
	this.forEachItem = null;
	this.showItem = null;
	this.hideItem = null;
	this.isVisible = null;
	this.enableItem = null;
	this.disableItem = null;
	this.isEnabled = null;
	this.setItemText = null;
	this.getItemText = null;
	this.setItemToolTip = null;
	this.getItemToolTip = null;
	this.setItemImage = null;
	this.setItemImageDis = null;
	this.clearItemImage = null;
	this.clearItemImageDis = null;
	this.setItemState = null;
	this.getItemState = null;
	this.setItemToolTipTemplate = null;
	this.getItemToolTipTemplate = null;
	this.setValue = null;
	this.getValue = null;
	this.setMinValue = null;
	this.getMinValue = null;
	this.setMaxValue = null;
	this.getMaxValue = null;
	this.setWidth = null;
	this.getWidth = null;
	this.getPosition = null;
	this.setPosition = null;
	this.removeItem = null;
	this.addListOption = null;
	this.removeListOption = null;
	this.showListOption = null;
	this.hideListOption = null;
	this.isListOptionVisible = null;
	this.enableListOption = null;
	this.disableListOption = null;
	this.isListOptionEnabled = null;
	this.setListOptionPosition = null;
	this.getListOptionPosition = null;
	this.setListOptionText = null;
	this.getListOptionText = null;
	this.setListOptionToolTip = null;
	this.getListOptionToolTip = null;
	this.setListOptionImage = null;
	this.getListOptionImage = null;
	this.clearListOptionImage = null;
	this.forEachListOption = null;
	this.getAllListOptions = null;
	this.setListOptionSelected = null;
	this.getListOptionSelected = null;
	this.unload = null;
	this.setUserData = null;
	this.getUserData = null;
	this.setMaxOpen = null;
	this.items = null;
	
};

dhtmlXToolbarObject.prototype._autoDetectVisibleArea = function() {
	this.tX1 = document.body.scrollLeft;
	this.tX2 = this.tX1+(window.innerWidth||document.body.clientWidth);
	this.tY1 = Math.max((_isIE?document.documentElement:document.getElementsByTagName("html")[0]).scrollTop, document.body.scrollTop);
	this.tY2 = this.tY1+(_isIE?Math.max(document.documentElement.clientHeight||0,document.documentElement.offsetHeight||0,document.body.clientHeight||0):window.innerHeight);
};

// user data start
dhtmlXToolbarObject.prototype.setUserData = function(id, name, value) {
	if (this.objPull[this.idPrefix+id] == null) return;
	var item = this.objPull[this.idPrefix+id];
	if (item.userData == null) item.userData = {};
	item.userData[name] = value;
};
dhtmlXToolbarObject.prototype.getUserData = function(id, name) {
	if (this.objPull[this.idPrefix+id] == null) return null;
	if (this.objPull[this.idPrefix+id].userData == null) return null;
	if (this.objPull[this.idPrefix+id].userData[name] == null) return null;
	return this.objPull[this.idPrefix+id].userData[name];
};
// userdata for listed options
dhtmlXToolbarObject.prototype._isListOptionExists = function(listId, optionId) {
	if (this.objPull[this.idPrefix+listId] == null) return false;
	var item = this.objPull[this.idPrefix+listId];
	if (item.type != "buttonSelect") return false;
	if (item._listOptions[optionId] == null) return false;
	return true;
};
dhtmlXToolbarObject.prototype.setListOptionUserData = function(listId, optionId, name, value) {
	// is exists?
	if (!this._isListOptionExists(listId, optionId)) return;
	// set userdata
	var opt = this.objPull[this.idPrefix+listId]._listOptions[optionId];
	if (opt.userData == null) opt.userData = {};
	opt.userData[name] = value;
};
dhtmlXToolbarObject.prototype.getListOptionUserData = function(listId, optionId, name) {
	// is exists?
	if (!this._isListOptionExists(listId, optionId)) return null;
	// get userdata
	var opt = this.objPull[this.idPrefix+listId]._listOptions[optionId];
	if (!opt.userData) return null;
	return (opt.userData[name]?opt.userData[name]:null);
};

// user data end


//toolbar
(function(){
	dhtmlx.extend_api("dhtmlXToolbarObject",{
		_init:function(obj){
			return [obj.parent, obj.skin];
		},
		icon_path:"setIconsPath",
		xml:"loadXML",
		items:"items",
		align:"setAlign",
		rtl:"setRTL",
		skin:"setSkin"
	},{
		items:function(arr){
			for (var i=0; i < arr.length; i++) {
				var item = arr[i];
				if (item.type == "button") this.addButton(item.id, null, item.text, item.img, item.img_disabled);
				if (item.type == "separator") this.addSeparator(item.id, null);
				if (item.type == "text") this.addText(item.id, null, item.text);
				if (item.type == "buttonSelect") this.addButtonSelect(item.id, null, item.text, item.options, item.img, item.img_disabled, item.renderSelect, item.openAll, item.maxOpen);
				if (item.type == "buttonTwoState") this.addButtonTwoState(item.id, null, item.text, item.img, item.img_disabled);
				if (item.type == "buttonInput") this.addInput(item.id, null, item.text);
				if (item.type == "slider") this.addSlider(item.id, null, item.length, item.value_min, item.value_max, item.value_now, item.text_min, item.text_max, item.tip_template);
				//
				if (item.width) this.setWidth(item.id, item.width);
				if (item.disabled) this.disableItem(item.id);
				if (item.tooltip) this.setItemToolTip(item.id, item.tooltip);
				if (item.pressed === true) this.setItemState(item.id, true);
			}
		}
	});
})();