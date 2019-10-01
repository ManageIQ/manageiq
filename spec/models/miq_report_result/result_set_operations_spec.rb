describe MiqReportResult::ResultSetOperations do
  describe ".result_set_for_reporting" do
    let(:result_set_options_base) { {'limit' => '1000'} }

    let(:user) { FactoryBot.create(:user_with_group) }

    let(:result_set) do
      [{"name" => "TEST_VM2", "size" => 115_533, "type" => 'small'},
       {"name" => "TEST_VM1", "size" => 332_233, "type" => 'large'},
       {"name" => "PROD_VM1", "size" => 112_233, "type" => 'large'}]
    end

    let(:report_result) { FactoryBot.create(:miq_report_result, :miq_group => user.current_group) }
    let(:columns) { %w[name size type] }

    let(:col_formats) { Array.new(columns.count) }

    let!(:report) do
      FactoryBot.create(:miq_report, :miq_group => user.current_group, :miq_report_results => [report_result],
                        :col_order => columns, :col_formats => col_formats)
    end

    before do
      allow(report_result).to receive(:result_set).and_return(result_set)
      User.current_user = user
    end

    subject { report_result.result_set_for_reporting(result_set_options) }

    let(:expected_result_set) do
      [{"name" => "TEST_VM2", "size" => "112.8 KB", "type" => 'small'},
       {"name" => "TEST_VM1", "size" => "324.4 KB", "type" => 'large'}]
    end

    let(:result_set_options) { result_set_options_base.merge(:filter_column => 'name', :filter_string => 'TEST') }

    it "filters with one column" do
      expect(subject[:result_set]).to match_array(expected_result_set)
    end

    context "with more columns" do
      let(:expected_result_set) do
        [{"name" => "TEST_VM2", "size" => "112.8 KB", "type" => 'small'}]
      end

      let(:result_set_options) do
        result_set_options_base.merge(:filter_column => 'name', :filter_string => 'TEST', :filter_column_1 => 'type', :filter_string_1 => 'small')
      end

      it "filters" do
        expect(subject[:result_set]).to match_array(expected_result_set)
      end

      context "with various order of parameters" do
        let(:result_set_options) do
          result_set_options_base.merge(:filter_column_2 => 'type', :filter_string_1 => 'TEST', :filter_column_1 => 'name', :filter_string_2 => 'small')
        end

        it "filters" do
          expect(subject[:result_set]).to match_array(expected_result_set)
        end
      end
    end

    context "parameter filter_stringXX is missing and filter_columnXX is specified" do
      let(:result_set_options) do
        result_set_options_base.merge(:filter_column_2 => 'type', :filter_string_1 => 'TEST', :filter_column_1 => 'name')
      end

      it "raises error when " do
        expect { subject }.to raise_error(ArgumentError, "Value for column type (filter_column_2 parameter) is missing, please specify filter_string_2 parameter")
      end
    end
  end
end
