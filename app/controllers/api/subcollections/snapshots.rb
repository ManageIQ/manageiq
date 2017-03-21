module Api
  module Subcollections
    module Snapshots
      def snapshots_query_resource(object)
        object.snapshots
      end

      def snapshots_create_resource(parent, _type, _id, data)
        raise "Must specify a name for the snapshot" unless data["name"].present?
        raise parent.unsupported_reason(:snapshot_create) unless parent.supports_snapshot_create?

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
        raise parent.unsupported_reason(:remove_snapshot) unless parent.supports_remove_snapshot?
        snapshot = resource_search(id, type, collection_class(type))

        message = "Deleting snapshot #{snapshot.name} for #{snapshot_ident(parent)}"
        task_id = queue_object_action(parent, message, :method_name => "remove_snapshot", :args => [id])
        action_result(true, message, :task_id => task_id)
      rescue => e
        action_result(false, e.to_s)
      end
      alias snapshots_delete_resource delete_resource_snapshots

      def snapshots_revert_resource(parent, type, id, _data)
        raise parent.unsupported_reason(:revert_to_snapshot) unless parent.supports_revert_to_snapshot?
        snapshot = resource_search(id, type, collection_class(type))

        message = "Reverting to snapshot #{snapshot.name} for #{snapshot_ident(parent)}"
        task_id = queue_object_action(parent, message, :method_name => "revert_to_snapshot", :args => [id])
        action_result(true, message, :task_id => task_id)
      rescue => e
        action_result(false, e.to_s)
      end

      private

      def snapshot_ident(parent)
        parent_ident = collection_config[@req.collection].description.singularize
        "#{parent_ident} id:#{parent.id} name:'#{parent.name}'"
      end
    end
  end
end
