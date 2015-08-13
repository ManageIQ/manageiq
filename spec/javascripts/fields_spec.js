describe('Pass fields  to server', function() {
  it('returns url fields in name/value pairs', function() {
    var url = '/path/to/infinity';
    var args = {'foo': 'bar', 'lorem': 'ipsum'};
    expect(miqPassFields(url, args)).toEqual('/path/to/infinity?foo=bar&lorem=ipsum');
  });
});
