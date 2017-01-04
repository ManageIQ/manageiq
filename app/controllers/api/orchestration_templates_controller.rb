module Api
  class OrchestrationTemplatesController < BaseController
    def delete_resource(type, id, data = {})
      klass    = collection_class(type)
      resource = resource_search(id, type, klass)
      super
      resource.raw_destroy if resource.kind_of?(OrchestrationTemplateVnfd)
    end

    def copy_resource(type, id, data = {})
      resource = resource_search(id, type, collection_class(type))
      resource.dup.tap do |new_resource|
        new_resource.assign_attributes(data)
        new_resource.save!
      end
    rescue => err
      raise BadRequestError, "Failed to copy orchestration template - #{err}"
    end
  end
end
