describe('miq_application.js', function() {
  describe('miqSerializeForm', function () {
    beforeEach(function () {
      var html = '<div id="form_div"><textarea name="method_data">new line added\r\n\r\n</textarea></div>'
      setFixtures(html);
    });

    it('verify serialize method doesnt convert line feed value to windows line feed', function() {
      expect(miqSerializeForm('form_div')).toEqual("method_data=new+line+added%0A%0A");
    });
  });

  describe('miqInitToolbars', function () {
    beforeEach(function () {
      var html  = '<div id="toolbar"><div class="btn-group"><button class="btn btn-default" id="first">Click me!</button></div><div class="btn-group"><button class="btn btn-default dropdown-toggle" id="second">Click me!</button><ul class="dropdown-menu"><li><a href="#" id="third">Click me!</a></li></ul></div></div>';
      setFixtures(html);
    });

    it('initializes the onclick event on a regular toolbar button', function () {
      spyOn(window, "miqToolbarOnClick");
      miqInitToolbars();
      $('#first').click();
      expect(miqToolbarOnClick).toHaveBeenCalled();
    });

    it('not initializes an onclick event on a dropdown toolbar button', function () {
      spyOn(window, "miqToolbarOnClick");
      miqInitToolbars();
      $('#second').click();
      expect(miqToolbarOnClick).not.toHaveBeenCalled();
    });

    it('initializes the onclick event on a dropdown toolbar link', function () {
      spyOn(window, "miqToolbarOnClick");
      miqInitToolbars();
      $('#third').click();
      expect(miqToolbarOnClick).toHaveBeenCalled();
    });
  });
});
