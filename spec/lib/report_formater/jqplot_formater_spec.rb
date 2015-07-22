require 'spec_helper'

describe ReportFormatter::JqplotFormatter do
  before (:each) do
    MiqRegion.seed

    @guid = MiqUUID.new_guid
    MiqServer.stub(:my_guid).and_return(@guid)
    @zone       = FactoryGirl.create(:zone)
    @miq_server = FactoryGirl.create(:miq_server, :guid => @guid, :zone => @zone)
    MiqServer.stub(:my_server).and_return(@miq_server)


    @group = FactoryGirl.create(:miq_group)
    @user  = FactoryGirl.create(:user, :miq_groups => [@group])
  end

  context '#build_reporting_chart_other_numeric' do
    it 'builds 2d numeric charts' do
      FactoryGirl.create(:vm_vmware, :host => host = FactoryGirl.create(:host, :name => 'host'))#, :miq_server => @server)

      report = MiqReport.new(
          :db          => "Vm",
          :sortby      => ["host_name"],
          :order       => "Descending",
          :cols        => ["mem_cpu", "host_name"],
          :include     => {},
          :col_order   => ["mem_cpu__total", "host_name"],
          :headers     => ["Parent Host", "Memory (Avg)", "Memory (Total)", "OS Product Type"],
          :dims        => 1,
          :rpt_options => {:pivot => {:group_cols => ["host_name"]}},
          :graph       => {:type => "Column", :mode => "values", :column => "Vm-mem_cpu:total", :count => 10, :other => false}
      )

      report.generate_table(:userid => 'test')
      report.table = Struct.new(:data).new
      report.table.data = [
        Ruport::Data::Record.new("mem_cpu__total" => 0.0, "host_name" => "host")
      ]

      expect_any_instance_of(described_class).to receive(:build_reporting_chart_other_numeric).once.and_call_original

      ReportFormatter::ReportRenderer.render(Charting.format) do |e|
        e.options.mri           = report
        e.options.show_title    = true
        e.options.graph_options = MiqReport.graph_options(600, 400)
        e.options.theme         = 'miq'
      end

      expect(report.chart[:data][0][0]).to eq(0.0)
      expect(report.chart[:options][:axes][:xaxis][:ticks][0]).to eq(host.name)
    end
  end

  context '#build_reporting_chart_dim2_numeric' do
    it 'builds 3d numeric charts' do
      report = MiqReport.new(
          :db        => "Vm",
          :cols      => ["host_name", "mem_cpu"],
          :include   => {"operating_system"=>{"columns"=>["product_type"]}},
          :col_order => ["host_name", "operating_system.product_type", "mem_cpu__avg", "mem_cpu__max", "mem_cpu__min", "mem_cpu__total"],
          :headers   => ["Parent Host", "OS Product Type", " Memory (Avg)", " Memory (Max)", " Memory (Min)", "Memory (Total)"],
          :order      => "Ascending",
          :sortby     => ["host_name", "operating_system.product_type"],
          :graph      => {:type=>"StackedBar", :mode=>"values", :column=>"Vm-mem_cpu:total", :count=>10, :other=>true},
          :dims       => 2,
          :rpt_options => {:pivot=>{:group_cols=>["host_name", "operating_system.product_type"]}, :pdf=>{:page_size=>"US-Letter"}, :queue_timeout=>nil},
      )

      report.table = Struct.new(:data).new
      report.table.data = [
        Ruport::Data::Record.new(
          'host_name'                     => 'foobar',
          'operating_system.product_type' => 'linux',
          'mem_cpu__avg'                  => 4437,
          'mem_cpu__max'                  => 6144,
          'mem_cpu__min'                  => 1024,
          'mem_cpu__total'                => 13312
        )
      ]

      expect_any_instance_of(described_class).to receive(:build_reporting_chart_dim2_numeric).once.and_call_original

      ReportFormatter::ReportRenderer.render(Charting.format) do |e|
        e.options.mri           = report
        e.options.show_title    = true
        e.options.graph_options = MiqReport.graph_options(600, 400)
        e.options.theme         = 'miq'
      end

      expect(report.chart[:data][0][0]).to eq(13312)
      expect(report.chart[:options][:series][0][:label]).to eq('linux')
    end
  end
end
