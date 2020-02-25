RSpec.describe MiqReport do
  before do
    EvmSpecHelper.local_miq_server

    @group = FactoryBot.create(:miq_group)
    @user  = FactoryBot.create(:user, :miq_groups => [@group])

    5.times do |i|
      vm = FactoryBot.build(:vm_vmware)
      vm.evm_owner_id = @user.id           if i > 2
      vm.miq_group_id = @user.current_group.id if vm.evm_owner_id || (i > 1)
      vm.save
    end

    @report_theme = 'miq'
    @show_title   = true
    @options = MiqReport.graph_options({ :title => "CPU (Mhz)", :type => "Line", :columns => ["col"] })

    allow(ManageIQ::Reporting::Charting).to receive(:backend).and_return(:c3)
    allow(ManageIQ::Reporting::Charting).to receive(:format).and_return(:c3)
  end

  context 'graph_options' do
    it 'returns a hash with options' do
      expect(MiqReport.graph_options({ :title => "CPU (Mhz)", :type => "Line", :columns => ["col"] })).to include(
        :type => "Line",
        :title => "CPU (Mhz)"
      )
    end
  end

  context 'to_chart' do
    it "raises an exception for missing sortby or type" do
      rpt = FactoryBot.create(:miq_report)

      # Can't create a graph without a sortby column
      expect { rpt.to_chart(@report_theme, @show_title, @options) }
        .to raise_error(RuntimeError, /Can't create a graph without a sortby column/)

      # Graph type not specified
      expect { rpt.to_chart(@report_theme, @show_title, @options) }
        .to raise_error(RuntimeError, /Can't create a graph without a sortby column/)
    end

    it "returns an empty chart for a report with empty results" do
      rpt = MiqReport.new(:db => "Vm", :sortby => "name", :order => "Descending",
                          :graph => {:type => 'Pie'})
      rpt.to_chart(@report_theme, @show_title, @options)
      chart = rpt.chart

      expect(chart[:data][:columns][0]).to be_nil
    end

    it "returns a valid chart for a report with data" do
      MiqReport.seed_report(name = "Vendor and Guest OS")
      rpt = MiqReport.find_by(:name => name)

      rpt.generate_table(:userid => 'test')
      rpt[:graph][:type] = 'StackedColumn'
      rpt.to_chart(@report_theme, @show_title, @options)
      chart = rpt.chart

      expect(chart[:data][:columns][0][1]).to eq(5)
    end
  end
end
