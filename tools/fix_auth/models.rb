require 'active_support/all'
require 'active_record'
require 'securerandom'

module FixAuth
  class FixAuthentication < ActiveRecord::Base
    include FixAuth::AuthModel
    self.table_name = "authentications"
    self.password_columns = %w[password auth_key]
    self.inheritance_column = :_type_disabled
  end

  class FixConfigurationScript < ActiveRecord::Base
    include FixAuth::AuthConfigModel
    self.table_name = "configuration_scripts"
    self.password_columns = %w[credentials]

    # no particular fields for passwords, instead encrypt everything
    self.password_fields = []
    # blank prefix matches all fields
    self.password_prefix = ""
  end

  class FixMiqDatabase < ActiveRecord::Base
    include FixAuth::AuthModel
    self.table_name = "miq_databases"
    self.password_columns = %w[registration_http_proxy_server registration_http_proxy_password
                               session_secret_token csrf_secret_token]

    def self.hardcode(old_value, _new_value)
      super(old_value, SecureRandom.hex(64))
    end
  end

  class FixMiqAeValue < ActiveRecord::Base
    include FixAuth::AuthModel
    self.table_name = "miq_ae_values"
    self.password_columns = %w[value]

    belongs_to :field,    :class_name => "FixMiqAeField",    :foreign_key => :field_id

    # add foreign keys so includes will work
    def self.select_columns
      super + [:field_id]
    end

    # only bring back columns that store passwords
    # we want to use joins, but using joins makes this readonly, so we're using includes instead
    def self.contenders
      super.includes(:field).where(:miq_ae_fields => {:datatype => 'password'})
    end
  end

  class FixMiqAeField < ActiveRecord::Base
    include FixAuth::AuthModel
    self.table_name = "miq_ae_fields"
    self.password_columns = %w[default_value]

    # only fix columns with password values
    def self.contenders
      super.where(:datatype => 'password')
    end
  end

  class FixMiqRequest < ActiveRecord::Base
    include FixAuth::AuthConfigModel
    # don't want to leverage STI
    self.inheritance_column = :_type_disabled
    self.password_columns = %w[options]
    self.password_fields = %w[root_password sysprep_password sysprep_domain_password]
    self.password_prefix = "password::"
    self.symbol_keys = true
    self.table_name = "miq_requests"
  end

  class FixMiqRequestTask < ActiveRecord::Base
    include FixAuth::AuthConfigModel
    # don't want to leverage STI
    self.inheritance_column = :_type_disabled
    self.password_columns = %w[options]
    self.password_fields = %w[root_password sysprep_password sysprep_domain_password]
    self.password_prefix = "password::"
    self.symbol_keys = true
    self.table_name = "miq_request_tasks"
  end

  class FixSettingsChange < ActiveRecord::Base
    include FixAuth::AuthModel
    self.table_name = "settings_changes"
    self.password_columns = %w[value]

    serialize :value

    def self.contenders
      query = password_fields.collect do |field|
        "(key LIKE '%/#{field}')"
      end.join(" OR ")

      super.where(query)
    end

    # keys that contain protected fields in the settings
    def self.password_fields
      Vmdb::SettingsWalker::PASSWORD_FIELDS +
        %w[openssl_verify_mode]
    end
  end

  class FixDatabaseYml
    attr_accessor :id
    attr_accessor :yml

    include FixAuth::AuthConfigModel

    class << self
      attr_accessor :available_columns
      attr_accessor :file_name

      def table_name
        file_name.gsub(".yml", "")
      end
    end

    def initialize(options = {})
      options.each { |n, v| public_send(:"#{n}=", v) }
    end

    def load
      @yml = File.read(id)
      self
    end

    def changed?
      true
    end

    def save!
      File.write(id, @yml)
    end

    self.password_fields = %w[password]
    self.available_columns = %w[yml]

    def self.contenders
      [new(:id => file_name).load]
    end
  end
end
