require 'active_support/all'
require 'active_record'
require 'securerandom'
require 'util/extensions/miq-deep'

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
    self.password_columns = %w(registration_http_proxy_server registration_http_proxy_password
                               session_secret_token csrf_secret_token)

    def self.hardcode(old_value, _new_value)
      super(old_value, SecureRandom.hex(64))
    end
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

  class FixMiqRequest < ActiveRecord::Base
    include FixAuth::AuthConfigModel
    # don't want to leverage STI
    self.inheritance_column = :_type_disabled
    self.password_columns = %w(options)
    self.password_fields = %w(root_password sysprep_password sysprep_domain_password)
    self.password_prefix = "password::"
    self.symbol_keys = true
    self.table_name = "miq_requests"

    def self.contenders
      where("options like '%password%'")
    end
  end

  class FixMiqRequestTask < ActiveRecord::Base
    include FixAuth::AuthConfigModel
    # don't want to leverage STI
    self.inheritance_column = :_type_disabled
    self.password_columns = %w(options)
    self.password_fields = %w(root_password sysprep_password sysprep_domain_password)
    self.password_prefix = "password::"
    self.symbol_keys = true
    self.table_name = "miq_request_tasks"

    def self.contenders
      where("options like '%password%'")
    end
  end

  class FixDatabaseYml
    attr_accessor :id
    attr_accessor :yaml
    include FixAuth::AuthConfigModel

    class << self
      attr_accessor :available_columns
      attr_accessor :file_name
      alias_method  :table_name, :file_name
    end

    def initialize(options = {})
      options.each { |n, v| public_send("#{n}=", v) }
    end

    def load
      @yaml = File.read(id)
      self
    end

    def save!
      File.write(id, @yaml)
    end

    self.password_fields = %w(password)
    self.available_columns = %w(yaml)

    def self.contenders
      [new(:id => file_name).load]
    end
  end
end
