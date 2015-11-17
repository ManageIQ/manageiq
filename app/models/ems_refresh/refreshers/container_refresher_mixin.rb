module EmsRefresh
  module Refreshers
    module ContainerRefresherMixin
      def fetch_entities(client, entities)
        h = {}
        entities.each do |entity|
          begin
            h[entity.singularize] = client.send("get_" << entity)
          rescue KubeException => e
            # Hack to handle
            if entity == 'component_statuses' && e.error_code == 403
              $log.error("Ignoring Exception during component_statuses refresh: #{e}")
              h[entity.singularize] = {}
            else
              throw e
            end
          end
        end
        h
      end
    end
  end
end

