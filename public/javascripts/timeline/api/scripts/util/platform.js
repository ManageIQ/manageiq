/*==================================================
 *  Platform Utility Functions and Constants
 *==================================================
 */

Timeline.Platform.os = {
    isMac:   false,
    isWin:   false,
    isWin32: false,
    isUnix:  false
};
Timeline.Platform.browser = {
    isIE:           false,
    isNetscape:     false,
    isMozilla:      false,
    isFirefox:      false,
    isOpera:        false,
    isSafari:       false,

    majorVersion:   0,
    minorVersion:   0
};

(function() {
    var an = navigator.appName.toLowerCase();
	var ua = navigator.userAgent.toLowerCase(); 
    
    /*
     *  Operating system
     */
	Timeline.Platform.os.isMac = (ua.indexOf('mac') != -1);
	Timeline.Platform.os.isWin = (ua.indexOf('win') != -1);
	Timeline.Platform.os.isWin32 = Timeline.Platform.isWin && (   
        ua.indexOf('95') != -1 || 
        ua.indexOf('98') != -1 || 
        ua.indexOf('nt') != -1 || 
        ua.indexOf('win32') != -1 || 
        ua.indexOf('32bit') != -1
    );
	Timeline.Platform.os.isUnix = (ua.indexOf('x11') != -1);
    
    /*
     *  Browser
     */
    Timeline.Platform.browser.isIE = (an.indexOf("microsoft") != -1);
    Timeline.Platform.browser.isNetscape = (an.indexOf("netscape") != -1);
    Timeline.Platform.browser.isMozilla = (ua.indexOf("mozilla") != -1);
    Timeline.Platform.browser.isFirefox = (ua.indexOf("firefox") != -1);
    Timeline.Platform.browser.isOpera = (an.indexOf("opera") != -1);
    //Timeline.Platform.browser.isSafari = (an.indexOf("safari") != -1);
    
    var parseVersionString = function(s) {
        var a = s.split(".");
        Timeline.Platform.browser.majorVersion = parseInt(a[0]);
        Timeline.Platform.browser.minorVersion = parseInt(a[1]);
    };
    var indexOf = function(s, sub, start) {
        var i = s.indexOf(sub, start);
        return i >= 0 ? i : s.length;
    };
    
    if (Timeline.Platform.browser.isMozilla) {
        var offset = ua.indexOf("mozilla/");
        if (offset >= 0) {
            parseVersionString(ua.substring(offset + 8, indexOf(ua, " ", offset)));
        }
    }
    if (Timeline.Platform.browser.isIE) {
        var offset = ua.indexOf("msie ");
        if (offset >= 0) {
            parseVersionString(ua.substring(offset + 5, indexOf(ua, ";", offset)));
        }
    }
    if (Timeline.Platform.browser.isNetscape) {
        var offset = ua.indexOf("rv:");
        if (offset >= 0) {
            parseVersionString(ua.substring(offset + 3, indexOf(ua, ")", offset)));
        }
    }
    if (Timeline.Platform.browser.isFirefox) {
        var offset = ua.indexOf("firefox/");
        if (offset >= 0) {
            parseVersionString(ua.substring(offset + 8, indexOf(ua, " ", offset)));
        }
    }
})();

Timeline.Platform.getDefaultLocale = function() {
    return Timeline.Platform.clientLocale;
};