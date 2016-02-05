/* jshint -W117, -W030 */
describe('Session', function() {
  var reloadOk;

  beforeEach(function() {
    module('app.core', 'gettext');

    reloadOk = false;

    module(function($provide) {
      $provide.value('$window', {
        get location() {
          return {
            href: window.location.href,
            reload: function() {
              reloadOk = true;
            },
          };
        },
        set location(str) {
          return;
        },
      });
    });

    bard.inject('Session', '$window', '$sessionStorage');
  });

  describe('switchGroup', function() {
    it('should persist and reload', function() {
      $sessionStorage.miqGroup = 'bad';

      Session.switchGroup('good');

      expect($sessionStorage.miqGroup).to.eq('good');
      expect(reloadOk).to.eq(true);
    });
  });
});
