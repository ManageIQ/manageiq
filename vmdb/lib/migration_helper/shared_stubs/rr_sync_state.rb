require Rails.root.join("lib/rr_model_core")
require_relative "../stub_cache_mixin"

module MigrationHelper::SharedStubs
  class RrSyncState < ActiveRecord::Base
    extend MigrationHelper::StubCacheMixin

    RR_TABLE_NAME_SUFFIX = "sync_state"
    include RrModelCore

    def self.create_table
      clearing_caches do
        connection.create_table table_name, :force => true do |t|
          t.string :table_name
          t.string :state
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
