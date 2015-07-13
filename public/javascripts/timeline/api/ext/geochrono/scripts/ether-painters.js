/*==================================================
 *  Geochrono Ether Painter
 *==================================================
 */
 
Timeline.GeochronoEtherPainter = function(params, band, timeline) {
    this._params = params;
    this._intervalUnit = params.intervalUnit;
    this._multiple = ("multiple" in params) ? params.multiple : 1;
    this._theme = params.theme;
};

Timeline.GeochronoEtherPainter.prototype.initialize = function(band, timeline) {
    this._band = band;
    this._timeline = timeline;
    
    this._backgroundLayer = band.createLayerDiv(0);
    this._backgroundLayer.setAttribute("name", "ether-background"); // for debugging
    this._backgroundLayer.style.background = this._theme.ether.backgroundColors[band.getIndex()];
    
    this._markerLayer = null;
    this._lineLayer = null;
    
    var align = ("align" in this._params && typeof this._params.align == "string") ? this._params.align : 
        this._theme.ether.interval.marker[timeline.isHorizontal() ? "hAlign" : "vAlign"];
    var showLine = ("showLine" in this._params) ? this._params.showLine : 
        this._theme.ether.interval.line.show;
        
    this._intervalMarkerLayout = new Timeline.GeochronoEtherMarkerLayout(
        this._timeline, this._band, this._theme, align, showLine);
        
    this._highlight = new Timeline.EtherHighlight(
        this._timeline, this._band, this._theme, this._backgroundLayer);
}

Timeline.GeochronoEtherPainter.prototype.setHighlight = function(startDate, endDate) {
    this._highlight.position(startDate, endDate);
}

Timeline.GeochronoEtherPainter.prototype.paint = function() {
    if (this._markerLayer) {
        this._band.removeLayerDiv(this._markerLayer);
    }
    this._markerLayer = this._band.createLayerDiv(100);
    this._markerLayer.setAttribute("name", "ether-markers"); // for debugging
    this._markerLayer.style.display = "none";
    
    if (this._lineLayer) {
        this._band.removeLayerDiv(this._lineLayer);
    }
    this._lineLayer = this._band.createLayerDiv(1);
    this._lineLayer.setAttribute("name", "ether-lines"); // for debugging
    this._lineLayer.style.display = "none";
    
    var minDate = Math.ceil(Timeline.GeochronoUnit.toNumber(this._band.getMinDate()));
    var maxDate = Math.floor(Timeline.GeochronoUnit.toNumber(this._band.getMaxDate()));
    
    var increment;
    var hasMore;
    (function(intervalUnit, multiple) {
        var dates;
        
        switch (intervalUnit) {
        case Timeline.GeochronoUnit.AGE:
            dates = Timeline.Geochrono.ages; break;
        case Timeline.GeochronoUnit.EPOCH:
            dates = Timeline.Geochrono.epoches; break;
        case Timeline.GeochronoUnit.PERIOD:
            dates = Timeline.Geochrono.periods; break;
        case Timeline.GeochronoUnit.ERA:
            dates = Timeline.Geochrono.eras; break;
        case Timeline.GeochronoUnit.EON:
            dates = Timeline.Geochrono.eons; break;
        default:
            hasMore = function() {
                return minDate > 0 && minDate > maxDate;
            }
            increment = function() {
                minDate -= multiple;
            };
            return;
        }
        
        var startIndex = dates.length - 1;
        while (startIndex > 0) {
            if (minDate <= dates[startIndex].start) {
                break;
            }
            startIndex--;
        }
        
        minDate = dates[startIndex].start;
        hasMore = function() {
            return startIndex < (dates.length - 1) && minDate > maxDate;
        };
        increment = function() {
            startIndex++;
            minDate = dates[startIndex].start;
        };
    })(this._intervalUnit, this._multiple);
    
    var labeller = this._band.getLabeller();
    while (true) {
        this._intervalMarkerLayout.createIntervalMarker(
            Timeline.GeochronoUnit.fromNumber(minDate), 
            labeller, 
            this._intervalUnit, 
            this._markerLayer, 
            this._lineLayer
        );
        if (hasMore()) {
            increment();
        } else {
            break;
        }
    }
    this._markerLayer.style.display = "block";
    this._lineLayer.style.display = "block";
};

Timeline.GeochronoEtherPainter.prototype.softPaint = function() {
};


/*==================================================
 *  Geochrono Ether Marker Layout
 *==================================================
 */
 
Timeline.GeochronoEtherMarkerLayout = function(timeline, band, theme, align, showLine) {
    var horizontal = timeline.isHorizontal();
    if (horizontal) {
        if (align == "Top") {
            this.positionDiv = function(div, offset) {
                div.style.left = offset + "px";
                div.style.top = "0px";
            };
        } else {
            this.positionDiv = function(div, offset) {
                div.style.left = offset + "px";
                div.style.bottom = "0px";
            };
        }
    } else {
        if (align == "Left") {
            this.positionDiv = function(div, offset) {
                div.style.top = offset + "px";
                div.style.left = "0px";
            };
        } else {
            this.positionDiv = function(div, offset) {
                div.style.top = offset + "px";
                div.style.right = "0px";
            };
        }
    }
    
    var markerTheme = theme.ether.interval.marker;
    var lineTheme = theme.ether.interval.line;
    
    var stylePrefix = (horizontal ? "h" : "v") + align;
    var labelStyler = markerTheme[stylePrefix + "Styler"];
    var emphasizedLabelStyler = markerTheme[stylePrefix + "EmphasizedStyler"];
    
    this.createIntervalMarker = function(date, labeller, unit, markerDiv, lineDiv) {
        var offset = Math.round(band.dateToPixelOffset(date));

        if (showLine) {
            var divLine = timeline.getDocument().createElement("div");
            divLine.style.position = "absolute";
            
            if (lineTheme.opacity < 100) {
                Timeline.Graphics.setOpacity(divLine, lineTheme.opacity);
            }
            
            if (horizontal) {
                divLine.style.borderLeft = "1px solid " + lineTheme.color;
                divLine.style.left = offset + "px";
                divLine.style.width = "1px";
                divLine.style.top = "0px";
                divLine.style.height = "100%";
            } else {
                divLine.style.borderTop = "1px solid " + lineTheme.color;
                divLine.style.top = offset + "px";
                divLine.style.height = "1px";
                divLine.style.left = "0px";
                divLine.style.width = "100%";
            }
            lineDiv.appendChild(divLine);
        }
        
        var label = labeller.labelInterval(date, unit);
        
        var div = timeline.getDocument().createElement("div");
        div.innerHTML = label.text;
        div.style.position = "absolute";
        (label.emphasized ? emphasizedLabelStyler : labelStyler)(div);
        
        this.positionDiv(div, offset);
        markerDiv.appendChild(div);
        
        return div;
    };
};