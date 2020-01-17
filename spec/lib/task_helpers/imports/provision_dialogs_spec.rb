RSpec.describe TaskHelpers::Imports::ProvisionDialogs do
  let(:data_dir) { File.join(File.expand_path(__dir__), 'data', 'provision_dialogs') }
  let(:dialog_file) { 'MiqProvisionWorkflow-test_miq_provision_dialogs_template.yaml' }
  let(:mod_dialog_file) { 'MiqProvisionWorkflow-test_miq_provision_dialogs_template_modified.yml' }
  let(:dialog_one_name) { 'test_miq_provision_dialogs_template' }
  let(:dialog_two_name) { 'test2_miq_provision_dialogs_template' }
  let(:dialog_one_desc) { 'Test Sample VM Provisioning Dialog (Template)' }
  let(:dialog_two_desc) { 'Test2 Sample VM Provisioning Dialog (Template)' }

  describe "#import" do
    let(:options) { { :source => source } }

    describe "when the source is a directory" do
      let(:source) { data_dir }

      it 'imports all .yaml files in a specified directory' do
        expect do
          TaskHelpers::Imports::ProvisionDialogs.new.import(options)
        end.to_not output.to_stderr
        assert_test_provision_dialog_one_present
        assert_test_provision_dialog_two_present
      end
    end

    describe "when the source is a file" do
      let(:source) { "#{data_dir}/#{dialog_file}" }

      it 'imports a specified file' do
        expect do
          TaskHelpers::Imports::ProvisionDialogs.new.import(options)
        end.to_not output.to_stderr
        assert_test_provision_dialog_one_present
        assert_test_provision_dialog_two_not_present
      end
    end

    describe "when the source file modifies an existing file" do
      let(:source) { "#{data_dir}/#{mod_dialog_file}" }

      before do
        TaskHelpers::Imports::ProvisionDialogs.new.import(:source => "#{data_dir}/#{dialog_file}")
      end

      it 'modifies an existing provisioning dialog' do
        expect do
          TaskHelpers::Imports::ProvisionDialogs.new.import(options)
        end.to_not output.to_stderr
        assert_test_provision_dialog_one_modified
      end
    end
  end

  def assert_test_provision_dialog_one_present
    d = MiqDialog.find_by(:name => dialog_one_name)
    expect(d.description).to eq(dialog_one_desc)
    expect(d.valid?).to be true
  end

  def assert_test_provision_dialog_two_present
    d = MiqDialog.find_by(:name => dialog_two_name)
    expect(d.description).to eq(dialog_two_desc)
    expect(d.valid?).to be true
    expect(d.content[:dialogs][:purpose][:fields][:vm_tags][:required_tags]).to contain_exactly("environment")
  end

  def assert_test_provision_dialog_two_not_present
    d = MiqDialog.find_by(:name => dialog_two_name)
    expect(d).to be nil
  end

  def assert_test_provision_dialog_one_modified
    d = MiqDialog.find_by(:name => dialog_one_name)
    expect(d.content[:dialogs][:hardware][:fields][:number_of_sockets][:values].keys).to contain_exactly(1, 2, 4, 8, 16)
    expect(d.content[:dialogs][:hardware][:fields][:number_of_sockets][:values].values).to contain_exactly("1", "2", "4", "8", "16")
    expect(d.content[:dialogs][:hardware][:fields][:vm_memory][:values].keys).to contain_exactly("2048", "4096", "8192", "12288", "16384", "32768")
    expect(d.content[:dialogs][:hardware][:fields][:vm_memory][:values].values).to contain_exactly("2048", "4096", "8192", "12288", "16384", "32768")
  end
end
