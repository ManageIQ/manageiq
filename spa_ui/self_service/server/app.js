/*jshint node:true*/
'use strict';

var express = require('express');
var proxy = require('express-http-proxy');
var app = express();
var router = express.Router();
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

router.use(favicon(__dirname + '/favicon.ico'));
router.use(bodyParser.urlencoded({extended: true}));
router.use(bodyParser.json());
router.use(logger('dev'));

app.use('/self_service/', router);

console.log('About to crank up node');
console.log('PORT=' + port);
console.log('NODE_ENV=' + environment);

switch (environment) {
  case 'build':
    console.log('** BUILD **');
    app.use(express.static('./public/self_service/'));
    app.use(express.static('./public/'));
    // Any invalid calls for templateUrls are under app/* and should return 404
    app.use('/app/*', function(req, res) {
      four0four.send404(req, res);
    });
    // Any deep link calls should return index.html
    router.use('/*', express.static('./public/self_service/index.html'));
    break;
  default:
    console.log('** DEV **');
    router.use(express.static('./spa_ui/self_service/client/'));
    app.use(express.static('./spa_ui/self_service/client/assets'));
    app.use(express.static('./'));
    // Any invalid calls for templateUrls are under app/* and should return 404
    router.use('/app/*', function(req, res) {
      four0four.send404(req, res);
    });
    // Any deep link calls should return index.html
    app.use('/*', express.static('./spa_ui/self_service/client/index.html'));
    break;
}

app.listen(port, function() {
  console.log('Express server listening on port ' + port);
  console.log('env = ' + app.get('env') + '\n__dirname = ' + __dirname + '\nprocess.cwd = ' + process.cwd());
});
