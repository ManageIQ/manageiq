class CreateJoinTableAuthenticationConfigurationScriptBase < ActiveRecord::Migration[5.0]
  def change
    create_table :authentication_configuration_script_bases do |t|
      t.bigint  :authentication_id
      t.bigint  :configuration_script_id
      t.index   :configuration_script_id, :name => 'configuration_script_id'
    end
  end
end
