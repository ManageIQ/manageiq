require Rails.root.join("lib/rr_model_core")
require_relative "../stub_cache_mixin"

module MigrationHelper::SharedStubs
  class RrPendingChange < ActiveRecord::Base
    extend MigrationHelper::StubCacheMixin

    RR_TABLE_NAME_SUFFIX = "pending_changes"
    include RrModelCore

    def self.create_table
      clearing_caches do
        connection.create_table table_name, :force => true do |t|
          t.string    :change_table
          t.string    :change_key
          t.string    :change_new_key
          t.string    :change_type
          t.timestamp :change_time
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
