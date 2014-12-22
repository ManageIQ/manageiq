class AddMiqProvisionsToMiqRequests < ActiveRecord::Migration
  class MiqRequest < ActiveRecord::Base
    serialize :options
  end

  class MiqProvisionRequest < ActiveRecord::Base
    serialize :options
  end

  class MiqRequestTask < ActiveRecord::Base; end
  class MiqProvision < MiqRequestTask; end

  def self.convert_miq_requests()
    MiqRequest.all.each do |req|
      next unless req.resource_type == "MiqProvisionRequest"
      prov_req = MiqProvisionRequest.find_by_id(req.resource_id)
      unless prov_req.nil?
        req_attrs = prov_req.attributes.dup
        %w{id description created_at updated_at created_on updated_on}.each {|key| req_attrs.delete(key)}
        req_attrs["request_type"]  = req_attrs.delete("provision_type")
        req_attrs["request_state"] = req_attrs.delete("state")
        if req_attrs.has_key?("src_vm_id")
          req_attrs["source_id"]   = req_attrs.delete("src_vm_id")
          req_attrs["source_type"] = "Vm" unless req_attrs["source_id"].nil?
        end
        req.update_attributes!(req_attrs)
      end
    end
  end

  def self.up

    change_table :miq_requests do |t|
      t.string      :request_type
      t.string      :request_state
      t.string      :message
      t.string      :status
      t.text        :options
      t.string      :userid
      t.belongs_to  :source,         :polymorphic => true, :type => :bigint
      t.belongs_to  :destination,    :polymorphic => true, :type => :bigint
      t.rename      :state,          :approval_state
    end

    # Adjust data in columns to match the new model
    say_with_time("Converting MiqRequests") { self.convert_miq_requests() }

    change_table :miq_requests do |t|
      t.rename      :resource_type,  :type
      t.remove      :resource_id
    end

    drop_table :miq_provision_requests
  end

  def self.down
    change_table :miq_requests do |t|
      t.remove             :request_type
      t.remove             :request_state
      t.remove             :message
      t.remove             :status
      t.remove             :options
      t.remove             :userid
      t.remove_belongs_to  :source,         :polymorphic => true
      t.remove_belongs_to  :destination,    :polymorphic => true
      t.rename             :approval_state, :state
      t.rename             :type,           :resource_type
      t.integer            :resource_id,   :limit => 8
    end

    create_table :miq_provision_requests do |t|
      t.string        :description
      t.string        :state
      t.string        :provision_type
      t.string        :userid
      t.text          :options
      t.datetime      :created_on
      t.datetime      :updated_on
      t.string        :message
      t.belongs_to    :src_vm, :type => :bigint
      t.string        :status
    end

    MiqRequest.delete_all
    MiqProvision.delete_all
  end
end
