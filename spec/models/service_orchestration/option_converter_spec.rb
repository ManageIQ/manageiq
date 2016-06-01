describe ServiceOrchestration::OptionConverter do
  let(:dialog_options) do
    {
      'dialog_stack_manager'         => FactoryGirl.create(:ems_amazon).id,
      'dialog_stack_template'        => FactoryGirl.create(:orchestration_template).id,
      'dialog_stack_name'            => 'test_stack_name',
      'dialog_stack_onfailure'       => 'ROLLBACK',
      'dialog_stack_timeout'         => 100,
      'dialog_param_para1'           => 'stack_param1',
      'password::dialog_param_para2' => 'v2:{c2XR8/Yl1CS0phoOVMNU9w==}'
    }
  end

  let(:amazon) { FactoryGirl.create(:ems_amazon) }
  let(:klass) { ServiceOrchestration::OptionConverter }  # alias to save typing

  it '#stack_create_options' do
    converter = klass.get_converter(dialog_options, ManageIQ::Providers::Amazon::CloudManager)
    expect(converter.stack_create_options).to have_attributes(
      :timeout_in_minutes => 100,
      :disable_rollback   => false,
      :parameters         => {'para1' => 'stack_param1', 'para2' => 'admin'}
    )
  end

  it 'parses other dialog options correctly' do
    expect(klass.get_stack_name(dialog_options)).to eq('test_stack_name')
    expect(klass.get_manager(dialog_options)).to be_kind_of(ManageIQ::Providers::Amazon::CloudManager)
    expect(klass.get_template(dialog_options)).to be_kind_of(OrchestrationTemplate)
  end
end
