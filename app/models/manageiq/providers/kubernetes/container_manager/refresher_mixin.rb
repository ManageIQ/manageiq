module ManageIQ
  module Providers
    module Kubernetes
      module ContainerManager::RefresherMixin
        KUBERNETES_ENTITIES = [
          {:name => 'pods'}, {:name => 'services'}, {:name => 'replication_controllers'}, {:name => 'nodes'},
          {:name => 'endpoints'}, {:name => 'namespaces'}, {:name => 'resource_quotas'}, {:name => 'limit_ranges'},
          {:name => 'persistent_volumes'}, {:name => 'persistent_volume_claims'},
          # workaround for: https://github.com/openshift/origin/issues/5865
          {:name => 'component_statuses', :default => []}
        ]

        def fetch_entities(client, entities)
          entities.each_with_object({}) do |entity, h|
            begin
              h[entity[:name].singularize] = client.send("get_#{entity[:name]}")
            rescue KubeException => e
              raise e if entity[:default].nil?
              $log.warn("Unexpected Exception during refresh: #{e}")
              h[entity[:name].singularize] = entity[:default]
            end
          end
        end
      end
    end
  end
end
