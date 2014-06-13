//patch for increasing length of attachHeader and attachFooter, in dhtmlx code it is set as default to 4k
//This patch allows to display delete buttons in footer on compare grid if there are more than 9 items
	dhtmlXGridObject.prototype._launchCommands=function(arr){
		for (var i = 0; i < arr.length; i++){
			var args = new Array();
	
			for (var j = 0; j < arr[i].childNodes.length; j++)
				if (arr[i].childNodes[j].nodeType == 1){
					var param=arr[i].childNodes[j];
					var text="";
					for (var k=0; k < param.childNodes.length; k++)
						text+=param.childNodes[k].data;
					args[args.length]=text;
				}
	
			this[arr[i].getAttribute("command")].apply(this, args);
		}
	}