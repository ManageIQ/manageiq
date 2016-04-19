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
    expect(window.was_syntax_error).toEqual(null);
  });
});
