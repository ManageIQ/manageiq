module Api
  module Subcollections
    module Snapshots
      def snapshots_query_resource(object)
        object.snapshots
      end

      def snapshots_create_resource(parent, _type, _id, data)
        raise "Must specify a name for the snapshot" unless data["name"].present?

        validation = parent.validate_create_snapshot
        raise validation[:message] unless validation[:available]

        message = "Creating snapshot #{data["name"]} for #{snapshot_ident(parent)}"
        task_id = queue_object_action(
          parent,
          message,
          :method_name => "create_snapshot",
          :args        => [data["name"], data["description"], data.fetch("memory", false)]
        )

        action_result(true, message, :task_id => task_id)
      rescue => e
        action_result(false, e.to_s)
      end

      def delete_resource_snapshots(parent, type, id, _data)
        validation = parent.validate_remove_snapshot(id)
        raise validation[:message] unless validation[:available]
        snapshot = resource_search(id, type, collection_class(type))

        message = "Deleting snapshot #{snapshot.name} for #{snapshot_ident(parent)}"
        task_id = queue_object_action(parent, message, :method_name => "remove_snapshot", :args => [id])
        action_result(true, message, :task_id => task_id)
      rescue => e
        action_result(false, e.to_s)
      end
      alias snapshots_delete_resource delete_resource_snapshots

      private

      def snapshot_ident(parent)
        parent_ident = collection_config[@req.collection].description.singularize
        "#{parent_ident} id:#{parent.id} name:'#{parent.name}'"
      end
    end
  end
end
