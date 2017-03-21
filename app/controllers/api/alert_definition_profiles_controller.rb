module Api
  class AlertDefinitionProfilesController < BaseController
    include Subcollections::AlertDefinitions

    REQUIRED_FIELDS = %w(description mode).freeze

    def create_resource(type, id, data = {})
      assert_all_required_fields_exists(data, type, REQUIRED_FIELDS)
      begin
        super(type, id, data)
      rescue => err
        raise BadRequestError, "Failed to create a new alert definition profile - #{err}"
      end
    end

    def edit_resource(type, id = nil, data = {})
      raise BadRequestError, "Must specify an id for editing a #{type} resource" unless id
      begin
        super(type, id, data)
      rescue => err
        raise BadRequestError, "Failed to update alert definition profile - #{err}"
      end
    end
  end
end
