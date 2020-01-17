RSpec.describe TaskHelpers::Imports::Widgets do
  describe "#import" do
    let(:data_dir) { File.join(File.expand_path(__dir__), 'data', 'widgets') }
    let(:widget_file1) { "Test_Widget.yaml" }
    let(:widget_file2) { "Test_Widget_Import.yaml" }
    let(:widget_name1) { "Test Widget" }
    let(:widget_name2) { "Test Widget Import" }
    let(:widget_title1) { "Test Widget" }
    let(:widget_title2) { "Test Widget Import" }
    let(:widget_cols1) { %w(name power_state last_scan_on) }
    let(:widget_cols2) { %w(name power_state) }
    let(:attr_err_file) { "Test_Widget_attr_error.yml" }
    let(:runt_err_file) { "Test_Widget_runtime_error.yml" }
    let(:options) { { :source => source } }

    before do
      _guid, @miq_server, @zone = EvmSpecHelper.create_guid_miq_server_zone
      FactoryBot.create(:user_admin, :userid => "admin")
    end

    describe "when the source is a directory" do
      let(:source) { data_dir }

      it 'imports all .yaml files in a specified directory' do
        expect do
          TaskHelpers::Imports::Widgets.new.import(options)
        end.to_not output.to_stderr
        expect(MiqWidget.all.count).to eq(2)
        assert_test_widget_one_present
        assert_test_widget_two_present
      end
    end

    describe "when the source is a file" do
      let(:source) { "#{data_dir}/#{widget_file1}" }

      it 'imports a specified file' do
        expect do
          TaskHelpers::Imports::Widgets.new.import(options)
        end.to_not output.to_stderr
        expect(MiqWidget.all.count).to eq(1)
        assert_test_widget_one_present
      end
    end

    describe "when the source file modifies an existing widget" do
      let(:update_file) { "Test_Widget_update.yml" }
      let(:source) { "#{data_dir}/#{update_file}" }

      before do
        TaskHelpers::Imports::Widgets.new.import(:source => "#{data_dir}/#{widget_file1}")
      end

      it 'overwrites an existing widget' do
        expect do
          TaskHelpers::Imports::Widgets.new.import(options)
        end.to_not output.to_stderr
        assert_test_widget_one_mod
      end
    end

    describe "when the source file has invalid settings" do
      context "when the object type is invalid" do
        let(:source) { "#{data_dir}/#{runt_err_file}" }

        it 'generates an error' do
          expect do
            TaskHelpers::Imports::Widgets.new.import(options)
          end.to output(/Incorrect format/).to_stderr
        end
      end

      context "when an attribute is invalid" do
        let(:source) { "#{data_dir}/#{attr_err_file}" }

        it 'generates an error' do
          expect do
            TaskHelpers::Imports::Widgets.new.import(options)
          end.to output(/unknown attribute 'invalid_title'/).to_stderr
        end
      end
    end
  end

  def assert_test_widget_one_present
    widget = MiqWidget.find_by(:name => widget_name1)
    expect(widget.title).to eq(widget_title1)
    expect(widget.options[:col_order]).to eq(widget_cols1)
    expect(widget.options[:col_order]).to_not include("storage.name")
  end

  def assert_test_widget_two_present
    widget = MiqWidget.find_by(:name => widget_name2)
    expect(widget.title).to eq(widget_title2)
    expect(widget.options[:col_order]).to eq(widget_cols2)
  end

  def assert_test_widget_one_mod
    widget = MiqWidget.find_by(:name => widget_name1)
    expect(widget.title).to include("Modified")
    expect(widget.options[:col_order]).to include("storage.name")
  end
end
