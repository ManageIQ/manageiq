/*jshint node:true*/
'use strict';

var express = require('express');
var proxy = require('express-http-proxy');
var app = express();
var bodyParser = require('body-parser');
var favicon = require('serve-favicon');
var logger = require('morgan');
var port = process.env.PORT || 8001;
var four0four = require('./utils/404')();
var url = require('url');

var environment = process.env.NODE_ENV;

app.use('/api/v1', proxy('127.0.0.1:3000', {
  forwardPath: function(req, res) {
    var path = '/api/v1' + url.parse(req.url).path;

    console.log('PROXY: http://127.0.0.1:3000' + path);
    return path;
  }
}));

app.use(favicon(__dirname + '/favicon.ico'));
app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());
app.use(logger('dev'));

app.use('/api', require('./routes'));

console.log('About to crank up node');
console.log('PORT=' + port);
console.log('NODE_ENV=' + environment);

switch (environment) {
  case 'build':
    console.log('** BUILD **');
    app.use(express.static('./build/'));
    // Any invalid calls for templateUrls are under app/* and should return 404
    app.use('/app/*', function(req, res) {
      four0four.send404(req, res);
    });
    // Any deep link calls should return index.html
    app.use('/*', express.static('./public/index.html'));
    break;
  default:
    console.log('** DEV **');
    app.use(express.static('./client/'));
    app.use(express.static('./client/assets'));
    app.use(express.static('./'));
    app.use(express.static('./tmp'));
    // Any invalid calls for templateUrls are under app/* and should return 404
    app.use('/app/*', function(req, res) {
      four0four.send404(req, res);
    });
    // Any deep link calls should return index.html
    app.use('/*', express.static('./client/index.html'));
    break;
}

app.listen(port, function() {
  console.log('Express server listening on port ' + port);
  console.log('env = ' + app.get('env') + '\n__dirname = '
    + __dirname + '\nprocess.cwd = ' + process.cwd());
});
