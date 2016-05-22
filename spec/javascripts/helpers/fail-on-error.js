// if you get a failing test in this file, most likely, *another* spec
// file has a syntax error, causing all the tests inside to be skipped

window.was_syntax_error = null;

window.onerror = function(err) {
  window.was_syntax_error = err;
  console.error(err);
};

window.addEventListener('error', function(err) {
  window.was_syntax_error = err;
  console.error(err);
}, true);

describe("Parse errors", function() {
  it("shouldn't happen", function() {
    var err = window.was_syntax_error;
    expect(err).toEqual(null);

    if (err) {
      // just in case the error happens only in `test:javascript` and not `environment jasmine`
      // and since we have no other way to output to console from there..
      expect("message").toEqual(err.message)
      expect("filename").toEqual(err.filename);
      expect("lineno").toEqual(err.lineno);
    }
  });
});
