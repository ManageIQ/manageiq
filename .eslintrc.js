module.exports = {
  installedESLint: true,
  env: {
    browser: true,
    jquery: true,
  },
  parserOptions: {
    ecmaVersion: 5,
    sourceType: 'script',
    ecmaFeatures: {
      globalReturn: false,
      impliedStrict: false,
      jsx: false,
    },
  },

  extends: 'airbnb-es5',

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

  rules: {
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
  },
};
