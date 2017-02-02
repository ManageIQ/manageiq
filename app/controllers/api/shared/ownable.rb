module Api
  module Shared
    module Ownable
      def set_ownership_resource(type, id, data = nil)
        raise BadRequestError, "Must specify an id for setting ownership of a #{type} resource" unless id
        raise BadRequestError, "Must specify an owner or group for setting ownership data = #{data}" if data.blank?

        api_action(type, id) do |klass|
          resource_search(id, type, klass)
          api_log_info("Setting ownership to #{type} #{id}")
          ownership = parse_ownership(data)
          set_ownership_action(klass, type, id, ownership)
        end
      end

      def set_ownership_action(klass, type, id, ownership)
        if ownership.blank?
          action_result(false, "Must specify a valid owner or group for setting ownership")
        else
          result = klass.set_ownership([id], ownership)
          details = ownership.each.collect { |key, obj| "#{key}: #{obj.name}" }.join(", ")
          desc = "setting ownership of #{type} id #{id} to #{details}"
          result == true ? action_result(true, desc) : action_result(false, result.values.join(", "))
        end
      rescue => err
        action_result(false, err.to_s)
      end

      def parse_ownership(data)
        return unless data.present?
        {
          :owner => collection_class(:users).find_by(:id => parse_owner(data["owner"])),
          :group => collection_class(:groups).find_by(:id => parse_group(data["group"]))
        }.compact
      end

      def parse_owner(resource)
        return nil if resource.blank?
        parse_id(resource, :users) || parse_by_attr(resource, :users)
      end
    end
  end
end
