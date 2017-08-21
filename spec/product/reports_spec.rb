describe 'YAML reports' do
  let(:report_dirs) { [Rails.root.join("product", "reports"), "#{ApplicationController::TIMELINES_FOLDER}/miq_reports"] }
  let(:report_yamls) { report_dirs.collect { |dir| Dir.glob(File.join(dir, "**", "*.yaml")) }.flatten }
  let(:chart_dirs) { [ApplicationController::Performance::CHARTS_REPORTS_FOLDER] }
  let(:chart_yamls) { chart_dirs.collect { |dir| Dir.glob(File.join(dir, "**", "*.yaml")) }.flatten }
  let!(:user) { FactoryGirl.create(:user_with_group) }

  before :each do
    EvmSpecHelper.local_miq_server
    @user = FactoryGirl.create(:user_with_group)
  end

  it 'is not empty' do
    expect(report_yamls.length).to be > 0
  end

  it 'can be build even though without data' do
    # TODO: ApplicationController::Performance::CHARTS_REPORTS_FOLDER
    report_yamls.each do |yaml|
      report_data = YAML.load(File.open(yaml))
      report_data.delete('menu_name')
      report = MiqReport.new(report_data)
      expect(report.table).to be_nil
      report.generate_table(:userid => @user.userid)
      expect(report.table).to be_kind_of(Ruport::Data::Table)
    end
  end

  it 'defines headers that match col_order' do
    (chart_yamls + report_yamls).each do |yaml|
      report_data = YAML.load(File.open(yaml))
      col_order = report_data['col_order'].length
      headers = report_data['headers'].length
      expect(headers).to eq(col_order)
    end
  end

  it 'defines correct (existing) col_order columns' do
    report_yamls.each do |yaml|
      report_data = YAML.load(File.open(yaml))
      cols = report_data['cols'] + collect_columns(report_data['include'])
      dangling = report_data['col_order'].reject do |col|
        cols.include?(col) || %w(max avg).include?(col.split('__')[-1])
      end
      expect(dangling).to eq([])
    end
  end

  def collect_columns(include_hash, parent = nil)
    return [] if include_hash.nil?
    include_hash.inject([]) do |cols, (table_name, data)|
      full_path = if parent
                    "#{parent}.#{table_name}"
                  else
                    table_name.to_s
                  end
      cols += data["columns"].collect { |col_name| "#{full_path}.#{col_name}" } if data['columns']
      cols + collect_columns(data['include'], full_path)
    end
  end

  it "defines fields for reporting by fully qualified name" do
    report_yamls.each do |yaml|
      report_yaml = YAML.load(File.open(yaml))
      report_yaml.delete('menu_name')
      report = MiqReport.new(report_yaml)
      report.generate_table(:userid => @user.userid)
      cols_from_data = report.table.column_names.to_set
      cols_from_yaml = report_yaml['col_order'].to_set
      expect(cols_from_yaml).to be_subset(cols_from_data)
    end
  end
end
