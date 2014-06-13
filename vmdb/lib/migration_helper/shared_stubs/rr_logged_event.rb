require Rails.root.join("lib/rr_model_core")
require_relative "../stub_cache_mixin"

module MigrationHelper::SharedStubs
  class RrLoggedEvent < ActiveRecord::Base
    extend MigrationHelper::StubCacheMixin

    RR_TABLE_NAME_SUFFIX = "logged_events"
    include RrModelCore

    def self.create_table
      clearing_caches do
        connection.create_table table_name, :force => true do |t|
          t.string    :activity
          t.string    :change_table
          t.string    :diff_type
          t.string    :change_key
          t.string    :left_change_type
          t.string    :right_change_type
          t.string    :description
          t.string    :long_description, :limit => 1000
          t.timestamp :event_time
          t.string    :diff_dump,        :limit => 2000
        end
      end
    end

    def self.drop_table
      clearing_caches do
        connection.drop_table table_name
      end
    end
  end
end
