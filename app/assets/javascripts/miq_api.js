/* functions to use the API from our JS/Angular:
 *
 * API.get(url, options) - use API.get('/api'), returns a Promise
 * API.delete - (the same)
 * API.post(url, data, options) - returns Promise
 * API.put - (the same)
 * API.patch - (the same)
 * API.login(login, password) - performs initial authentication, saves token on success, returns Promise
 * API.logout() - clears login info, no return
 * API.autorenew() - registers a 60second interval to query /api, returns a function to clear the interval
 *
 * can also be used from angular - depend on miq.api module and use the API service
 * when used as an angular service, all the promises are $q, so they work within the angular digest cycle
 *
 * the API token is persisted into sessionStorage
 */

(function() {
  function API() {
  }

  API.get = function(url, options) {
    return fetch(url, _.extend({
      method: 'GET',
    }, process_options(options)))
    .then(process_response);
  };

  API.post = function(url, data, options) {
    return fetch(url, _.extend({
      method: 'POST',
      body: process_data(data),
    }, process_options(options)))
    .then(process_response);
  };

  API.delete = function(url, options) {
    return fetch(url, _.extend({
      method: 'DELETE',
    }, process_options(options)))
    .then(process_response);
  };

  API.put = function(url, data, options) {
    return fetch(url, _.extend({
      method: 'PUT',
      body: process_data(data),
    }, process_options(options)))
    .then(process_response);
  };

  API.patch = function(url, data, options) {
    return fetch(url, _.extend({
      method: 'PATCH',
      body: process_data(data),
    }, process_options(options)))
    .then(process_response);
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
    delete o.body;

    if (o.skipTokenRenewal) {
      o.headers = o.headers || {};
      o.headers['X-Auth-Skip-Token-Renewal'] = 'true';
    }

    if (sessionStorage.miq_token) {
      o.headers = o.headers || {};
      o.headers['X-Auth-Token'] = sessionStorage.miq_token;
    }

    if (o.headers) {
      o.headers = new Headers(o.headers);
    }

    return o;
  }

  function process_data(o) {
    if (!o || _.isString(o))
      return o;

    if (_.isPlainObject(o))
      return JSON.stringify(o);

    // fetch supports more types but we aren't using any of those yet..
    console.warning('Unknown type for request data - please provide a plain object or a string', o);
    return null;
  }

  function process_response(response) {
    if (response.status === 204)  // No content
      return null;

    return response.json();
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
    delete: angularify(API.delete),
    put: angularify(API.put),
    patch: angularify(API.patch),
    login: angularify(API.login),
    logout: API.logout,
    autorenew: API.autorenew,
  };
}]);
