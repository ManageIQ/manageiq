ManageIQ.angular.app.service('mwAddDatasourceService', MwAddDatasourceService);

MwAddDatasourceService.$inject = ['$http', '$q'];

function MwAddDatasourceService($http, $q) {

   var datasources = [
    {id: 'H2', label: 'H2', name: 'H2DS', jndiName: 'java:/H2DS',
      driverName: 'h2', driverModuleName: 'com.h2database.h2', driverClass: 'org.h2.Driver',
      connectionUrl: ':mem:test;DB_CLOSE_DELAY=-1'},
    {id : 'POSTGRES', label: 'Postgres', name: 'PostgresDS', jndiName: 'java:/PostgresDS',
      driverName: 'postresql', driverModuleName: 'org.postgresql', driverClass: 'org.postgresql.Driver',
      connectionUrl: '://localhost:5432/postgresdb'},
    {id: 'MSSQL', label: 'Microsoft SQL Server', name: 'MSSQLDS', jndiName: 'java:/MSSQLDS',
      driverName: 'sqlserver', driverModuleName: 'com.microsoft',
      driverClass: 'com.microsoft.sqlserver.jdbc.SQLServerDriver',
      connectionUrl: '://localhost:1433;DatabaseName=MyDatabase'},
    {id: 'ORACLE', label: 'Oracle', name: 'OracleDS', jndiName: 'java:/OracleDS',
      driverName: 'oracle', driverModuleName: 'com.oracle', driverClass: 'oracle.jdbc.driver.OracleDriver',
      connectionUrl: ':thin:@localhost:1521:orcalesid'},
    {id: 'DB2', label: 'IBM DB2', name: 'DB2DS', jndiName: 'java:/DB2DS',
      driverName: 'ibmdb2', driverModuleName: 'com.ibm', driverClass: 'COM.ibm.db2.jdbc.app.DB2Driver',
      connectionUrl: '://db2'},
    {id: 'SYBASE', label: 'Sybase', name: 'SybaseDS', jndiName: 'java:/SybaseDB',
      driverName: 'sybase', driverModuleName: 'com.sybase', driverClass: 'com.sybase.jdbc.SybDriver',
      connectionUrl: ':Tds:localhost:5000/mydatabase?JCONNECT_VERSION=6'},
    {id: 'MYSQL', label: 'MySql', name: 'MySqlDS', jndiName: 'java:/MySqlDS',
      driverName: 'mysql', driverModuleName: 'com.mysql', driverClass: 'com.mysql.jdbc.Driver',
      connectionUrl: '://localhost:3306/mysqldb'}
  ];

  this.getDatasources = function() {
    return Object.freeze(datasources);
  };

  this.determineConnectionUrl = function (dsSelection) {
    var PREFIX = 'jdbc:';
    var driverName = dsSelection.driverName;

    return PREFIX + driverName + dsSelection.connectionUrl;
  };

  this.sendAddDatasource = function(payload) {
    var errorMsg = _('Error running add_datasource on this server.');
    var deferred = $q.defer();

    $http.post('/middleware_server/add_datasource', angular.toJson(payload))
      .then(
        function (response) { // success
          var data = response.data;

          if (data.status === 'ok') {
            deferred.resolve(data.msg);
          } else {
            deferred.reject(data.msg);
          }
        })
      .catch(function () {
        deferred.reject(errorMsg);
      })
      .finally(function () {
        // we should already be resolved and promises can only fire once
        deferred.resolve(data.msg);
      });
    return deferred.promise;

  }
}

