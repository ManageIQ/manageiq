ManageIQ.angular.app.service('mwAddDatasourceService', MwAddDatasourceService);

MwAddDatasourceService.$inject = ['$http', '$q'];

function MwAddDatasourceService($http, $q) {
  var JDBC_PREFIX = 'jdbc:';
  var self = this;
  // NOTE: these are config objects that will basically never change
  var datasources = [
    {id: 'H2', label: 'H2', name: 'H2DS', jndiName: 'java:jboss/datasources/H2DS',
      driverName: 'h2', driverModuleName: 'com.h2database.h2', driverClass: 'org.h2.Driver',
      connectionUrl: ':mem:test;DB_CLOSE_DELAY=-1'},
    {id: 'POSTGRES', label: 'Postgres', name: 'PostgresDS', jndiName: 'java:jboss/datasources/PostgresDS',
      driverName: 'postresql', driverModuleName: 'org.postgresql', driverClass: 'org.postgresql.Driver',
      connectionUrl: '://localhost:5432/postgresdb', alias: 'POSTGRESQL'},
    {id: 'MSSQL', label: 'Microsoft SQL Server', name: 'MSSQLDS', jndiName: 'java:jboss/datasources/MSSQLDS',
      driverName: 'sqlserver', driverModuleName: 'com.microsoft',
      driverClass: 'com.microsoft.sqlserver.jdbc.SQLServerDriver',
      connectionUrl: '://localhost:1433;DatabaseName=MyDatabase'},
    {id: 'ORACLE', label: 'Oracle', name: 'OracleDS', jndiName: 'java:jboss/datasources/OracleDS',
      driverName: 'oracle', driverModuleName: 'com.oracle', driverClass: 'oracle.jdbc.driver.OracleDriver',
      connectionUrl: ':thin:@localhost:1521:oraclesid'},
    {id: 'DB2', label: 'IBM DB2', name: 'DB2DS', jndiName: 'java:jboss/datasources/DB2DS',
      driverName: 'ibmdb2', driverModuleName: 'com.ibm', driverClass: 'COM.ibm.db2.jdbc.app.DB2Driver',
      connectionUrl: '://db2'},
    {id: 'SYBASE', label: 'Sybase', name: 'SybaseDS', jndiName: 'java:jboss/datasources/SybaseDB',
      driverName: 'sybase', driverModuleName: 'com.sybase', driverClass: 'com.sybase.jdbc.SybDriver',
      connectionUrl: ':Tds:localhost:5000/mydatabase?JCONNECT_VERSION=6'},
    {id: 'MARIADB', label: 'MariaDB', name: 'MariaDBDS', jndiName: 'java:jboss/datasources/MariaDBDS',
       driverName: 'mariadb', driverModuleName: 'org.mariadb', driverClass: 'org.mariadb.jdbc.Driver',
       connectionUrl: '://localhost:3306/db_name'},
    {id: 'MYSQL', label: 'MySql', name: 'MySqlDS', jndiName: 'java:jboss/datasources/MySqlDS',
      driverName: 'mysql', driverModuleName: 'com.mysql', driverClass: 'com.mysql.jdbc.Driver',
      connectionUrl: '://localhost:3306/db_name'},
  ];
  var dsDriverNames = _.pluck(datasources, 'driverName');

  self.getExistingJdbcDrivers = function(serverId) {
    var deferred = $q.defer();
    var BASE_URL = '/middleware_server/jdbc_drivers';
    var parameterizedUrl = BASE_URL + '?server_id=' + serverId;

    $http.get(parameterizedUrl).then(function(driverData) {
      var transformedData = _.chain(driverData.data.data)
        .filter(function(driver) {
          return driver.properties['Driver Class'] !== null;
        })
        .map(function(driver) {
          return {'id': driver.properties['Driver Name'].toUpperCase(),
                  'label': driver.properties['Driver Name'],
                  'xaDsClass': driver.properties['XA DS Class'],
                  'driverClass': driver.properties['Driver Class']};
      })
      .value();

      deferred.resolve(transformedData);
    }).catch(function(errorMsg) {
      deferred.reject(errorMsg);
    });
    return deferred.promise;
  };

  self.getDatasources = function() {
    return Object.freeze(datasources);
  };

  self.isXaDriver = function(driver) {
    return driver.hasOwnProperty('xaDsClass') && driver.xaDsClass !== '';
  };

  self.determineConnectionUrl = function(dsSelection) {
    var driverName = dsSelection.driverName;
    return JDBC_PREFIX + driverName + dsSelection.connectionUrl;
  };

  self.isValidDatasourceName = function(dsName) {
    if (dsName) {
      return _.contains(dsDriverNames, dsName.toLowerCase());
    } else {
      return null;
    }
  };

  self.findDatasourceById = function(id) {
    return _.find(datasources, function(datasource) {
      // handle special case when JDBC Driver Name doesn't match naming of Datasource
      // For instance, 'POSTGRES' vs 'POSTGRESQL'
      // in this case an 'alias' in the datasource configuration is used
      if (datasource.hasOwnProperty('alias')) {
        return datasource.alias === id;
      } else {
        return datasource.driverName.toUpperCase() === id;
      }
    });
  };

  self.findDsSelectionFromDriver = function(driverSelection) {
    var dsSelection;
    var findDatasourceByDriverClass = function(driverClass) {
      return _.find(datasources, function(datasource) {
        return datasource.driverClass === driverClass;
      });
    };

    if (self.isValidDatasourceName(driverSelection.id)) {
      dsSelection = self.findDatasourceById(driverSelection.id);
    } else {
      dsSelection = findDatasourceByDriverClass(driverSelection.driverClass);
    }
    return dsSelection;
  };

  self.determineConnectionUrlFromExisting = function(driverSelection) {
    var dsSelection = self.findDsSelectionFromDriver(driverSelection);
    return JDBC_PREFIX + dsSelection.driverName + dsSelection.connectionUrl;
  };

  this.sendAddDatasource = function(payload) {
    return $http.post('/middleware_server/add_datasource', angular.toJson(payload));
  }
}


