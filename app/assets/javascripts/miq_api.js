/* functions to use the API from our JS/Angular:
 *
 * API.get(url, options) - use API.get('/api'), returns promise
 * API.delete - (the same)
 * API.post(url, data, options) - returns promise
 * API.put - (the same)
 * API.patch - (the same)
 * API.login(login, password) - performs initial authentication, saves token on success, returns promise
 * API.logout() - clears login info, no return
 * API.autorenew() - registers a 60second interval to query /api, returns a function to clear the interval
 *
 * can also be used from angular - depend on miq.api module and use the API service
 * when used as an angular service, all the promises are $q, so work within the angular digest cycle
 *
 * the API token is persisted into sessionStorage
 */

(function() {
  function API() {
  }

  API.get = function(url, options) {
    return $.ajax(url, _.extend({
      method: 'GET',
    }, process_options(options)));
  };

  API.post = function(url, data, options) {
    return $.ajax(url, _.extend({
      method: 'POST',
      data: data,
    }, process_options(options)));
  };

  API.delete = function(url, options) {
    return $.ajax(url, _.extend({
      method: 'DELETE',
    }, process_options(options)));
  };

  API.put = function(url, data, options) {
    return $.ajax(url, _.extend({
      method: 'PUT',
      data: data,
    }, process_options(options)));
  };

  API.patch = function(url, data, options) {
    return $.ajax(url, _.extend({
      method: 'PATCH',
      data: data,
    }, process_options(options)));
  };

  var base64encode = window.btoa; // browser api

  API.login = function(login, password) {
    API.logout();

    return API.get('/api/auth?requester_type=ui', {
      headers: {
        'Authorization': 'Basic ' + base64encode([login, password].join(':')),
      },
    })
    .then(function(response) {
      sessionStorage.miq_token = response.auth_token;
    });
  };

  API.logout = function() {
    if (sessionStorage.miq_token) {
      API.delete('/api/auth');
    }

    delete sessionStorage.miq_token;
  };

  API.autorenew = function() {
    var id = setInterval(function() {
      API.get('/api')
      .then(null, function() {
        console.warn('API autorenew fail', arguments);
        clearInterval(id);
      });
    }, 60 * 1000);

    return function() {
      clearInterval(id);
    };
  };

  window.API = API;


  function process_options(o) {
    o = o || {};
    delete o.type;
    delete o.method;
    delete o.url;
    delete o.data;

    if (o.skipTokenRenewal) {
      o.headers = o.headers || {};
      o.headers['X-Auth-Skip-Token-Renewal'] = 'true';
    }

    if (sessionStorage.miq_token) {
      o.headers = o.headers || {};
      o.headers['X-Auth-Token'] = sessionStorage.miq_token;
    }

    return o;
  }
})(window);


angular.module('miq.api', [])
.factory('API', ['$q', function($q) {
  var angularify = function(what) {
    return function() {
      return $q.when(what.apply(API, arguments));
    };
  };

  return {
    get: angularify(API.get),
    post: angularify(API.post),
    login: angularify(API.login),
    logout: API.logout,
    autorenew: API.autorenew,
  };
}]);
