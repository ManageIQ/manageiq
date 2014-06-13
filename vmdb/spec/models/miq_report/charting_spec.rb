require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

describe MiqReport do
  before(:each) do
    MiqRegion.seed
    guid = MiqUUID.new_guid
    MiqServer.stub(:my_guid => guid)
    FactoryGirl.create(:miq_server, :zone => FactoryGirl.create(:zone), :guid => guid, :status => "started")
    MiqServer.my_server(true)

    @group = FactoryGirl.create(:miq_group)
    @user  = FactoryGirl.create(:user, :miq_groups => [@group])

    5.times do |i|
      vm = FactoryGirl.build(:vm_vmware)
      vm.evm_owner_id = @user.id           if i > 2
      vm.miq_group_id = @user.current_group.id if vm.evm_owner_id || (i > 1)
      vm.save
    end

    @report_theme = 'miq'
    @show_title   = true
    @options = MiqReport.graph_options(600, 400)

    Charting.stub(:detect_available_plugin).and_return(JqplotCharting)
  end

  context 'graph_options' do
    it 'returns a hash with options' do
      expect(MiqReport.graph_options(400, 600)).to include(
        :totalwidth  => 400,
        :totalheight => 600
      )
    end
  end

  context 'to_chart' do
    it "raises an exception for missing sortby or type" do
      rpt = FactoryGirl.create(:miq_report_with_non_nil_condition)

      # Can't create a graph without a sortby column
      expect { rpt.to_chart(@report_theme, @show_title, @options) }.to raise_exception

      # Graph type not specified
      expect { rpt.to_chart(@report_theme, @show_title, @options) }.to raise_exception
    end

    it "returns an empty chart for a report with empty results" do
      rpt = MiqReport.new(:db => "Vm", :sortby => "name", :order => "Descending",
                          :graph => {:type => 'Pie'})
      rpt.to_chart(@report_theme, @show_title, @options)
      chart = rpt.chart

      # {:data=>[[nil]], :options=>{:title=>"No records found for this chart"}}
      expect(chart[:data][0][0]).to be_nil
      expect(chart[:options][:title]).to eq('No records found for this chart')
    end

    it "returns a valid chart for a report with data" do
      MiqReport.seed_report(name = "Vendor and Guest OS")
      rpt = MiqReport.find_by_name(name)

      rpt.generate_table(:userid => 'test')
      rpt.to_chart(@report_theme, @show_title, @options)
      chart = rpt.chart

      expect(chart[:data][0][0]).to eq(5)
      expect(chart[:options][:title]).to eq(name)
    end
  end
end
