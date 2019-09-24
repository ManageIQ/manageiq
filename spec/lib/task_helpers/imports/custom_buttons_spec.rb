describe TaskHelpers::Imports::CustomButtons do
  let(:data_dir) { File.join(File.expand_path(__dir__), 'data', 'custom_buttons') }
  let(:custom_button_file)            { 'CustomButtons.yaml' }
  let(:bad_custom_button_file)        { 'CustomButtonsBad.yaml' }
  let(:custom_button_set_name)        { 'group1|Vm|' }
  let(:custom_button_set_description) { 'group1' }
  let(:resource_action_ae_namespace)  { 'SYSTEM' }
  let(:options)                       { {:source => source} }

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
          file = Tempfile.new('foo.yaml', data_dir)
          file.write("bad yaml here")
          TaskHelpers::Imports::CustomButtons.new.import(options)
          assert_raises_import_error
          assert_imports_only_custom_button_set_one
        end
      end
    end

    describe "when the source is a file" do
      let(:source) { "#{data_dir}/#{custom_button_file}" }

      context "without existing buttons" do
        context "only imports good yaml" do
          it 'imports a specified file' do
            TaskHelpers::Imports::CustomButtons.new.import(options)
            assert_test_custom_button_set_present
            assert_imports_only_custom_button_set_one
          end
        end

        context "doesn't import bad yaml" do
          let(:source) { "#{data_dir}/#{bad_custom_button_file}" }
          it 'does not imports a specified file' do
            TaskHelpers::Imports::CustomButtons.new.import(options)
            assert_imports_no_custom_buttons
          end
        end
      end

      context "with existing identical buttons" do
        it 'should not import anything' do
          TaskHelpers::Imports::CustomButtons.new.import(options)
          assert_raises_import_error
          assert_imports_only_custom_button_set_one
        end
      end
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
