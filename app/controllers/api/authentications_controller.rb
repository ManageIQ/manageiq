module Api
  class AuthenticationsController < BaseController
    def options
      render_options(:authentications, :fields => build_field_values)
    end

    private

    def build_field_values
      values = {}
      ::Authentication.descendants.each do |subclass|
        field_values = subclass.try(:fields)
        values[subclass.to_s] = field_values if field_values
      end
      values
    end
  end
end
