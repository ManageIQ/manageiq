require "spec_helper"

RSpec.describe "reports API" do
  include Rack::Test::Methods

  def app
    Vmdb::Application
  end

  before { init_api_spec_env }

  it "can fetch all the reports" do
    report_1 = FactoryGirl.create(:miq_report_with_results)
    report_2 = FactoryGirl.create(:miq_report_with_results)

    api_basic_authorize
    run_get reports_url

    expect_result_resources_to_include_hrefs(
      "resources",
      [
        reports_url(report_1.id),
        reports_url(report_2.id)
      ]
    )
    expect_result_to_match_hash(@result, "count" => 2, "name" => "reports")
    expect_request_success
  end

  it "can fetch a report" do
    report = FactoryGirl.create(:miq_report_with_results)

    api_basic_authorize
    run_get reports_url(report.id)

    expect_result_to_match_hash(
      @result,
      "href"  => reports_url(report.id),
      "id"    => report.id,
      "name"  => report.name,
      "title" => report.title
    )
    expect_request_success
  end

  it "can fetch a report's results" do
    report = FactoryGirl.create(:miq_report_with_results)
    result = report.miq_report_results.first

    api_basic_authorize
    run_get "#{reports_url(report.id)}/results"

    expect_result_resources_to_include_hrefs(
      "resources",
      [
        "#{reports_url(report.id)}/results/#{result.to_param}"
      ]
    )
    expect(@result["resources"]).not_to be_any { |resource| resource.key?("result_set") }
    expect_request_success
  end

  it "can fetch a report's result" do
    report = FactoryGirl.create(:miq_report_with_results)
    result = report.miq_report_results.first
    table = Ruport::Data::Table.new(
      :column_names => %w(foo),
      :data         => [%w(bar), %w(baz)]
    )
    allow(report).to receive(:table).and_return(table)
    allow_any_instance_of(MiqReportResult).to receive(:report_results).and_return(report) # ughhhh

    api_basic_authorize
    run_get "#{reports_url(report.id)}/results/#{result.to_param}"

    expect_result_to_match_hash(@result, "result_set" => [{"foo" => "bar"}, {"foo" => "baz"}])
    expect_request_success
  end
end
