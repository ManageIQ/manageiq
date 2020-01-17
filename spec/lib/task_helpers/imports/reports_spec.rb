RSpec.describe TaskHelpers::Imports::Reports do
  describe "#import" do
    let(:data_dir) { File.join(File.expand_path(__dir__), 'data', 'reports') }
    let(:rpt_file1) { "Test_Report.yaml" }
    let(:rpt_file2) { "Test_Report_-_Chargeback.yaml" }
    let(:rpt_name1) { "Test Report" }
    let(:rpt_name2) { "Test Report - Chargeback" }
    let(:rpt_title1) { "Test Report for Exporting" }
    let(:rpt_title2) { "Test Chargeback Report" }
    let(:rpt_db1) { "Vm" }
    let(:rpt_db2) { "ChargebackVm" }
    let(:attr_err_file) { "Test_Report_attr_error.yml" }
    let(:runt_err_file) { "Test_Report_runtime_error.yml" }
    let(:options) { { :source => source, :overwrite => overwrite } }

    before do
      FactoryBot.create(:user_admin, :userid => "admin")
    end

    describe "when the source is a directory" do
      let(:source) { data_dir }
      let(:overwrite) { true }

      it 'imports all .yaml files in a specified directory' do
        expect do
          TaskHelpers::Imports::Reports.new.import(options)
        end.to_not output.to_stderr
        expect(MiqReport.all.count).to eq(2)
        assert_test_rpt_one_present
        assert_test_rpt_two_present
      end
    end

    describe "when the source is a file" do
      let(:source) { "#{data_dir}/#{rpt_file1}" }
      let(:overwrite) { true }

      it 'imports a specified file' do
        expect do
          TaskHelpers::Imports::Reports.new.import(options)
        end.to_not output.to_stderr
        expect(MiqReport.all.count).to eq(1)
        assert_test_rpt_one_present
      end
    end

    describe "when the source file modifies an existing report" do
      let(:update_file) { "Test_Report_update.yml" }
      let(:source) { "#{data_dir}/#{update_file}" }

      before do
        TaskHelpers::Imports::Reports.new.import(:source => "#{data_dir}/#{rpt_file1}")
      end

      context 'overwrite is true' do
        let(:overwrite) { true }

        it 'overwrites an existing report' do
          expect do
            TaskHelpers::Imports::Reports.new.import(options)
          end.to_not output.to_stderr
          assert_test_rpt_one_modified
        end
      end

      context 'overwrite is false' do
        let(:overwrite) { false }

        it 'does not overwrite an existing report' do
          expect do
            TaskHelpers::Imports::Reports.new.import(options)
          end.to_not output.to_stderr
          assert_test_rpt_one_present
        end
      end
    end

    describe "when the source file has invalid settings" do
      let(:overwrite) { true }

      context "when the object type is invalid" do
        let(:source) { "#{data_dir}/#{runt_err_file}" }

        it 'generates an error' do
          expect do
            TaskHelpers::Imports::Reports.new.import(options)
          end.to output(/Incorrect format/).to_stderr
        end
      end

      context "when an attribute is invalid" do
        let(:source) { "#{data_dir}/#{attr_err_file}" }

        it 'generates an error' do
          expect do
            TaskHelpers::Imports::Reports.new.import(options)
          end.to output(/unknown attribute 'invalid_title'/).to_stderr
        end
      end
    end
  end

  def assert_test_rpt_one_present
    report = MiqReport.find_by(:name => rpt_name1)
    expect(report.title).to eq(rpt_title1)
    expect(report.db).to eq(rpt_db1)
    expect(report.cols).to_not include("active")
  end

  def assert_test_rpt_two_present
    report = MiqReport.find_by(:name => rpt_name2)
    expect(report.title).to eq(rpt_title2)
    expect(report.db).to eq(rpt_db2)
  end

  def assert_test_rpt_one_modified
    report = MiqReport.find_by(:name => rpt_name1)
    expect(report.title).to include("Modified")
    expect(report.cols).to include("active")
  end
end
