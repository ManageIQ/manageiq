// MIQ - Changes to work in our environment
// Original source: https://github.com/splendeo/jquery.observe_field

// jquery.observe_field.js

(function( $j ){

  jQuery.fn.observe_field = function(frequency, callback) {
		var el = $j(this[0])
		if (typeof el.data("events") == "undefined" || typeof el.data("events").click == "undefined"){

			frequency = frequency * 1000; // translate to milliseconds

			return this.each(function(){
				var $this = $j(this);
				var prev = $this.val();
				var ti;

				var check = function() {
					if(ti) clearInterval(ti);
					var val = $this.val();
					if(prev != val){
						prev = val;
						$this.map(callback); // invokes the callback on $this
					}
				};

				var reset = function() {
					if(ti) clearInterval(ti);
					ti = setInterval(check, frequency);
				};

//				Commented the following so we don't have a timer constantly
//				check();
//				var ti = setInterval(check, frequency); // invoke check periodically

				// reset counter after user interaction
	      $this.bind('keyup click mousemove', reset); //mousemove is for selects
	    });
		}

  };

})( jQuery );

