RSpec.describe "chargebacks API" do
  let(:field) { FactoryGirl.create(:chargeable_field) }

  it "can fetch the list of all chargeback rates" do
    chargeback_rate = FactoryGirl.create(:chargeback_rate)

    api_basic_authorize collection_action_identifier(:chargebacks, :read, :get)
    run_get chargebacks_url

    expect_result_resources_to_include_hrefs(
      "resources", [chargebacks_url(chargeback_rate.id)]
    )
    expect_result_to_match_hash(response.parsed_body, "count" => 1)
    expect(response).to have_http_status(:ok)
  end

  it "can show an individual chargeback rate" do
    chargeback_rate = FactoryGirl.create(:chargeback_rate)

    api_basic_authorize action_identifier(:chargebacks, :read, :resource_actions, :get)
    run_get chargebacks_url(chargeback_rate.id)

    expect_result_to_match_hash(
      response.parsed_body,
      "description" => chargeback_rate.description,
      "guid"        => chargeback_rate.guid,
      "id"          => chargeback_rate.id,
      "href"        => chargebacks_url(chargeback_rate.id)
    )
    expect(response).to have_http_status(:ok)
  end

  it "can fetch chargeback rate details" do
    chargeback_rate_detail = FactoryGirl.build(:chargeback_rate_detail, :chargeable_field => field)
    chargeback_tier = FactoryGirl.create(:chargeback_tier, :chargeback_rate_detail_id => chargeback_rate_detail.id,
                                         :start => 0, :finish => Float::INFINITY, :fixed_rate => 0.0,
                                         :variable_rate => 0.0)
    chargeback_rate_detail.chargeback_tiers = [chargeback_tier]
    chargeback_rate = FactoryGirl.create(:chargeback_rate,
                                         :chargeback_rate_details => [chargeback_rate_detail])

    api_basic_authorize
    run_get "#{chargebacks_url(chargeback_rate.id)}/rates"

    expect_query_result(:rates, 1, 1)
    expect_result_resources_to_include_hrefs(
      "resources",
      ["#{chargebacks_url(chargeback_rate.id)}/rates/#{chargeback_rate_detail.to_param}"]
    )
  end

  it "can fetch an individual chargeback rate detail" do
    chargeback_rate_detail = FactoryGirl.build(:chargeback_rate_detail, :description => "rate_1", :chargeable_field => field)
    chargeback_tier = FactoryGirl.create(:chargeback_tier, :chargeback_rate_detail_id => chargeback_rate_detail.id,
                                         :start => 0, :finish => Float::INFINITY, :fixed_rate => 0.0,
                                         :variable_rate => 0.0)
    chargeback_rate_detail.chargeback_tiers = [chargeback_tier]
    chargeback_rate = FactoryGirl.create(:chargeback_rate,
                                         :chargeback_rate_details => [chargeback_rate_detail])

    api_basic_authorize
    run_get "#{chargebacks_url(chargeback_rate.id)}/rates/#{chargeback_rate_detail.to_param}"

    expect_result_to_match_hash(
      response.parsed_body,
      "chargeback_rate_id" => chargeback_rate.id,
      "href"               => "#{chargebacks_url(chargeback_rate.id)}/rates/#{chargeback_rate_detail.to_param}",
      "id"                 => chargeback_rate_detail.id,
      "description"        => "rate_1"
    )
    expect(response).to have_http_status(:ok)
  end

  it "can list of all currencies" do
    currency = FactoryGirl.create(:chargeback_rate_detail_currency)

    api_basic_authorize
    run_get '/api/currencies'

    expect_result_resources_to_include_hrefs(
      "resources", ["/api/currencies/#{currency.id}"]
    )
    expect_result_to_match_hash(response.parsed_body, "count" => 1)
    expect(response).to have_http_status(:ok)
  end

  it "can show an individual currency" do
    currency = FactoryGirl.create(:chargeback_rate_detail_currency)

    api_basic_authorize
    run_get "/api/currencies/#{currency.id}"

    expect_result_to_match_hash(
      response.parsed_body,
      "name" => currency.name,
      "id"   => currency.id,
      "href" => "/api/currencies/#{currency.id}"
    )
    expect(response).to have_http_status(:ok)
  end

  it "can list of all measures" do
    measure = FactoryGirl.create(:chargeback_rate_detail_measure)

    api_basic_authorize
    run_get '/api/measures'

    expect_result_resources_to_include_hrefs(
      "resources", ["/api/measures/#{measure.id}"]
    )
    expect_result_to_match_hash(response.parsed_body, "count" => 1)
    expect(response).to have_http_status(:ok)
  end

  it "can show an individual measure" do
    measure = FactoryGirl.create(:chargeback_rate_detail_measure)

    api_basic_authorize
    run_get "/api/measures/#{measure.id}"

    expect_result_to_match_hash(
      response.parsed_body,
      "name" => measure.name,
      "id"   => measure.id,
      "href" => "/api/measures/#{measure.id}",
    )
    expect(response).to have_http_status(:ok)
  end

  context "with an appropriate role" do
    it "can create a new chargeback rate" do
      api_basic_authorize action_identifier(:chargebacks, :create, :collection_actions)

      expect do
        run_post chargebacks_url,
                 :description => "chargeback_0",
                 :rate_type   => "Storage"
      end.to change(ChargebackRate, :count).by(1)
      expect_result_to_match_hash(response.parsed_body["results"].first, "description" => "chargeback_0",
                                                                         "rate_type"   => "Storage",
                                                                         "default"     => false)
      expect(response).to have_http_status(:ok)
    end

    it "returns bad request for incomplete chargeback rate" do
      api_basic_authorize action_identifier(:chargebacks, :create, :collection_actions)

      expect do
        run_post chargebacks_url,
                 :rate_type   => "Storage"
      end.not_to change(ChargebackRate, :count)
      expect_bad_request(/description can't be blank/i)
    end

    it "can edit a chargeback rate through POST" do
      chargeback_rate = FactoryGirl.create(:chargeback_rate, :description => "chargeback_0")

      api_basic_authorize action_identifier(:chargebacks, :edit)
      run_post chargebacks_url(chargeback_rate.id), gen_request(:edit, :description => "chargeback_1")

      expect(response.parsed_body["description"]).to eq("chargeback_1")
      expect(response).to have_http_status(:ok)
      expect(chargeback_rate.reload.description).to eq("chargeback_1")
    end

    it "can edit a chargeback rate through PATCH" do
      chargeback_rate = FactoryGirl.create(:chargeback_rate, :description => "chargeback_0")

      api_basic_authorize action_identifier(:chargebacks, :edit)
      run_patch chargebacks_url(chargeback_rate.id), [{:action => "edit",
                                                       :path   => "description",
                                                       :value  => "chargeback_1"}]

      expect(response.parsed_body["description"]).to eq("chargeback_1")
      expect(response).to have_http_status(:ok)
      expect(chargeback_rate.reload.description).to eq("chargeback_1")
    end

    it "can delete a chargeback rate" do
      chargeback_rate = FactoryGirl.create(:chargeback_rate)

      api_basic_authorize action_identifier(:chargebacks, :delete)

      expect do
        run_delete chargebacks_url(chargeback_rate.id)
      end.to change(ChargebackRate, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end

    it "can delete a chargeback rate through POST" do
      chargeback_rate = FactoryGirl.create(:chargeback_rate)

      api_basic_authorize action_identifier(:chargebacks, :delete)

      expect do
        run_post chargebacks_url(chargeback_rate.id), :action => "delete"
      end.to change(ChargebackRate, :count).by(-1)
      expect(response).to have_http_status(:ok)
    end

    it "can create a new chargeback rate detail" do
      api_basic_authorize action_identifier(:rates, :create, :collection_actions)
      chargeback_rate = FactoryGirl.create(:chargeback_rate)

      expect do
        run_post rates_url,
                 :description         => "rate_0",
                 :group               => "fixed",
                 :chargeback_rate_id  => chargeback_rate.id,
                 :chargeable_field_id => field.id,
                 :source              => "used",
                 :enabled             => true
      end.to change(ChargebackRateDetail, :count).by(1)
      expect_result_to_match_hash(response.parsed_body["results"].first, "description" => "rate_0", "enabled" => true)
      expect(response).to have_http_status(:ok)
    end

    it "returns bad request for incomplete chargeback rate detail" do
      api_basic_authorize action_identifier(:rates, :create, :collection_actions)

      expect do
        run_post rates_url,
                 :description => "rate_0",
                 :enabled     => true
      end.not_to change(ChargebackRateDetail, :count)
      expect_bad_request(/group can't be blank/i)
      expect_bad_request(/source can't be blank/i)
    end

    it "can edit a chargeback rate detail through POST" do
      chargeback_rate_detail = FactoryGirl.build(:chargeback_rate_detail, :description => "rate_0", :chargeable_field => field)
      chargeback_tier = FactoryGirl.create(:chargeback_tier, :chargeback_rate_detail_id => chargeback_rate_detail.id,
                                           :start => 0, :finish => Float::INFINITY, :fixed_rate => 0.0,
                                           :variable_rate => 0.0)
      chargeback_rate_detail.chargeback_tiers = [chargeback_tier]
      chargeback_rate_detail.save

      api_basic_authorize action_identifier(:rates, :edit)
      run_post rates_url(chargeback_rate_detail.id), gen_request(:edit, :description => "rate_1")

      expect(response.parsed_body["description"]).to eq("rate_1")
      expect(response).to have_http_status(:ok)
      expect(chargeback_rate_detail.reload.description).to eq("rate_1")
    end

    it "can edit a chargeback rate detail through PATCH" do
      chargeback_rate_detail = FactoryGirl.build(:chargeback_rate_detail, :description => "rate_0", :chargeable_field => field)
      chargeback_tier = FactoryGirl.create(:chargeback_tier, :chargeback_rate_detail_id => chargeback_rate_detail.id,
                                           :start => 0, :finish => Float::INFINITY, :fixed_rate => 0.0,
                                           :variable_rate => 0.0)
      chargeback_rate_detail.chargeback_tiers = [chargeback_tier]
      chargeback_rate_detail.save

      api_basic_authorize action_identifier(:rates, :edit)
      run_patch rates_url(chargeback_rate_detail.id), [{:action => "edit", :path => "description", :value => "rate_1"}]

      expect(response.parsed_body["description"]).to eq("rate_1")
      expect(response).to have_http_status(:ok)
      expect(chargeback_rate_detail.reload.description).to eq("rate_1")
    end

    it "can delete a chargeback rate detail" do
      chargeback_rate_detail = FactoryGirl.build(:chargeback_rate_detail, :chargeable_field => field)
      chargeback_tier = FactoryGirl.create(:chargeback_tier, :chargeback_rate_detail_id => chargeback_rate_detail.id,
                                           :start => 0, :finish => Float::INFINITY, :fixed_rate => 0.0,
                                           :variable_rate => 0.0)
      chargeback_rate_detail.chargeback_tiers = [chargeback_tier]
      chargeback_rate_detail.save

      api_basic_authorize action_identifier(:rates, :delete)

      expect do
        run_delete rates_url(chargeback_rate_detail.id)
      end.to change(ChargebackRateDetail, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end

    it "can delete a chargeback rate detail through POST" do
      chargeback_rate_detail = FactoryGirl.build(:chargeback_rate_detail, :chargeable_field => field)
      chargeback_tier = FactoryGirl.create(:chargeback_tier, :chargeback_rate_detail_id => chargeback_rate_detail.id,
                                           :start => 0, :finish => Float::INFINITY, :fixed_rate => 0.0,
                                           :variable_rate => 0.0)
      chargeback_rate_detail.chargeback_tiers = [chargeback_tier]
      chargeback_rate_detail.save

      api_basic_authorize action_identifier(:rates, :delete)

      expect do
        run_post rates_url(chargeback_rate_detail.id), :action => "delete"
      end.to change(ChargebackRateDetail, :count).by(-1)
      expect(response).to have_http_status(:ok)
    end
  end

  context "without an appropriate role" do
    it "cannot create a chargeback rate" do
      api_basic_authorize

      expect { run_post chargebacks_url, :description => "chargeback_0" }.not_to change(ChargebackRate,
                                                                                        :count)
      expect(response).to have_http_status(:forbidden)
    end

    it "cannot edit a chargeback rate" do
      chargeback_rate = FactoryGirl.create(:chargeback_rate, :description => "chargeback_0")

      api_basic_authorize

      expect do
        run_post chargebacks_url(chargeback_rate.id), gen_request(:edit, :description => "chargeback_1")
      end.not_to change { chargeback_rate.reload.description }
      expect(response).to have_http_status(:forbidden)
    end

    it "cannot delete a chargeback rate" do
      chargeback_rate = FactoryGirl.create(:chargeback_rate)

      api_basic_authorize

      expect do
        run_delete chargebacks_url(chargeback_rate.id)
      end.not_to change(ChargebackRate, :count)
      expect(response).to have_http_status(:forbidden)
    end

    it "cannot create a chargeback rate detail" do
      api_basic_authorize

      expect { run_post rates_url, :description => "rate_0", :enabled => true }.not_to change(ChargebackRateDetail,
                                                                                              :count)
      expect(response).to have_http_status(:forbidden)
    end

    it "cannot edit a chargeback rate detail" do
      chargeback_rate_detail = FactoryGirl.build(:chargeback_rate_detail, :description => "rate_1", :chargeable_field => field)
      chargeback_tier = FactoryGirl.create(:chargeback_tier, :chargeback_rate_detail_id => chargeback_rate_detail.id,
                                           :start => 0, :finish => Float::INFINITY, :fixed_rate => 0.0,
                                           :variable_rate => 0.0)
      chargeback_rate_detail.chargeback_tiers = [chargeback_tier]
      chargeback_rate_detail.save

      api_basic_authorize

      expect do
        run_post rates_url(chargeback_rate_detail.id), gen_request(:edit, :description => "rate_2")
      end.not_to change { chargeback_rate_detail.reload.description }
      expect(response).to have_http_status(:forbidden)
    end

    it "cannot delete a chargeback rate detail" do
      chargeback_rate_detail = FactoryGirl.build(:chargeback_rate_detail, :chargeable_field => field)
      chargeback_tier = FactoryGirl.create(:chargeback_tier, :chargeback_rate_detail_id => chargeback_rate_detail.id,
                                           :start => 0, :finish => Float::INFINITY, :fixed_rate => 0.0,
                                           :variable_rate => 0.0)
      chargeback_rate_detail.chargeback_tiers = [chargeback_tier]
      chargeback_rate_detail.save

      api_basic_authorize

      expect do
        run_delete rates_url(chargeback_rate_detail.id)
      end.not_to change(ChargebackRateDetail, :count)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
