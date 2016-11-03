class EmsBlockStorageController < ApplicationController
  include EmsCommon
  include Mixins::EmsCommonAngular
  include Mixins::GenericSessionMixin

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def self.model
    ManageIQ::Providers::StorageManager
  end

  def self.table_name
    @table_name ||= "ems_storage"
  end

  def ems_path(*args)
    path_hash = {:action => 'show', :id => args[0].id.to_s }
    path_hash.merge(args[1])
  end

  def new_ems_path
    {:action => 'new'}
  end

  def ems_storage_form_fields
    ems_form_fields
  end

  # Show the main MS list view
  def show_list
    opts = {:supported_features_filter => "supports_block_storage?",
            :model           => model}
    process_show_list(opts)
  end
end
