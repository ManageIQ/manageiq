RSpec.describe TaskHelpers::Imports::CustomButtons do
  let(:data_dir) { File.join(File.expand_path(__dir__), 'data', 'custom_buttons') }
  let(:custom_button_file)            { 'CustomButtons.yaml' }
  let(:bad_custom_button_file)        { 'CustomButtonsBad.yaml' }
  let(:custom_button_set_name)        { 'group1|Vm|' }
  let(:custom_button_set_description) { 'group1' }
  let(:resource_action_ae_namespace)  { 'SYSTEM' }
  let(:connect_dialog_by_name) { true }
  let(:options) { {:source => source, :connect_dialog_by_name => connect_dialog_by_name} }
  let!(:test_dialog) { FactoryBot.create(:dialog, :label => 'dialog') }
  let!(:test_dialog_2) { FactoryBot.create(:dialog, :label => 'dialog 2') }

  describe "#import" do
    describe "when the source is a directory" do
      let(:source) { data_dir }

      context "without existing buttons" do
        it 'imports all formatted .yaml files in a specified directory' do
          TaskHelpers::Imports::CustomButtons.new.import(options)
          assert_test_custom_button_set_present
        end
      end

      context "with existing identical buttons" do
        it 'should raise' do
          TaskHelpers::Imports::CustomButtons.new.import(options)
          assert_raises_import_error
        end
      end

      context "yaml import failure" do
        it 'should raise' do
          Tempfile.create(%w[foo .yaml], data_dir) do |file|
            file.write("bad yaml here")
            assert_raises_import_error
          end
        end
      end
    end

    describe "when the source is a file" do
      let(:source) { "#{data_dir}/#{custom_button_file}" }

      context "without existing buttons" do
        context "only imports good yaml" do
          context "connect dialog flag is set" do
            it 'imports a specified file' do
              TaskHelpers::Imports::CustomButtons.new.import(options)
              assert_test_custom_button_set_present
              assert_imports_only_custom_button_set_one
              assert_dialog_is_set(true)
            end
          end
          context "connect dialog flag not set" do
            let(:connect_dialog_by_name) { false }
            it 'imports a specified file' do
              TaskHelpers::Imports::CustomButtons.new.import(options)
              assert_test_custom_button_set_present
              assert_imports_only_custom_button_set_one
              assert_dialog_is_set(false)
            end
          end
        end
      end

      context "doesn't import bad yaml" do
        let(:source) { "#{data_dir}/#{bad_custom_button_file}" }
        it 'does not imports a specified file' do
          TaskHelpers::Imports::CustomButtons.new.import(options)
          assert_imports_no_custom_buttons
        end
      end

      context "with existing identical buttons" do
        it 'should not import anything' do
          TaskHelpers::Imports::CustomButtons.new.import(options)
          assert_imports_only_custom_button_set_one
        end
      end
    end
  end

  def assert_dialog_is_set(connect)
    btn1 = CustomButton.find_by(:name => 'button 1')
    expect(btn1).to be_an(CustomButton)
    if connect
      expect(btn1.resource_action.dialog.id).to eq(test_dialog_2.id)
    else
      expect(btn1.resource_action.dialog).to be_nil
    end
  end

  def assert_test_custom_button_set_present
    cbs = CustomButtonSet.find_by(:name => custom_button_set_name)
    expect(cbs.custom_buttons.count).to eq(3)
    expect(cbs.description).to eq(custom_button_set_description)
    expect(cbs.custom_buttons.first.resource_action.ae_namespace).to eq(resource_action_ae_namespace)
    expect(cbs.custom_buttons.pluck(:userid)).to eq(%w(admin admin admin))
  end

  def assert_imports_only_custom_button_set_one
    expect(CustomButton.count).to eq(3)
  end

  def assert_imports_no_custom_buttons
    expect(CustomButton.count).to eq(0)
  end

  def assert_raises_import_error
    expect { TaskHelpers::Imports::CustomButtons.new.import(options) }.to raise_error(StandardError, /Error importing/)
  end
end
