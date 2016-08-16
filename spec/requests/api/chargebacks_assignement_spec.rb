RSpec.describe "chargebacks API" do
  it "can fetch the list of all tags of one chargeback" do
    # Build Chargeback tag
    chargeback = FactoryGirl.create(:chargeback_rate)
    tenant     = FactoryGirl.create(:tenant)
    ChargebackRate.set_assignments chargeback.rate_type, [{:cb_rate => chargeback, :object => tenant}]
    # URI of tags
    uri = "#{chargebacks_url(chargeback.id)}/tags"
    tag = chargeback.tags.first

    api_basic_authorize action_identifier(:chargebacks, :read, :resource_actions, :get)
    run_get uri, :expand => "resources"
    expect_result_to_match_hash(
      response.parsed_body,
      "name"      => "tags",
      "count"     => 1,
      "subcount"  => 1,
      "resources" => [{
        # example.com? How I can set chargeback_tags_url like chargebacks_url?
        "href" => ("http://www.example.com" + uri + "/" + tag.id.to_s),
        "id"   => tag.id,
        "name" => tag.name
      }]
    )
    expect(response).to have_http_status(:ok)
  end

  it "can assign a tag to a chargeback" do
    # Build Chargeback tag
    chargeback = FactoryGirl.create(:chargeback_rate)
    tenant     = FactoryGirl.create(:tenant)
    # URI of tags
    uri = "#{chargebacks_url(chargeback.id)}/tags"
    # Build Payload
    payload = {:action => "assign", :kind => "tenant", :c_id => tenant.id}

    api_basic_authorize action_identifier(:chargebacks, :edit)
    run_post uri, payload

    tag = chargeback.tags.first
    expect_result_to_match_hash(
      response.parsed_body,
      "results" => [{
        "tags" => [{
          "id"   => tag.id,
          "name" => "/chargeback_rate/assigned_to/tenant/id/#{tenant.id}"
        }]
      }]
    )
    expect(response).to have_http_status(:ok)
  end

  it "can unassign a chargeback tag" do
    # Build Chargeback tag
    chargeback = FactoryGirl.create(:chargeback_rate)
    tenant     = FactoryGirl.create(:tenant)
    ChargebackRate.set_assignments chargeback.rate_type, [{:cb_rate => chargeback, :object => tenant}]
    # URI of tags
    uri = "#{chargebacks_url(chargeback.id)}/tags"
    # Build Payload
    payload = {:action => "unassign", :kind => "tenant", :c_id => tenant.id}

    api_basic_authorize action_identifier(:chargebacks, :edit)
    run_post uri, payload

    expect_result_to_match_hash(
      response.parsed_body,
      "results"=> [{"tags"=> []}])
    expect(response).to have_http_status(:ok)
  end
end
