class AddStateToMiqProvision < ActiveRecord::Migration
  def self.up
    add_column     :miq_provisions,          :status,  :string
    add_column     :miq_provision_requests,  :status,  :string
  end

  def self.down
    remove_column  :miq_provisions,          :status
    remove_column  :miq_provision_requests,  :status
  end
end
