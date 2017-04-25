class AddStiToMiddlewares < ActiveRecord::Migration[5.0]
  class MiddlewareDatasource < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class MiddlewareDeployment < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class MiddlewareDomain < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class MiddlewareMessaging < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class MiddlewareServer < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class MiddlewareServerGroup < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  def up
    add_column :middleware_datasources, :type, :string
    add_index  :middleware_datasources, :type

    add_column :middleware_deployments, :type, :string
    add_index  :middleware_deployments, :type

    add_column :middleware_domains, :type, :string
    add_index  :middleware_domains, :type

    add_column :middleware_messagings, :type, :string
    add_index  :middleware_messagings, :type

    add_column :middleware_server_groups, :type, :string
    add_index  :middleware_server_groups, :type

    add_column :middleware_servers, :type, :string
    add_index  :middleware_servers, :type

    MiddlewareDatasource
      .update_all(:type => 'ManageIQ::Providers::Hawkular::MiddlewareManager::MiddlewareDatasource')

    MiddlewareDeployment
      .update_all(:type => 'ManageIQ::Providers::Hawkular::MiddlewareManager::MiddlewareDeployment')

    MiddlewareDomain
      .update_all(:type => 'ManageIQ::Providers::Hawkular::MiddlewareManager::MiddlewareDomain')

    MiddlewareMessaging
      .update_all(:type => 'ManageIQ::Providers::Hawkular::MiddlewareManager::MiddlewareMessaging')

    MiddlewareServerGroup
      .update_all(:type => 'ManageIQ::Providers::Hawkular::MiddlewareManager::MiddlewareServerGroup')

    MiddlewareServer
      .update_all(:type => 'ManageIQ::Providers::Hawkular::MiddlewareManager::MiddlewareServer')
  end

  def down
    remove_index :middleware_datasources, :column => [:type]
    remove_column :middleware_datasources, :type

    remove_index :middleware_deployments, :column => [:type]
    remove_column :middleware_deployments, :type

    remove_index :middleware_domains, :column => [:type]
    remove_column :middleware_domains, :type

    remove_index :middleware_messagings, :column => [:type]
    remove_column :middleware_messagings, :type

    remove_index :middleware_server_groups, :column => [:type]
    remove_column :middleware_server_groups, :type

    remove_index :middleware_servers, :column => [:type]
    remove_column :middleware_servers, :type
  end
end
