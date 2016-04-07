RSpec.describe "chargebacks API" do
  it "can fetch the list of all chargeback rates" do
    chargeback_rate = FactoryGirl.create(:chargeback_rate)

    api_basic_authorize
    run_get chargebacks_url

    expect_result_resources_to_include_hrefs(
      "resources", [chargebacks_url(chargeback_rate.id)]
    )
    expect_result_to_match_hash(response_hash, "count" => 1)
    expect_request_success
  end

  it "can show an individual chargeback rate" do
    chargeback_rate = FactoryGirl.create(:chargeback_rate)

    api_basic_authorize
    run_get chargebacks_url(chargeback_rate.id)

    expect_result_to_match_hash(
      response_hash,
      "description" => chargeback_rate.description,
      "guid"        => chargeback_rate.guid,
      "id"          => chargeback_rate.id,
      "href"        => chargebacks_url(chargeback_rate.id)
    )
    expect_request_success
  end

  it "can fetch chargeback rate details" do
    chargeback_rate_detail = FactoryGirl.build(:chargeback_rate_detail)
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
    chargeback_rate_detail = FactoryGirl.build(:chargeback_rate_detail, :description => "rate_1")
    chargeback_tier = FactoryGirl.create(:chargeback_tier, :chargeback_rate_detail_id => chargeback_rate_detail.id,
                                         :start => 0, :finish => Float::INFINITY, :fixed_rate => 0.0,
                                         :variable_rate => 0.0)
    chargeback_rate_detail.chargeback_tiers = [chargeback_tier]
    chargeback_rate = FactoryGirl.create(:chargeback_rate,
                                         :chargeback_rate_details => [chargeback_rate_detail])

    api_basic_authorize
    run_get "#{chargebacks_url(chargeback_rate.id)}/rates/#{chargeback_rate_detail.to_param}"

    expect_result_to_match_hash(
      response_hash,
      "chargeback_rate_id" => chargeback_rate.id,
      "href"               => "#{chargebacks_url(chargeback_rate.id)}/rates/#{chargeback_rate_detail.to_param}",
      "id"                 => chargeback_rate_detail.id,
      "description"        => "rate_1"
    )
    expect_request_success
  end

  context "with an appropriate role" do
    it "can create a new chargeback rate detail" do
      api_basic_authorize action_identifier(:rates, :create, :collection_actions)

      expect do
        run_post rates_url,
                 :description => "rate_0",
                 :group       => "fixed",
                 :source      => "used",
                 :enabled     => true
      end.to change(ChargebackRateDetail, :count).by(1)
      expect_result_to_match_hash(response_hash["results"].first, "description" => "rate_0", "enabled" => true)
      expect_request_success
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
      chargeback_rate_detail = FactoryGirl.build(:chargeback_rate_detail, :description => "rate_0")
      chargeback_tier = FactoryGirl.create(:chargeback_tier, :chargeback_rate_detail_id => chargeback_rate_detail.id,
                                           :start => 0, :finish => Float::INFINITY, :fixed_rate => 0.0,
                                           :variable_rate => 0.0)
      chargeback_rate_detail.chargeback_tiers = [chargeback_tier]
      chargeback_rate_detail.save

      api_basic_authorize action_identifier(:rates, :edit)
      run_post rates_url(chargeback_rate_detail.id), gen_request(:edit, :description => "rate_1")

      expect(response_hash["description"]).to eq("rate_1")
      expect_request_success
      expect(chargeback_rate_detail.reload.description).to eq("rate_1")
    end

    it "can edit a chargeback rate detail through PATCH" do
      chargeback_rate_detail = FactoryGirl.build(:chargeback_rate_detail, :description => "rate_0")
      chargeback_tier = FactoryGirl.create(:chargeback_tier, :chargeback_rate_detail_id => chargeback_rate_detail.id,
                                           :start => 0, :finish => Float::INFINITY, :fixed_rate => 0.0,
                                           :variable_rate => 0.0)
      chargeback_rate_detail.chargeback_tiers = [chargeback_tier]
      chargeback_rate_detail.save

      api_basic_authorize action_identifier(:rates, :edit)
      run_patch rates_url(chargeback_rate_detail.id), [{:action => "edit", :path => "description", :value => "rate_1"}]

      expect(response_hash["description"]).to eq("rate_1")
      expect_request_success
      expect(chargeback_rate_detail.reload.description).to eq("rate_1")
    end

    it "can delete a chargeback rate detail" do
      chargeback_rate_detail = FactoryGirl.build(:chargeback_rate_detail)
      chargeback_tier = FactoryGirl.create(:chargeback_tier, :chargeback_rate_detail_id => chargeback_rate_detail.id,
                                           :start => 0, :finish => Float::INFINITY, :fixed_rate => 0.0,
                                           :variable_rate => 0.0)
      chargeback_rate_detail.chargeback_tiers = [chargeback_tier]
      chargeback_rate_detail.save

      api_basic_authorize action_identifier(:rates, :delete)

      expect do
        run_delete rates_url(chargeback_rate_detail.id)
      end.to change(ChargebackRateDetail, :count).by(-1)
      expect_request_success_with_no_content
    end

    it "can delete a chargeback rate detail through POST" do
      chargeback_rate_detail = FactoryGirl.build(:chargeback_rate_detail)
      chargeback_tier = FactoryGirl.create(:chargeback_tier, :chargeback_rate_detail_id => chargeback_rate_detail.id,
                                           :start => 0, :finish => Float::INFINITY, :fixed_rate => 0.0,
                                           :variable_rate => 0.0)
      chargeback_rate_detail.chargeback_tiers = [chargeback_tier]
      chargeback_rate_detail.save

      api_basic_authorize action_identifier(:rates, :delete)

      expect do
        run_post rates_url(chargeback_rate_detail.id), :action => "delete"
      end.to change(ChargebackRateDetail, :count).by(-1)
      expect_request_success
    end
  end

  context "without an appropriate role" do
    it "cannot create a chargeback rate detail" do
      api_basic_authorize

      expect { run_post rates_url, :description => "rate_0", :enabled => true }.not_to change(ChargebackRateDetail,
                                                                                              :count)
      expect_request_forbidden
    end

    it "cannot edit a chargeback rate detail" do
      chargeback_rate_detail = FactoryGirl.build(:chargeback_rate_detail, :description => "rate_1")
      chargeback_tier = FactoryGirl.create(:chargeback_tier, :chargeback_rate_detail_id => chargeback_rate_detail.id,
                                           :start => 0, :finish => Float::INFINITY, :fixed_rate => 0.0,
                                           :variable_rate => 0.0)
      chargeback_rate_detail.chargeback_tiers = [chargeback_tier]
      chargeback_rate_detail.save

      api_basic_authorize

      expect do
        run_post rates_url(chargeback_rate_detail.id), gen_request(:edit, :description => "rate_2")
      end.not_to change { chargeback_rate_detail.reload.description }
      expect_request_forbidden
    end

    it "cannot delete a chargeback rate detail" do
      chargeback_rate_detail = FactoryGirl.build(:chargeback_rate_detail)
      chargeback_tier = FactoryGirl.create(:chargeback_tier, :chargeback_rate_detail_id => chargeback_rate_detail.id,
                                           :start => 0, :finish => Float::INFINITY, :fixed_rate => 0.0,
                                           :variable_rate => 0.0)
      chargeback_rate_detail.chargeback_tiers = [chargeback_tier]
      chargeback_rate_detail.save

      api_basic_authorize

      expect do
        run_delete rates_url(chargeback_rate_detail.id)
      end.not_to change(ChargebackRateDetail, :count)
      expect_request_forbidden
    end
  end
end
