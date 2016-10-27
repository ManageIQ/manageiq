RSpec.describe "API entrypoint" do
  it "returns a :settings hash" do
    api_basic_authorize

    run_get entrypoint_url

    expect(response).to have_http_status(:ok)
    expect_result_to_have_keys(%w(settings))
    expect(response.parsed_body['settings']).to be_kind_of(Hash)
  end

  it "returns a locale" do
    api_basic_authorize

    run_get entrypoint_url

    expect(%w(en en_US)).to include(response.parsed_body['settings']['locale'])
  end

  it "returns users's settings" do
    api_basic_authorize

    test_settings = {:cartoons => {:saturday => {:tom_jerry => 'n', :bugs_bunny => 'y'}}}
    @user.update_attributes!(:settings => test_settings)

    run_get entrypoint_url

    expect(response.parsed_body).to include("settings" => a_hash_including(test_settings.deep_stringify_keys))
  end

  it "collection query is sorted" do
    api_basic_authorize

    run_get entrypoint_url

    collection_names = response.parsed_body['collections'].map { |c| c['name'] }
    expect(collection_names).to eq(collection_names.sort)
  end

  it "returns server_info" do
    api_basic_authorize

    run_get entrypoint_url

    expect(response.parsed_body).to include(
      "server_info" => a_hash_including(
        "version"   => Vmdb::Appliance.VERSION,
        "build"     => Vmdb::Appliance.BUILD,
        "appliance" => MiqServer.my_server.name
      )
    )
  end

  it "returns product_info" do
    api_basic_authorize

    run_get entrypoint_url

    expect(response.parsed_body).to include(
      "product_info" => a_hash_including(
        "name"                 => I18n.t("product.name"),
        "name_full"            => I18n.t("product.name_full"),
        "copyright"            => I18n.t("product.copyright"),
        "support_website"      => I18n.t("product.support_website"),
        "support_website_text" => I18n.t("product.support_website_text"),
      )
    )
  end
end
