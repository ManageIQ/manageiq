/*jshint -W117 */
'use strict';

var router = require('express').Router();
var four0four = require('./utils/404')();

router.get('/*', four0four.notFoundMiddleware);

module.exports = router;


