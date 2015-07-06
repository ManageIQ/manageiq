class CreateHostHypervisorHostname < ActiveRecord::Migration
  def change
    add_column :hosts, :hypervisor_hostname, :string
  end
end
