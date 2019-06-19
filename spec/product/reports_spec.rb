describe 'YAML reports' do
  REPORT_DIRS  = [Rails.root.join("product", "reports"), "#{ApplicationController::TIMELINES_FOLDER}/miq_reports"]
  REPORT_YAMLS = REPORT_DIRS.collect { |dir| Dir.glob(File.join(dir, "**", "*.yaml")) }.flatten
  CHART_DIRS   = [ApplicationController::Performance::CHARTS_REPORTS_FOLDER]
  CHART_YAMLS  = CHART_DIRS.collect { |dir| Dir.glob(File.join(dir, "**", "*.yaml")) }.flatten

  before do
    EvmSpecHelper.local_miq_server
    @user = FactoryBot.create(:user_with_group)
  end

  context "product directory" do
    it 'is not empty and contains reports' do
      expect(REPORT_YAMLS.length).to be > 0
      expect(CHART_YAMLS.length).to be > 0
    end
  end

  shared_examples "all report type examples" do |report_yaml|
    let(:yaml)        { report_yaml }
    let(:report_data) { YAML.load(File.open(yaml)) }

    it 'defines headers that match col_order' do
      col_order = report_data['col_order'].length
      headers = report_data['headers'].length
      expect(headers).to eq(col_order)
    end
  end

  context "regular reports" do
    shared_examples "regular report examples" do |report_yaml|
      let(:yaml)        { report_yaml }
      let(:report_data) { YAML.load(File.open(yaml)) }

      it 'can be built even though without data' do
        # TODO: ApplicationController::Performance::CHARTS_REPORTS_FOLDER
        report_data.delete('menu_name')
        report = MiqReport.new(report_data)
        expect(report.table).to be_nil
        report.generate_table(:userid => @user.userid)
        expect(report.table).to be_kind_of(Ruport::Data::Table)
      end

      it 'defines correct (existing) col_order columns' do
        cols = report_data['cols'] + collect_columns(report_data['include'])
        dangling = report_data['col_order'].reject do |col|
          cols.include?(col) || %w(max avg).include?(col.split('__')[-1])
        end
        expect(dangling).to eq([])
      end

      it "defines fields for reporting by fully qualified name" do
        report_data.delete('menu_name')
        report = MiqReport.new(report_data)
        report.generate_table(:userid => @user.userid)
        cols_from_data = report.table.column_names.to_set
        cols_from_yaml = report_data['col_order'].to_set
        expect(cols_from_yaml).to be_subset(cols_from_data)
      end
    end

    REPORT_YAMLS.each do |report_yaml|
      context "#{File.basename(File.dirname(report_yaml))}/#{File.basename(report_yaml, '.yaml')}" do
        include_examples "regular report examples",  report_yaml
        include_examples "all report type examples", report_yaml
      end
    end
  end

  context "chart reports" do
    CHART_YAMLS.each do |report_yaml|
      context "#{File.basename(File.dirname(report_yaml))}/#{File.basename(report_yaml, '.yaml')}" do
        include_examples "all report type examples", report_yaml
      end
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
end
