RSpec.describe "reports API" do
  it "can fetch all the reports" do
    report_1 = FactoryGirl.create(:miq_report_with_results)
    report_2 = FactoryGirl.create(:miq_report_with_results)

    api_basic_authorize collection_action_identifier(:reports, :read, :get)
    run_get reports_url

    expect_result_resources_to_include_hrefs(
      "resources",
      [
        reports_url(report_1.id),
        reports_url(report_2.id)
      ]
    )
    expect_result_to_match_hash(response_hash, "count" => 2, "name" => "reports")
    expect_request_success
  end

  it "can fetch a report" do
    report = FactoryGirl.create(:miq_report_with_results)

    api_basic_authorize action_identifier(:reports, :read, :resource_actions, :get)
    run_get reports_url(report.id)

    expect_result_to_match_hash(
      response_hash,
      "href"  => reports_url(report.id),
      "id"    => report.id,
      "name"  => report.name,
      "title" => report.title
    )
    expect_request_success
  end

  it "can fetch a report's results" do
    report = FactoryGirl.create(:miq_report_with_results)
    report_result = report.miq_report_results.first

    api_basic_authorize
    run_get "#{reports_url(report.id)}/results"

    expect_result_resources_to_include_hrefs(
      "resources",
      [
        "#{reports_url(report.id)}/results/#{report_result.to_param}"
      ]
    )
    expect(response_hash["resources"]).not_to be_any { |resource| resource.key?("result_set") }
    expect_request_success
  end

  it "can fetch a report's result" do
    report = FactoryGirl.create(:miq_report_with_results)
    report_result = report.miq_report_results.first
    table = Ruport::Data::Table.new(
      :column_names => %w(foo),
      :data         => [%w(bar), %w(baz)]
    )
    allow(report).to receive(:table).and_return(table)
    allow_any_instance_of(MiqReportResult).to receive(:report_results).and_return(report)

    api_basic_authorize
    run_get "#{reports_url(report.id)}/results/#{report_result.to_param}"

    expect_result_to_match_hash(response_hash, "result_set" => [{"foo" => "bar"}, {"foo" => "baz"}])
    expect_request_success
  end

  it "can fetch all the results" do
    report = FactoryGirl.create(:miq_report_with_results)
    result = report.miq_report_results.first

    api_basic_authorize
    run_get results_url

    expect_result_resources_to_include_hrefs(
      "resources",
      [
        "#{results_url(result.id)}"
      ]
    )
    expect_request_success
  end

  it "can fetch a specific result as a primary collection" do
    report = FactoryGirl.create(:miq_report_with_results)
    report_result = report.miq_report_results.first
    table = Ruport::Data::Table.new(
      :column_names => %w(foo),
      :data         => [%w(bar), %w(baz)]
    )
    allow(report).to receive(:table).and_return(table)
    allow_any_instance_of(MiqReportResult).to receive(:report_results).and_return(report)

    api_basic_authorize
    run_get results_url(report_result.id)

    expect_result_to_match_hash(response_hash, "result_set" => [{"foo" => "bar"}, {"foo" => "baz"}])
    expect_request_success
  end

  it "returns an empty result set if none has been run" do
    report = FactoryGirl.create(:miq_report_with_results)
    report_result = report.miq_report_results.first

    api_basic_authorize
    run_get "#{reports_url(report.id)}/results/#{report_result.id}"

    expect_result_to_match_hash(response_hash, "result_set" => [])
    expect_request_success
  end

  context "with an appropriate role" do
    it "can run a report" do
      report = FactoryGirl.create(:miq_report)

      expect do
        api_basic_authorize action_identifier(:reports, :run)
        run_post "#{reports_url(report.id)}", :action => "run"
      end.to change(MiqReportResult, :count).by(1)
      expect_single_action_result(
        :href    => reports_url(report.id),
        :success => true,
        :message => "running report #{report.id}"
      )
    end

    it "can import a report" do
      serialized_report = {
        :menu_name => "Test Report",
        :col_order => %w(foo bar baz),
        :cols      => %w(foo bar baz),
        :rpt_type  => "Custom",
        :title     => "Test Report",
        :db        => "My::Db",
        :rpt_group => "Custom"
      }
      options = {:save => true}

      api_basic_authorize collection_action_identifier(:reports, :import)

      expect do
        run_post reports_url, gen_request(:import, :report => serialized_report, :options => options)
      end.to change(MiqReport, :count).by(1)
      expect_result_to_match_hash(
        response_hash["results"].first["result"],
        "name"      => "Test Report",
        "title"     => "Test Report",
        "rpt_group" => "Custom",
        "rpt_type"  => "Custom",
        "db"        => "My::Db",
        "cols"      => %w(foo bar baz),
        "col_order" => %w(foo bar baz),
      )
      expect_result_to_match_hash(
        response_hash["results"].first,
        "message" => "Imported Report: [Test Report]",
        "success" => true
      )
      expect_request_success
    end

    it "can import multiple reports in a single call" do
      serialized_report = {
        :menu_name => "Test Report",
        :col_order => %w(foo bar baz),
        :cols      => %w(foo bar baz),
        :rpt_type  => "Custom",
        :title     => "Test Report",
        :db        => "My::Db",
        :rpt_group => "Custom"
      }
      serialized_report2 = {
        :menu_name => "Test Report 2",
        :col_order => %w(qux quux corge),
        :cols      => %w(qux quux corge),
        :rpt_type  => "Custom",
        :title     => "Test Report 2",
        :db        => "My::Db",
        :rpt_group => "Custom"
      }
      options = {:save => true}

      api_basic_authorize collection_action_identifier(:reports, :import)

      expect do
        run_post(
          reports_url,
          gen_request(
            :import,
            [{:report => serialized_report, :options => options},
             {:report => serialized_report2, :options => options}]
          )
        )
      end.to change(MiqReport, :count).by(2)
    end
  end

  context "without an appropriate role" do
    it "cannot run a report" do
      report = FactoryGirl.create(:miq_report)

      expect do
        api_basic_authorize
        run_post "#{reports_url(report.id)}", :action => "run"
      end.not_to change(MiqReportResult, :count)
      expect_request_forbidden
    end

    it "cannot import a report" do
      serialized_report = {
        :menu_name => "Test Report",
        :col_order => %w(foo bar baz),
        :cols      => %w(foo bar baz),
        :rpt_type  => "Custom",
        :title     => "Test Report",
        :db        => "My::Db",
        :rpt_group => "Custom"
      }
      options = {:save => true}

      api_basic_authorize

      expect do
        run_post reports_url, gen_request(:import, :report => serialized_report, :options => options)
      end.not_to change(MiqReport, :count)
      expect_request_forbidden
    end
  end
end
