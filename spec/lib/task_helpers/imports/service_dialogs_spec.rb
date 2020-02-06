RSpec.describe TaskHelpers::Imports::ServiceDialogs do
  let(:data_dir)         { File.join(File.expand_path(__dir__), 'data', 'service_dialogs') }
  let(:dialog_file)      { 'Simple_Dialog.yaml' }
  let(:mod_dialog_file)  { 'Simple_Dialog_modified.yml' }
  let(:dialog_one_label) { 'Simple Dialog' }
  let(:dialog_two_label) { 'Test Dialog' }
  let(:dialog_one_desc)  { 'Simple Dialog to test export and import' }
  let(:dialog_tab_label) { 'Modified New tab' }

  describe "#import" do
    let(:options) { {:source => source} }

    describe "when the source is a directory" do
      let(:source) { data_dir }

      it 'imports all .yaml files in a specified directory' do
        expect do
          TaskHelpers::Imports::ServiceDialogs.new.import(options)
        end.to_not output.to_stderr
        assert_test_service_dialog_one_present
        assert_test_service_dialog_two_present
      end
    end

    describe "when the source is a file" do
      let(:source) { "#{data_dir}/#{dialog_file}" }

      it 'imports a specified file' do
        expect do
          TaskHelpers::Imports::ServiceDialogs.new.import(options)
        end.to_not output.to_stderr
        assert_test_service_dialog_one_present
      end
    end

    describe "when the source file modifies an existing file" do
      let(:source) { "#{data_dir}/#{mod_dialog_file}" }

      before do
        TaskHelpers::Imports::ServiceDialogs.new.import(:source => "#{data_dir}/#{dialog_file}")
      end

      it 'modifies an existing service dialog' do
        TaskHelpers::Imports::ServiceDialogs.new.import(options)
      end
    end
  end

  def assert_test_service_dialog_one_present
    d = Dialog.find_by(:label => dialog_one_label)
    expect(d.description).to eq(dialog_one_desc)
    expect(d.dialog_tabs.count).to eq(1)
  end

  def assert_test_service_dialog_two_present
    d = Dialog.find_by(:label => dialog_two_label)
    expect(d.description).to be nil
    expect(d.dialog_tabs.count).to eq(1)
  end

  def assert_test_service_dialog_modified
    d = Dialog.find_by(:label => dialog_one_label)
    expect(d.dialog_tabs.first.label).to eq(dialog_tab_label)
  end
end
