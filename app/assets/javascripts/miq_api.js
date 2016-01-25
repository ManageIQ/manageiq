function API() {
  this.get = API.get;
  this.post = API.post;
}

API.get = function(url, options) {
  return $.ajax(url, _.extend({
    method: 'GET',
  }, options || {}));
}

API.post = function(url, data, options) {
  return $.ajax(url, _.extend({
    method: 'POST',
    data: data,
  }, options || {}));
}

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
  };
}]);
