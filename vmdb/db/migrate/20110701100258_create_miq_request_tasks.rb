class CreateMiqRequestTasks < ActiveRecord::Migration
  class MiqProvisionRequest < ActiveRecord::Base
    serialize :options
  end

  class MiqProvision < ActiveRecord::Base
    serialize :options
  end

  class MiqRequest < ActiveRecord::Base; end

  def self.convert_miq_provisions()
    MiqProvision.all.each do |p|
      upd_attrs = {}
      upd_attrs.merge!(:destination_id => p.vm_id,     :destination_type => 'Vm') unless p.vm_id.nil?
      upd_attrs.merge!(:source_id      => p.src_vm_id, :source_type      => 'Vm') unless p.src_vm_id.nil?

      if (prov_req = MiqProvisionRequest.find_by_id(p.miq_provision_request_id))
        req = MiqRequest.find_by_resource_type_and_resource_id('MiqProvisionRequest',prov_req.id)
        upd_attrs[:miq_request_id] = req.id unless req.nil?
      end
      p.update_attribute(:type, 'MiqProvision')
      p.update_attributes!(upd_attrs)
    end
  end

  def self.up
    # MiqHostProvisioning table was only internally used, delete references to it
    say_with_time("Destroying MiqRequests for Host Provisions") do
      MiqRequest.delete_all(:resource_type => "MiqHostProvisionRequest")
    end
    drop_table :miq_host_provision_requests
    drop_table :miq_host_provisions

    change_table :miq_provisions do |t|
      t.string      :type
      t.rename      :provision_type, :request_type
      t.belongs_to  :miq_request
      t.belongs_to  :source,         :polymorphic => true
      t.belongs_to  :destination,    :polymorphic => true
    end

    # Adjust data in columns to match the new model
    say_with_time("Converting MiqProvisions") { self.convert_miq_provisions() }

    change_table :miq_provisions do |t|
      t.remove             :src_vm_id
      t.remove_belongs_to  :vm
      t.remove_belongs_to  :miq_provision_request
    end

    rename_table :miq_provisions, :miq_request_tasks
  end


  def self.down
    change_table :miq_request_tasks do |t|
      t.rename             :request_type,   :provision_type
      t.integer            :src_vm_id,      :limit => 8
      t.belongs_to         :vm
      t.belongs_to         :miq_provision_request
      t.remove             :type
      t.remove_belongs_to  :miq_request
      t.remove_belongs_to  :source,         :polymorphic => true
      t.remove_belongs_to  :destination,    :polymorphic => true
    end

    rename_table :miq_request_tasks, :miq_provisions

    create_table :miq_host_provision_requests do |t|
      t.string      :description
      t.string      :state
      t.string      :provision_type
      t.string      :userid
      t.text        :options
      t.string      :message
      t.string      :status
      t.timestamps
    end

    create_table :miq_host_provisions do |t|
      t.string      :description
      t.string      :state
      t.string      :provision_type
      t.string      :userid
      t.text        :options
      t.string      :message
      t.string      :status
      t.bigint      :miq_host_provision_request_id
      t.bigint      :host_id
      t.timestamps
    end
  end
end
