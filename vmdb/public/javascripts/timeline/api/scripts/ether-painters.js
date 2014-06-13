/*==================================================
 *  Gregorian Ether Painter
 *==================================================
 */
 
Timeline.GregorianEtherPainter = function(params) {
    this._params = params;
    this._theme = params.theme;
    this._unit = params.unit;
    this._multiple = ("multiple" in params) ? params.multiple : 1;
};

Timeline.GregorianEtherPainter.prototype.initialize = function(band, timeline) {
    this._band = band;
    this._timeline = timeline;
    
    this._backgroundLayer = band.createLayerDiv(0);
    this._backgroundLayer.setAttribute("name", "ether-background"); // for debugging
    this._backgroundLayer.style.background = this._theme.ether.backgroundColors[band.getIndex()];
    
    this._markerLayer = null;
    this._lineLayer = null;
    
    var align = ("align" in this._params && this._params.align != undefined) ? this._params.align : 
        this._theme.ether.interval.marker[timeline.isHorizontal() ? "hAlign" : "vAlign"];
    var showLine = ("showLine" in this._params) ? this._params.showLine : 
        this._theme.ether.interval.line.show;
        
    this._intervalMarkerLayout = new Timeline.EtherIntervalMarkerLayout(
        this._timeline, this._band, this._theme, align, showLine);
        
    this._highlight = new Timeline.EtherHighlight(
        this._timeline, this._band, this._theme, this._backgroundLayer);
}

Timeline.GregorianEtherPainter.prototype.setHighlight = function(startDate, endDate) {
    this._highlight.position(startDate, endDate);
}

Timeline.GregorianEtherPainter.prototype.paint = function() {
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
    
    var minDate = this._band.getMinDate();
    var maxDate = this._band.getMaxDate();
    
    var timeZone = this._band.getTimeZone();
    var labeller = this._band.getLabeller();
    
    Timeline.DateTime.roundDownToInterval(minDate, this._unit, timeZone, 1, this._theme.firstDayOfWeek);
    
    var p = this;
    var incrementDate = function(date) {
        for (var i = 0; i < p._multiple; i++) {
            Timeline.DateTime.incrementByInterval(date, p._unit);
        }
    };
    
    while (minDate.getTime() < maxDate.getTime()) {
        this._intervalMarkerLayout.createIntervalMarker(
            minDate, labeller, this._unit, this._markerLayer, this._lineLayer);
            
        incrementDate(minDate);
    }
    this._markerLayer.style.display = "block";
    this._lineLayer.style.display = "block";
};

Timeline.GregorianEtherPainter.prototype.softPaint = function() {
};

/*==================================================
 *  Hot Zone Gregorian Ether Painter
 *==================================================
 */
 
Timeline.HotZoneGregorianEtherPainter = function(params) {
    this._params = params;
    this._theme = params.theme;
    
    this._zones = [{
        startTime:  Number.NEGATIVE_INFINITY,
        endTime:    Number.POSITIVE_INFINITY,
        unit:       params.unit,
        multiple:   1
    }];
    for (var i = 0; i < params.zones.length; i++) {
        var zone = params.zones[i];
        var zoneStart = Timeline.DateTime.parseGregorianDateTime(zone.start).getTime();
        var zoneEnd = Timeline.DateTime.parseGregorianDateTime(zone.end).getTime();
        
        for (var j = 0; j < this._zones.length && zoneEnd > zoneStart; j++) {
            var zone2 = this._zones[j];
            
            if (zoneStart < zone2.endTime) {
                if (zoneStart > zone2.startTime) {
                    this._zones.splice(j, 0, {
                        startTime:   zone2.startTime,
                        endTime:     zoneStart,
                        unit:        zone2.unit,
                        multiple:    zone2.multiple
                    });
                    j++;
                    
                    zone2.startTime = zoneStart;
                }
                
                if (zoneEnd < zone2.endTime) {
                    this._zones.splice(j, 0, {
                        startTime:  zoneStart,
                        endTime:    zoneEnd,
                        unit:       zone.unit,
                        multiple:   (zone.multiple) ? zone.multiple : 1
                    });
                    j++;
                    
                    zone2.startTime = zoneEnd;
                    zoneStart = zoneEnd;
                } else {
                    zone2.multiple = zone.multiple;
                    zone2.unit = zone.unit;
                    zoneStart = zone2.endTime;
                }
            } // else, try the next existing zone
        }
    }
};

Timeline.HotZoneGregorianEtherPainter.prototype.initialize = function(band, timeline) {
    this._band = band;
    this._timeline = timeline;
    
    this._backgroundLayer = band.createLayerDiv(0);
    this._backgroundLayer.setAttribute("name", "ether-background"); // for debugging
    this._backgroundLayer.style.background = this._theme.ether.backgroundColors[band.getIndex()];
    
    this._markerLayer = null;
    this._lineLayer = null;
    
    var align = ("align" in this._params && this._params.align != undefined) ? this._params.align : 
        this._theme.ether.interval.marker[timeline.isHorizontal() ? "hAlign" : "vAlign"];
    var showLine = ("showLine" in this._params) ? this._params.showLine : 
        this._theme.ether.interval.line.show;
        
    this._intervalMarkerLayout = new Timeline.EtherIntervalMarkerLayout(
        this._timeline, this._band, this._theme, align, showLine);
        
    this._highlight = new Timeline.EtherHighlight(
        this._timeline, this._band, this._theme, this._backgroundLayer);
}

Timeline.HotZoneGregorianEtherPainter.prototype.setHighlight = function(startDate, endDate) {
    this._highlight.position(startDate, endDate);
}

Timeline.HotZoneGregorianEtherPainter.prototype.paint = function() {
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
    
    var minDate = this._band.getMinDate();
    var maxDate = this._band.getMaxDate();
    
    var timeZone = this._band.getTimeZone();
    var labeller = this._band.getLabeller();
    
    var p = this;
    var incrementDate = function(date, zone) {
        for (var i = 0; i < zone.multiple; i++) {
            Timeline.DateTime.incrementByInterval(date, zone.unit);
        }
    };
    
    var zStart = 0;
    while (zStart < this._zones.length) {
        if (minDate.getTime() < this._zones[zStart].endTime) {
            break;
        }
        zStart++;
    }
    var zEnd = this._zones.length - 1;
    while (zEnd >= 0) {
        if (maxDate.getTime() > this._zones[zEnd].startTime) {
            break;
        }
        zEnd--;
    }
    
    for (var z = zStart; z <= zEnd; z++) {
        var zone = this._zones[z];
        
        var minDate2 = new Date(Math.max(minDate.getTime(), zone.startTime));
        var maxDate2 = new Date(Math.min(maxDate.getTime(), zone.endTime));
        
        Timeline.DateTime.roundDownToInterval(minDate2, zone.unit, timeZone, zone.multiple, this._theme.firstDayOfWeek);
        Timeline.DateTime.roundUpToInterval(maxDate2, zone.unit, timeZone, zone.multiple, this._theme.firstDayOfWeek);
        
        while (minDate2.getTime() < maxDate2.getTime()) {
            this._intervalMarkerLayout.createIntervalMarker(
                minDate2, labeller, zone.unit, this._markerLayer, this._lineLayer);
                
            incrementDate(minDate2, zone);
        }
    }
    this._markerLayer.style.display = "block";
    this._lineLayer.style.display = "block";
};

Timeline.HotZoneGregorianEtherPainter.prototype.softPaint = function() {
};

/*==================================================
 *  Year Count Ether Painter
 *==================================================
 */
 
Timeline.YearCountEtherPainter = function(params) {
    this._params = params;
    this._theme = params.theme;
    this._startDate = Timeline.DateTime.parseGregorianDateTime(params.startDate);
    this._multiple = ("multiple" in params) ? params.multiple : 1;
};

Timeline.YearCountEtherPainter.prototype.initialize = function(band, timeline) {
    this._band = band;
    this._timeline = timeline;
    
    this._backgroundLayer = band.createLayerDiv(0);
    this._backgroundLayer.setAttribute("name", "ether-background"); // for debugging
    this._backgroundLayer.style.background = this._theme.ether.backgroundColors[band.getIndex()];
    
    this._markerLayer = null;
    this._lineLayer = null;
    
    var align = ("align" in this._params) ? this._params.align : 
        this._theme.ether.interval.marker[timeline.isHorizontal() ? "hAlign" : "vAlign"];
    var showLine = ("showLine" in this._params) ? this._params.showLine : 
        this._theme.ether.interval.line.show;
        
    this._intervalMarkerLayout = new Timeline.EtherIntervalMarkerLayout(
        this._timeline, this._band, this._theme, align, showLine);
        
    this._highlight = new Timeline.EtherHighlight(
        this._timeline, this._band, this._theme, this._backgroundLayer);
};

Timeline.YearCountEtherPainter.prototype.setHighlight = function(startDate, endDate) {
    this._highlight.position(startDate, endDate);
};

Timeline.YearCountEtherPainter.prototype.paint = function() {
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
    
    var minDate = new Date(this._startDate.getTime());
    var maxDate = this._band.getMaxDate();
    var yearDiff = this._band.getMinDate().getUTCFullYear() - this._startDate.getUTCFullYear();
    minDate.setUTCFullYear(this._band.getMinDate().getUTCFullYear() - yearDiff % this._multiple);
    
    var p = this;
    var incrementDate = function(date) {
        for (var i = 0; i < p._multiple; i++) {
            Timeline.DateTime.incrementByInterval(date, Timeline.DateTime.YEAR);
        }
    };
    var labeller = {
        labelInterval: function(date, intervalUnit) {
            var diff = date.getUTCFullYear() - p._startDate.getUTCFullYear();
            return {
                text: diff,
                emphasized: diff == 0
            };
        }
    };
    
    while (minDate.getTime() < maxDate.getTime()) {
        this._intervalMarkerLayout.createIntervalMarker(
            minDate, labeller, Timeline.DateTime.YEAR, this._markerLayer, this._lineLayer);
            
        incrementDate(minDate);
    }
    this._markerLayer.style.display = "block";
    this._lineLayer.style.display = "block";
};

Timeline.YearCountEtherPainter.prototype.softPaint = function() {
};

/*==================================================
 *  Quarterly Ether Painter
 *==================================================
 */
 
Timeline.QuarterlyEtherPainter = function(params) {
    this._params = params;
    this._theme = params.theme;
    this._startDate = Timeline.DateTime.parseGregorianDateTime(params.startDate);
};

Timeline.QuarterlyEtherPainter.prototype.initialize = function(band, timeline) {
    this._band = band;
    this._timeline = timeline;
    
    this._backgroundLayer = band.createLayerDiv(0);
    this._backgroundLayer.setAttribute("name", "ether-background"); // for debugging
    this._backgroundLayer.style.background = this._theme.ether.backgroundColors[band.getIndex()];
    
    this._markerLayer = null;
    this._lineLayer = null;
    
    var align = ("align" in this._params) ? this._params.align : 
        this._theme.ether.interval.marker[timeline.isHorizontal() ? "hAlign" : "vAlign"];
    var showLine = ("showLine" in this._params) ? this._params.showLine : 
        this._theme.ether.interval.line.show;
        
    this._intervalMarkerLayout = new Timeline.EtherIntervalMarkerLayout(
        this._timeline, this._band, this._theme, align, showLine);
        
    this._highlight = new Timeline.EtherHighlight(
        this._timeline, this._band, this._theme, this._backgroundLayer);
};

Timeline.QuarterlyEtherPainter.prototype.setHighlight = function(startDate, endDate) {
    this._highlight.position(startDate, endDate);
};

Timeline.QuarterlyEtherPainter.prototype.paint = function() {
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
    
    var minDate = new Date(0);
    var maxDate = this._band.getMaxDate();
    
    minDate.setUTCFullYear(Math.max(this._startDate.getUTCFullYear(), this._band.getMinDate().getUTCFullYear()));
    minDate.setUTCMonth(this._startDate.getUTCMonth());
    
    var p = this;
    var incrementDate = function(date) {
        date.setUTCMonth(date.getUTCMonth() + 3);
    };
    var labeller = {
        labelInterval: function(date, intervalUnit) {
            var quarters = (4 + (date.getUTCMonth() - p._startDate.getUTCMonth()) / 3) % 4;
            if (quarters != 0) {
                return { text: "Q" + (quarters + 1), emphasized: false };
            } else {
                return { text: "Y" + (date.getUTCFullYear() - p._startDate.getUTCFullYear() + 1), emphasized: true };
            }
        }
    };
    
    while (minDate.getTime() < maxDate.getTime()) {
        this._intervalMarkerLayout.createIntervalMarker(
            minDate, labeller, Timeline.DateTime.YEAR, this._markerLayer, this._lineLayer);
            
        incrementDate(minDate);
    }
    this._markerLayer.style.display = "block";
    this._lineLayer.style.display = "block";
};

Timeline.QuarterlyEtherPainter.prototype.softPaint = function() {
};

/*==================================================
 *  Ether Interval Marker Layout
 *==================================================
 */
 
Timeline.EtherIntervalMarkerLayout = function(timeline, band, theme, align, showLine) {
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
    var weekendTheme = theme.ether.interval.weekend;
    
    var stylePrefix = (horizontal ? "h" : "v") + align;
    var labelStyler = markerTheme[stylePrefix + "Styler"];
    var emphasizedLabelStyler = markerTheme[stylePrefix + "EmphasizedStyler"];
    var day = Timeline.DateTime.gregorianUnitLengths[Timeline.DateTime.DAY];
    
    this.createIntervalMarker = function(date, labeller, unit, markerDiv, lineDiv) {
        var offset = Math.round(band.dateToPixelOffset(date));

        if (showLine && unit != Timeline.DateTime.WEEK) {
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
        if (unit == Timeline.DateTime.WEEK) {
            var firstDayOfWeek = theme.firstDayOfWeek;
            
            var saturday = new Date(date.getTime() + (6 - firstDayOfWeek - 7) * day);
            var monday = new Date(saturday.getTime() + 2 * day);
            
            var saturdayPixel = Math.round(band.dateToPixelOffset(saturday));
            var mondayPixel = Math.round(band.dateToPixelOffset(monday));
            var length = Math.max(1, mondayPixel - saturdayPixel);
            
            var divWeekend = timeline.getDocument().createElement("div");
            divWeekend.style.position = "absolute";
            
            divWeekend.style.background = weekendTheme.color;
            if (weekendTheme.opacity < 100) {
                Timeline.Graphics.setOpacity(divWeekend, weekendTheme.opacity);
            }
            
            if (horizontal) {
                divWeekend.style.left = saturdayPixel + "px";
                divWeekend.style.width = length + "px";
                divWeekend.style.top = "0px";
                divWeekend.style.height = "100%";
            } else {
                divWeekend.style.top = saturdayPixel + "px";
                divWeekend.style.height = length + "px";
                divWeekend.style.left = "0px";
                divWeekend.style.width = "100%";
            }
            lineDiv.appendChild(divWeekend);
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

/*==================================================
 *  Ether Highlight Layout
 *==================================================
 */
 
Timeline.EtherHighlight = function(timeline, band, theme, backgroundLayer) {
    var horizontal = timeline.isHorizontal();
    
    this._highlightDiv = null;
    this._createHighlightDiv = function() {
        if (this._highlightDiv == null) {
            this._highlightDiv = timeline.getDocument().createElement("div");
            this._highlightDiv.setAttribute("name", "ether-highlight"); // for debugging
            this._highlightDiv.style.position = "absolute";
            this._highlightDiv.style.background = theme.ether.highlightColor;
            
            var opacity = theme.ether.highlightOpacity;
            if (opacity < 100) {
                Timeline.Graphics.setOpacity(this._highlightDiv, opacity);
            }
            
            backgroundLayer.appendChild(this._highlightDiv);
        }
    }
    
    this.position = function(startDate, endDate) {
        this._createHighlightDiv();
        
        var startPixel = Math.round(band.dateToPixelOffset(startDate));
        var endPixel = Math.round(band.dateToPixelOffset(endDate));
        var length = Math.max(endPixel - startPixel, 3);
        if (horizontal) {
            this._highlightDiv.style.left = startPixel + "px";
            this._highlightDiv.style.width = length + "px";
            this._highlightDiv.style.top = "2px";
            this._highlightDiv.style.height = (band.getViewWidth() - 4) + "px";
        } else {
            this._highlightDiv.style.top = startPixel + "px";
            this._highlightDiv.style.height = length + "px";
            this._highlightDiv.style.left = "2px";
            this._highlightDiv.style.width = (band.getViewWidth() - 4) + "px";
        }
    }
};

