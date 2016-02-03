// overriden from gettext.config once the initialization is done
window.__ = function(str) {
  throw new Error('Attempting to call gettext before the service was initialized. Maybe you\'re doing it in the .config phase? ("' + str + '")');
};

// N_ is OK anywhere
window.N_ = function(str) {
  return str;
};
