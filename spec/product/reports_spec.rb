describe 'YAML reports' do
  let(:report_dirs) { [REPORTS_FOLDER, "#{TIMELINES_FOLDER}/miq_reports"] }
  let(:report_yamls) { report_dirs.collect { |dir| Dir.glob(File.join(dir, "**", "*.yaml")) }.flatten }
  let!(:user) { FactoryGirl.create(:user_with_group) }

  # TODO: CHARTS_REPORTS_FOLDER

  before :each do
    EvmSpecHelper.local_miq_server
    @user = FactoryGirl.create(:user_with_group)
  end

  it 'is not empty' do
    expect(report_yamls.length).to be > 0
  end

  it 'can be build even though without data' do
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
    report_yamls.each do |yaml|
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

  def collect_columns(include_hash)
    return [] if include_hash.nil?
    include_hash.inject([]) do |cols, (table_name, data)|
      cols += data["columns"].collect { |col_name| "#{table_name}.#{col_name}" } if data['columns']
      cols + collect_columns(data['include'])
    end
  end
end
