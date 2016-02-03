// overriden from gettext.config once the initialization is done
window.__ = function(str) {
  throw new Error([
    'Attempting to call gettext before the service was initialized.',
    'Maybe you\'re calling it in the .config phase? ("' + str + '")',
  ].join(' '));
};

// N_ is OK anywhere
window.N_ = function(str) {
  return str;
};
