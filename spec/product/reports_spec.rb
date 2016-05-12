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
end
