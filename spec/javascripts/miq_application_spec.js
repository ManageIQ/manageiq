describe('miq_application.js', function() {
  beforeEach(function () {
    var html = '<div id="form_div"><textarea name="method_data">new line added\r\n\r\n</textarea></div>'
    setFixtures(html);
  });
  it('verify serialize method doesnt convert line feed value to windows line feed', function() {
    expect(miqSerializeForm('form_div')).toEqual("method_data=new+line+added%0A%0A");
  });
});
