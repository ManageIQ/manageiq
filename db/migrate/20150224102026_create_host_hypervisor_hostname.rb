class CreateHostHypervisorHostname < ActiveRecord::Migration[4.2]
  def change
    add_column :hosts, :hypervisor_hostname, :string
  end
end
