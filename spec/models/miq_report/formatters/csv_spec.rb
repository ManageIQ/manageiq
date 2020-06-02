RSpec.describe MiqReport::Formatters::Csv do
  describe "#to_csv" do
    let(:col_options) { nil }
    let(:table_data) do
      [{"id" => 5, "name" => "vmware", "base_name" => "XXX", "file_version" => "11", "size" => "33", "contents_available" => true, "permissions" => nil, "updated_on" => nil, "mtime" => nil},
       {"id" => 1, "name" => "vmware1", "base_name" => "YYY", "file_version" => "22", "size" => "44", "contents_available" => true, "permissions" => nil, "updated_on" => nil, "mtime" => nil}]
    end

    let(:miq_report_filesystem) do
      FactoryBot.create(:miq_report_filesystem).tap do |report|
        report.table = Ruport::Data::Table.new(:data => table_data, :column_names => report.cols)
        report.col_options = col_options
        report
      end
    end

    let(:csv_output) do
      <<~CSV
        "Name","File Name","File Version","Size","Contents Available","Permissions","Collected On","Last Modified"
        vmware,XXX,11,33,true,,,
        vmware1,YYY,22,44,true,,,
      CSV
    end

    it "generates csv report" do
      expect(miq_report_filesystem.to_csv).to eq(csv_output)
    end

    context "hidden columns" do
      let(:col_options) do
        { 'name' => {:hidden => true}, 'file_version' => {:hidden => true} }
      end

      let(:csv_output) do
        <<~CSV
          "File Name","Size","Contents Available","Permissions","Collected On","Last Modified"
          XXX,33,true,,,
          YYY,44,true,,,
        CSV
      end

      it "hides columns in csv report" do
        expect(miq_report_filesystem.to_csv).to eq(csv_output)
      end
    end
  end
end
