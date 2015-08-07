(function() {
  'use strict';

  angular.module('mock').run(mock);

  /** @ngInject */
  function mock($httpBackend) {
    $httpBackend.whenGET(/\/api\/v1\/staff\/sign_in/).respond(getAuth);
    $httpBackend.whenGET(/\/api\/v1\/staff\/current_member/).respond('');
    $httpBackend.whenPOST(/\/api\/v1\/staff\/sign_in/).respond('');
    $httpBackend.whenDELETE(/\/api\/v1\/staff\/sign_out/).respond(getAuthDelete);

    function getAuth(method, url, data) {
      return [200, {
        first_name: 'ManageIQ',
        last_name: 'User',
        full_name: 'ManageIQ User',
        id: 1,
        email: 'User@manageIQ.org',
        phone: null,
        role: 'user',
        created_at: '2015-07-28T13:08:12.742Z',
        updated_at: '2015-08-06T16:03:42.192Z',
        api_token: null
      }];
    }

    function getAuthDelete(method, url, data) {
      return [200, {}];
    }
  }
})();
