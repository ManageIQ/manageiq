class AddProviderOptionsToVms < ActiveRecord::Migration[5.0]
  def change
    add_column :vms, :provider_options, :text, :comment => "Opaque container"\
        " for provider-specific options/flags. Anything stored here should be"\
        " considered opaque to the general ManageIQ system."
  end
end
