RSpec.describe TaskHelpers::Exports::Widgets do
  let(:export_dir) do
    Dir.mktmpdir('miq_exp_dir')
  end

  before do
    _guid, _server, _zone = EvmSpecHelper.create_guid_miq_server_zone

    MiqReport.seed_report("Vendor and Guest OS")
    MiqWidget.seed_widget("chart_vendor_and_guest_os")
    MiqWidget.sync_from_hash(YAML.safe_load("
    description: Test Widget
    title: Test Widget
    content_type: report
    options:
      :col_order:
        - name
        - vendor_display
      :row_count: 5
    visibility:
      :roles:
      - _ALL_
    resource_name: Vendor and Guest OS
    resource_type: MiqReport
    enabled: true
    read_only: false
    ", [Symbol], %i(col_order row_count roles)))
    MiqWidget.sync_from_hash(YAML.safe_load("
    description: Test Widget 2
    title: Test Widget 2
    content_type: report
    options:
      :col_order:
        - name
        - vendor_display
      :row_count: 5
    visibility:
      :roles:
      - _ALL_
    resource_name: Vendor and Guest OS
    resource_type: MiqReport
    enabled: true
    read_only: false
    ", [Symbol], %i(col_order row_count roles)))
  end

  after do
    FileUtils.remove_entry export_dir
  end

  describe "when --all is not specified" do
    let(:widget_filename1) { "#{export_dir}/Test_Widget.yaml" }
    let(:widget_filename2) { "#{export_dir}/Test_Widget_2.yaml" }

    it "exports custom widgets to individual files in a given directory" do
      TaskHelpers::Exports::Widgets.new.export(:directory => export_dir)
      expect(Dir[File.join(export_dir, '**', '*')].count { |file| File.file?(file) }).to eq(2)
      widget1 = YAML.load_file(widget_filename1)
      expect(widget1.first["MiqWidget"]["description"]).to eq("Test Widget")
      widget2 = YAML.load_file(widget_filename2)
      expect(widget2.first["MiqWidget"]["description"]).to eq("Test Widget 2")
    end
  end

  describe "when --all is specified" do
    let(:widget_filename1) { "#{export_dir}/Test_Widget.yaml" }
    let(:widget_filename2) { "#{export_dir}/Test_Widget_2.yaml" }
    let(:widget_filename3) { "#{export_dir}/chart_vendor_and_guest_os.yaml" }

    it "exports all reports to individual files in a given directory" do
      TaskHelpers::Exports::Widgets.new.export(:directory => export_dir, :all => true)
      expect(Dir[File.join(export_dir, '**', '*')].count { |file| File.file?(file) }).to eq(3)
      widget1 = YAML.load_file(widget_filename1)
      expect(widget1.first["MiqWidget"]["description"]).to eq("Test Widget")
      widget2 = YAML.load_file(widget_filename2)
      expect(widget2.first["MiqWidget"]["description"]).to eq("Test Widget 2")
      widget3 = YAML.load_file(widget_filename3)
      expect(widget3.first["MiqWidget"]["description"]).to eq("chart_vendor_and_guest_os")
    end
  end
end
