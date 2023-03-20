RSpec.describe MiqReport::Formatters::Graph do
  describe '#to_chart' do
    let(:table_data1) do
      [{"id" => 102, "name" => "region2", "created_on" => "2023-03-15 10:11:12.000000", "size" => 3_333_333},
       {"id" => 101, "name" => "region1", "created_on" => "2023-03-15 01:23:45.000000", "size" => 44_444_444},
       {"id" => 103, "name" => "region3", "created_on" => "2023-03-15 12:34:56.000000", "size" => 555_555_555}]
    end
    let(:table_data2) do
      [{"id" => 201, "name" => "region1", "created_on" => "2023-03-15 10:11:12.000000", "size" => 1_111_111},
       {"id" => 202, "name" => "region2", "created_on" => "2023-03-15 12:34:56.000000", "size" => 222_222}]
    end
    let(:table_data3) do
      [{"id" => 301, "name" => "region1", "created_on" => "2023-03-15 10:11:12.000000", "size" => 11_111_111},
       {"id" => 302, "name" => "region2", "created_on" => "2023-03-15 12:34:56.000000", "size" => 222_222}]
    end
    let(:col_names) do
      ["name", "size", "created_on"]
    end
    let(:col_formats) do
      [nil, :megabytes_human, :date]
    end
    let(:miq_report) do
      FactoryBot.create(:miq_report).tap do |report|
        report.col_formats = col_formats
        report.col_order = col_names
        report.sortby = ["size"]
        report.order = "Descending"
        report.graph = {:type => 'Donut', :mode => "values", :column => "CloudVolume-size", :count => 10, :other => true}
      end
    end

    it "finds the right unit and humanizes data that are in similar range" do
      miq_report.table = Ruport::Data::Table.new(:data => table_data1, :column_names => col_names)
      miq_report.to_chart(nil, true, MiqReport.graph_options({}))
      chart = miq_report.chart

      expect(chart[:data][:columns][0][1]).to eq(529) # 555555555/1024/1024
      expect(chart[:data][:columns][1][1]).to eq(42)  #  44444444/1024/1024
    end

    it "finds the right unit and humanizes data with smaller unit" do
      miq_report.table = Ruport::Data::Table.new(:data => table_data2, :column_names => col_names)
      miq_report.to_chart(nil, true, MiqReport.graph_options({}))
      chart = miq_report.chart

      expect(chart[:data][:columns][0][1]).to eq(1085) # 1111111/1024
      expect(chart[:data][:columns][1][1]).to eq(217)  #  222222/1024
    end

    it "finds the right unit and humanizes data with bigger unit" do
      miq_report.table = Ruport::Data::Table.new(:data => table_data3, :column_names => col_names)
      miq_report.to_chart(nil, true, MiqReport.graph_options({}))
      chart = miq_report.chart

      expect(chart[:data][:columns][0][1]).to eq(10) # 11111111/1024/1024
      expect(chart[:data][:columns][1][1]).to eq(0)  #   222222/1024/1024
    end
  end
end
