require 'active_support/all'
require 'active_record'
require 'util/extensions/miq-deep'
require 'vmdb/configuration_encoder'

module FixAuth
  class FixAuthentication < ActiveRecord::Base
    include FixAuth::AuthModel
    self.table_name = "authentications"
    self.password_columns = %w(password auth_key)
    self.inheritance_column = :_type_disabled
  end

  class FixMiqDatabase < ActiveRecord::Base
    include FixAuth::AuthModel
    self.table_name = "miq_databases"
    self.password_columns = %w(registration_http_proxy_server session_secret_token csrf_secret_token)
  end

  class FixMiqAeValue < ActiveRecord::Base
    include FixAuth::AuthModel
    self.table_name = "miq_ae_values"
    self.password_columns = %w(value)

    belongs_to :field,    :class_name => "FixMiqAeField",    :foreign_key => :field_id

    # only bring back columns that store passwords
    # we want to use joins, but using joins makes this readonly, so we're using includes instead
    def self.contenders
      super.includes(:field).where(:miq_ae_fields => {:datatype => 'password'})
    end
  end

  class FixMiqAeField < ActiveRecord::Base
    include FixAuth::AuthModel
    self.table_name = "miq_ae_fields"
    self.password_columns = %w(default_value)

    # only fix columns with password values
    def self.contenders
      super.where(:datatype => 'password')
    end
  end

  class FixConfiguration < ActiveRecord::Base
    include FixAuth::AuthConfigModel
    self.password_columns = %w(settings)
    self.password_fields = Vmdb::ConfigurationEncoder::PASSWORD_FIELDS
    self.table_name = "configurations"

    def self.display_record(r)
      puts "  #{r.id} (#{r.typ}.yml):"
    end

    # only bring back rows that store passwords
    def self.selection_criteria
      "typ = 'vmdb'"
    end
  end
end
