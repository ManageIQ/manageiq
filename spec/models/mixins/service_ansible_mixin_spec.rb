describe ServiceAnsibleMixin do
  let(:catalog_item) do
    {
      :name                        => 'test_ansible_catalog_item',
      :description                 => 'test ansible',
      :service_template_catalog_id => 999,
      :display                     => true,
      :config_info                 => {
        :provision => {
          :new_dialog_name       => 'test_dialog',
          :hosts                 => 'many',
          :credential_id         => 88,
          :network_credential_id => 87,
          :playbook_id           => 68
        },
      }
    }
  end

  let(:test_class) do
    Class.new do
      include ServiceAnsibleMixin
    end
  end

  it "only returns applied config_info keys" do
    actions_list = ServiceTemplateAnsiblePlaybook::CONFIG_ACTIONS
    action_final_list = []
    test_class.with_applied_config_info(actions_list, catalog_item[:config_info]) do |action|
      action_final_list << action
    end
    expect(actions_list).to eq [:provision, :retirement, :reconfigure]
    expect(action_final_list).to eq [:provision]
  end
end
