var mode;
mode = global.process.env.MIQ_ESLINT;

if (mode === undefined) {
  console.warn('Please use the environmental variable MIQ_ESLINT to enable specific rulesets..');
  console.warn('MIQ_ESLINT=vanilla\tfor non-angular, non-es6, non-spec code');
  console.warn('MIQ_ESLINT=angular\tfor angular code');
  console.warn('MIQ_ESLINT=spec\tfor specs');
  console.warn('MIQ_ESLINT=es6\tfor .es6 files');
}

if (!mode) {
  mode = "vanilla";
}

var plugins = [];
var xtends = [];
var ecmaVersion = 5;

var rules = {
  'indent': [ 'error', 2, {
    SwitchCase: 1,
    VariableDeclarator: 1,
  }],
  'consistent-return': 1,
  'default-case': 1,
  'vars-on-top': 0,
  'no-var': 0,
  'linebreak-style': [ 'error', 'unix' ],
  'quotes': [ 'error', 'single' ],
  'semi-spacing': ['error', {
    before: false,
    after: true,
  }],
  'semi': [ 'error', 'always' ],
  'comma-dangle': [ 'warn', 'always-multiline' ],
  'space-unary-ops': [ 'error', {
    words: true,
    nonwords: false,
    overrides: {
      '!': true,
    },
  }],
  'no-unused-vars': [ 'error', {
    args: 'all',
    argsIgnorePattern: '^_',
    vars: 'local',
    caughtErrors: 'all',
    caughtErrorsIgnorePattern: '^_',
  }],
  'no-console': 1,
  'no-alert': 2,
  'no-debugger': 2,
  'no-else-return': 1,
  'no-undef': [ 'warn', {
    typeof: true,
  }],
  'eqeqeq': [ 'error', 'smart' ],
  'quotes': [ 'warn', 'single', {
    avoidEscape: true,
    allowTemplateLiterals: true,
  }],
  'func-names': 0,
  'no-mixed-spaces-and-tabs': 2,
  'camelcase': 1,
  'curly': [ 'warn', 'all' ],
  'space-before-function-paren': [ 'error', 'never' ],
  'no-eq-null': 0,
  'no-param-reassign': 1,
  'no-fallthrough': [ 'error', {
    commentPattern: "fall.*through|pass",
  }],
  'no-use-before-define': [ 'error', {
    functions: false,
    classes: true,
  }],
  'padded-blocks': [ 'error', 'never' ],
};

switch (mode) {
  case 'vanilla':
    xtends.push('airbnb-es5');
    break;

  case 'angular':
    plugins.push('angular');
    xtends.push('airbnb-es5');
    xtends.push('angular');

    rules = Object.assign(rules, {
      // eslint-plugin-angular
      'angular/module-setter': 0,
      'angular/foreach': 0,
      'angular/watchers-execution': [ 'warn', '$apply' ], // but allow $digest for specs
      'angular/json-functions': 0,
      'angular/definedundefined': 0,
      'angular/log': 0,
      'angular/no-service-method': 0,
      'angular/di': [ 'error', 'array' ], // strictDi

      // only warnings for now
      'angular/controller-as': 1,
      'angular/module-getter': 1,
      'angular/no-services': [ "warn", ['$http'] ],

      // prefer lodash for typechecks
      'angular/typecheck-array': 0,
      'angular/typecheck-date': 0,
      'angular/typecheck-function': 0,
      'angular/typecheck-number': 0,
      'angular/typecheck-object': 0,
      'angular/typecheck-string': 0,
    });

    break;

  case 'spec':
    xtends.push('airbnb-es5');
    break;

  case 'es6':
    // note that eslint has to be run with --ext .es6 to pick these up
    xtends.push('airbnb');
    ecmaVersion = 6;
    break;

  default:
    console.error('Unknown mode: ' + mode + " - sorry");
    global.process.exit(1);
}


module.exports = {
  installedESLint: true,
  env: {
    browser: true,
    jquery: true,
  },
  parserOptions: {
    ecmaVersion: ecmaVersion,
    sourceType: 'script',
    ecmaFeatures: {
      globalReturn: false,
      impliedStrict: false,
      jsx: false,
    },
  },

  plugins: plugins,
  extends: xtends,

  globals: {
    API: false, // local: miq_api.js
    ManageIQ: false,  // local: mig_global.js
    Promise: false, // bower: es6-shim
    _: false, // bower: lodash
    __: false,  // local: i18n.js
    angular: false, // bower: angular
    c3: false,  // bower: c3
    d3: false,  // bower: d3
    i18n: false,  // gem: gettext_i18n_rails_js
    moment: false,  // bower: moment
    numeral: false, // bower: numeral
    sprintf: false, // bower: sprintf
  },

  rules: rules,
};
