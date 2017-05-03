module Api
  class Environment
    def self.url_attributes
      @url_attributes ||= Set.new(%w(href))
    end

    def self.resource_attributes
      @resource_attributes ||= Set.new(%w(image_href))
    end

    def self.encrypted_attributes
      @encrypted_attributes ||= Set.new(%w(password)) |
                                ::MiqRequestWorkflow.all_encrypted_options_fields.map(&:to_s) |
                                ::Vmdb::Settings::PASSWORD_FIELDS.map(&:to_s)
    end

    def self.time_attributes
      @time_attributes ||= ApiConfig.collections.each.with_object(Set.new(%w(expires_on))) do |(_, cspec), result|
        next if cspec[:klass].blank?
        klass = cspec[:klass].constantize
        klass.columns_hash.each do |name, typeobj|
          result << name if %w(date datetime).include?(typeobj.type.to_s)
        end
      end
    end

    def self.user_token_service
      @user_token_service ||= UserTokenService.new(ApiConfig, :log_init => true)
    end

    def self.fetch_encrypted_attribute_names(klass)
      return [] unless klass.respond_to?(:encrypted_columns)
      encrypted_objects_checked[klass.name] ||= klass.encrypted_columns.each do |attr|
        encrypted_attributes << attr
      end
    end

    def self.encrypted_objects_checked
      @encrypted_objects_checked ||= {}
    end
  end
end
