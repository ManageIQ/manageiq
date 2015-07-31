'use strict';

var wiredep = require('wiredep');
var merge = require('merge');

module.exports = (function() {
  var src = './spa_ui/self_service/';
  var client = src + 'client/';
  var server = src + 'server/';
  var build = './public/self_service/';
  var temp = './.tmp/';
  var reports = './reports/';
  var bower = './bower_components/';
  var nodeModules = './node_modules/';

  var config = {};

  /**
   * Files
   */
  var indexFile = 'index.html';
  var specsFile = 'specs.html';
  var cssFile = 'styles.css';
  var sassFiles = [
    client + 'assets/sass/**/*.sass',
    client + 'app/**/*.sass'
  ];
  var templateFiles = client + 'app/**/*.html';
  var serverIntegrationSpecs = [client + 'tests/server-integration/**/*.spec.js'];
  var specHelperFiles = client + 'test-helpers/*.js';

  var clientJsOrder = [
    '**/app.module.js',
    '**/*.module.js',
    '**/*.js'
  ];

  var wiredepOptions = {
    json: require('../bower.json'),
    directory: bower,
    ignorePath: '../../..',
    // Ignore CSS and JavaScript this is not needed or is undesired
    exclude: [
      // Exclude the bootstrap CSS, the Sass version will be @imported instead
      /bootstrap\.css/,
      // Exclude the giant heap of never used jquery-ui code (see bower.json for overrides)
      /jquery-ui\.js/
    ]
  };

  var serverApp = server + 'app.js';

  function getClientJsFiles(ordered, excludeSpecs) {
    var files = [client + 'app/**/*.js'];

    if (ordered) {
      files = [].concat(client + 'app/app.module.js', client + 'app/**/*module*.js', files)
    }

    if (excludeSpecs) {
      files = [].concat(files, '!' + client + 'app/**/*.spec.js');
    }

    return files;
  }

  function getKarmaOptions() {
    var options = {
      files: [].concat(
        wiredep({devDependencies: true}).js,
        specHelperFiles,
        getClientJsFiles(true),
        config.templatecache.build + config.templatecache.output,
        config.test.serverIntegrationSpecs
      ),
      exclude: [],
      coverage: {
        dir: reports + 'coverage',
        reporters: [
          // reporters not supporting the `file` property
          {type: 'html', subdir: 'report-html'},
          {type: 'lcov', subdir: 'report-lcov'},
          {type: 'text-summary'}
        ]
      },
      preprocessors: {}
    };
    options.preprocessors[client + 'app/**/!(*.spec)+(.js)'] = ['coverage'];

    return options;
  }

  // gulp-load-plugins options
  config.plugins = {
    lazy: true
  };

  // task jshint: Runs JsHint on client code
  config.jshint = {
    src: getClientJsFiles(),
    rcFile: './gulp/.jshintrc',
    reporter: 'jshint-stylish',
    options: {
      verbose: true
    }
  };

  // task jscs: Runs JsCs on client code
  config.jscs = {
    src: getClientJsFiles(),
    rcfile: './gulp/.jscsrc'
  };

  // task plato: Analyze client code with Plato
  config.plato = {
    src: getClientJsFiles()[0],
    output: reports + 'plato',
    options: {
      title: 'Plato Inspections Report',
      exclude: /.*\.spec\.js/
    }
  };

  // task clean: Directories to clean
  config.clean = {
    src: [
      build + '*',
      // report + '*',
      temp + '*'
    ]
  };

  config.cleanStyles = {
    src: [
      temp + '**/*.css',
      build + 'styles/**/*.css'
    ]
  };

  config.cleanFonts = {
    src: [build + 'fonts/**/*.*']
  };

  config.cleanImages = {
    src: [build + 'images/**/*.*']
  };

  config.cleanCode = {
    src: [
      temp + '**/*.js',
      build + 'js/**/*.js',
      build + '**/*.html'
    ]
  };

  // task images: Image build options
  config.images = {
    src: [
      client + 'assets/images/**/*.*'
    ],
    build: build + 'images',
    minify: true,
    options: {
      optimizationLevel: 5,
      progressive: true,
      interlaced: true
    }
  };

  // task fonts: Copies fonts into build directory
  config.fonts = {
    src: [
      src + 'client/assets/fonts/**/*.*',
      bower + 'font-awesome/fonts/**/*.*',
      bower + 'bootstrap-sass-official/assets/fonts/**/*.*'
    ],
    build: build + 'fonts'
  };

  // task sass: Sass build options
  config.sass = {
    src: client + 'assets/sass/styles.sass',
    build: temp,
    output: cssFile,
    options: {
      // Only includes the styles if @imported
      // Remember to then update exclude in wiredepOptions if using @import
      loadPath: [
        bower + 'bootstrap-sass-official/assets/stylesheets/'
      ],
      style: 'compact',
      noCache: false,
      compass: false,
      bundleExec: true,
      sourcemap: false,
      precision: 5
    },
    autoprefixer: {
      browsers: [
        'last 2 versions',
        '> 5%'
      ],
      cascade: true
    }
  };

  // task templatecache: Optimize templates
  config.templatecache = {
    src: templateFiles,
    build: temp,
    output: 'templates.js',
    minify: true, // Always minify the templates
    minifyOptions: {
      empty: true
    },
    templateOptions: {
      module: 'app.core',
      standalone: false,
      root: 'app/'
    }
  };

  // task wiredep: Inject Bower CSS and JS into index.html
  // This task will also inject the application JavaScript
  // The inject task will inject the application CSS
  config.wiredep = {
    index: client + indexFile,
    build: client,
    options: wiredepOptions,
    files: getClientJsFiles(true, true),
    order: clientJsOrder
  };

  // task inject: Injects the application CSS (compiled from Sass) into index.html
  config.inject = {
    index: client + indexFile,
    build: client,
    css: temp + cssFile
  };

  config.optimize = {
    index: client + indexFile,
    build: build,
    cssFilter: '**/*.css',
    appJsFilter: '**/app.js',
    libJsFilter: '**/lib.js',
    templateCache: config.templatecache.build + config.templatecache.output,
    ngAnnotateOptions: {
      add: true,
      single_quotes: true
    }
  };

  config.build = {
    clean: temp
  };

  // task build-specs: Builds a specs index file
  config.buildSpecs = {
    index: client + specsFile,
    build: client,
    templateCache: config.templatecache.build + config.templatecache.output,
    options: merge({}, wiredepOptions, {devDependencies: true}),
    specs: [client + 'app/**/*.spec.js'],
    serverIntegrationSpecs: serverIntegrationSpecs,
    files: getClientJsFiles(true, true),
    order: clientJsOrder,
    testLibraries: [
      nodeModules + 'mocha/mocha.js',
      nodeModules + 'chai/chai.js',
      nodeModules + 'mocha-clean/index.js',
      nodeModules + 'sinon-chai/lib/sinon-chai.js'
    ],
    specHelpers: [specHelperFiles]
  };

  config.test = {
    confFile: __dirname + '/karma.conf.js',
    serverEnv: 'dev',
    serverPort: 8888,
    serverApp: serverApp,
    serverIntegrationSpecs: serverIntegrationSpecs
  };

  config.karma = getKarmaOptions();

  config.serve = {
    serverApp: serverApp,
    serverPort: process.env.PORT || '8001',
    watch: [server],
    browserReloadDelay: 1000,
    specsFile: specsFile,
    sass: sassFiles,
    js: getClientJsFiles(),
    html: [].concat(client + indexFile, templateFiles),
    devFiles: [
      client + '**/*.js',
      client + '**/*.html',
      temp + '**/*.css'
    ],
    browserSyncOptions: {
      proxy: 'localhost:' + (process.env.PORT || '8001'),
      port: 3001,
      startPath: '/self_service/',
      files: [],
      ghostMode: {
        clicks: true,
        location: false,
        forms: true,
        scroll: true
      },
      injectChanges: true,
      logFileChanges: true,
      logLevel: 'debug',
      logPrefix: 'angular-gulp-sass-inject',
      notify: true,
      reloadDelay: 0
    }
  };

  // task bump: Revs the package and bower files
  config.bump = {
    packages: [
      './package.json',
      './bower.json'
    ],
    root: './'
  };

  return config;
})();
