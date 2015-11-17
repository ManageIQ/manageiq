module EmsRefresh
  module Refreshers
    module ContainerRefresherMixin
      def fetch_entities(client, entities)
        h = {}
        entities.each do |entity|
          h[entity.singularize] = client.send("get_" << entity)
        end
        h
      end
    end
  end
end

