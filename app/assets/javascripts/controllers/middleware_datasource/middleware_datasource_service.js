ManageIQ.angular.app.service('mwAddDatasourceService', MwAddDatasourceService);
'use strict';

MwAddDatasourceService.$inject = ['$http', '$q'];

function MwAddDatasourceService($http, $q) {
  var JDBC_PREFIX = 'jdbc:';
  // NOTE: these are config objects that will basically never change
  var datasources = [
    {id: 'H2', label: 'H2', name: 'H2DS', jndiName: 'java:jboss/datasources/H2DS',
      driverName: 'h2', driverModuleName: 'com.h2database.h2', driverClass: 'org.h2.Driver',
      connectionUrl: ':mem:test;DB_CLOSE_DELAY=-1'},
    {id: 'POSTGRES', label: 'Postgres', name: 'PostgresDS', jndiName: 'java:jboss/datasources/PostgresDS',
      driverName: 'postresql', driverModuleName: 'org.postgresql', driverClass: 'org.postgresql.Driver',
      connectionUrl: '://localhost:5432/postgresdb'},
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

  this.getExistingJdbcDrivers = function(serverId) {
    var deferred = $q.defer();
    var BASE_URL = '/middleware_server/jdbc_drivers';
    var parameterizedUrl = BASE_URL + '?server_id=' + serverId;

    $http.get(parameterizedUrl).then(function(driverData) {
      var transformedData = _.map(driverData.data.data, function(driver) {
        return {'id': driver.properties['Driver Name'].toUpperCase(),
                'label': driver.properties['Driver Name']};
      });
      deferred.resolve(transformedData);
    }).catch(function(errorMsg) {
      deferred.reject(errorMsg);
    });
    return deferred.promise;
  };

  this.getDatasources = function() {
    return Object.freeze(datasources);
  };

  this.determineConnectionUrl = function(dsSelection) {
    var driverName = dsSelection.driverName;
    return JDBC_PREFIX + driverName + dsSelection.connectionUrl;
  };

  this.determineConnectionUrlFromExisting = function(id) {
    console.warn('id: ' + id);
    console.dir(datasources);
    var dsSelection = _.find(datasources, function(datasource) {
      return datasource.driverName.toUpperCase() === id;
    });
    console.dir(dsSelection);

    return JDBC_PREFIX + dsSelection.driverName + dsSelection.connectionUrl;
  };

  this.sendAddDatasource = function(payload) {
    return $http.post('/middleware_server/add_datasource', angular.toJson(payload));
  }
}


