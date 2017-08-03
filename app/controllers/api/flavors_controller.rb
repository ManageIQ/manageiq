module Api
  class FlavorsController < BaseController
    def create_resource(_type, _id, data)
      attrs = validate_flavor_attrs(data)
      task_id = Flavor.create_flavor_queue(User.current_user.id, EmsCloud.find_by_id(attrs['ems']['id']), attrs.deep_symbolize_keys)
      action_result(true, 'Creating Flavor', :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end

    def delete_resource(type, id, _data = {})
      flavor = resource_search(id, type, collection_class(:flavors))
      raise "Delete not supported for #{flavor_ident(flavor)}" unless flavor.respond_to?(:delete_flavor_queue)
      task_id = flavor.delete_in_provider_queue(User.current_user.id)
      action_result(true, "Deleting #{flavor_ident(flavor)}", :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end

    private

    def flavor_ident(flavor)
      "Flavor id:#{flavor.id} name: '#{flavor.name}'"
    end

    def validate_flavor_attrs(data)
      data.dup
    end
  end
end
