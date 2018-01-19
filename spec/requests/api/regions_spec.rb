#
# REST API Request Tests - Regions
#
# Regions primary collections:
#   /api/regions
#
# Tests for:
# GET /api/regions/:id
#

describe "Regions API" do
  it "forbids access to regions without an appropriate role" do
    api_basic_authorize

    run_get(regions_url)

    expect(response).to have_http_status(:forbidden)
  end

  it "forbids access to a region resource without an appropriate role" do
    api_basic_authorize

    region = FactoryGirl.create(:miq_region, :region => "2")

    run_get(regions_url(region.id))

    expect(response).to have_http_status(:forbidden)
  end

  it "allows GETs of a region" do
    api_basic_authorize action_identifier(:regions, :read, :resource_actions, :get)

    region = FactoryGirl.create(:miq_region, :region => "2")

    run_get(regions_url(region.id))

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include(
      "href" => a_string_matching(regions_url(region.id)),
      "id"   => region.id
    )
  end

  describe "/api/regions/:id/settings" do
    let(:region_number) { ApplicationRecord.my_region_number + 1 }
    let(:id) { ApplicationRecord.id_in_region(1, region_number) }
    let(:region) { FactoryGirl.create(:miq_region, :id => id, :region => region_number) }
    let(:zone) { FactoryGirl.create(:zone, :id => id) }
    let!(:server) { EvmSpecHelper.remote_miq_server(:id => id, :zone => zone) }
    let(:original_timeout) { region.settings_for_resource[:api][:authentication_timeout] }
    let(:user) { FactoryGirl.create(:user, :role => role_name, :userid => 'alice', :password => 'alicepassword') }
    let(:role_name) { 'user' }

    def define_user
      @user = user
      @role = user.miq_groups.first.miq_user_role
    end

    it "shows the settings to an authenticated user with the proper role" do
      api_basic_authorize(:ops_settings)

      run_get(api_region_settings_url(nil, region))

      expect(response).to have_http_status(:ok)
    end

    it "does not allow an authenticated user who doesn't have the proper role to view the settings" do
      api_basic_authorize

      run_get(api_region_settings_url(nil, region))

      expect(response).to have_http_status(:forbidden)
    end

    it "does not allow an unauthenticated user to view the settings" do
      run_get(api_region_settings_url(nil, region))

      expect(response).to have_http_status(:unauthorized)
    end

    context "as an authenticated super-admin user" do
      let(:role_name) { 'super_administrator' }

      it "permits updates to settings" do
        api_basic_authorize

        expect {
          run_patch(api_region_settings_url(nil, region), :params => {:api => {:authentication_timeout => "1337.minutes"}})
        }.to change { region.settings_for_resource[:api][:authentication_timeout] }.from(original_timeout).to("1337.minutes")

        expect(response.parsed_body).to include("api" => a_hash_including("authentication_timeout" => "1337.minutes"))
        expect(response).to have_http_status(:ok)
      end
    end

    it "does not allow an authenticated non-super-admin user to update settings" do
      api_basic_authorize

      expect {
        run_patch(api_region_settings_url(nil, region), :params => {:api => {:authentication_timeout => "10.minutes"}})
      }.not_to change { region.settings_for_resource[:api][:authentication_timeout] }

      expect(response).to have_http_status(:forbidden)
    end

    it "does not allow an unauthenticated user to update the settings" do
      expect {
        run_patch(api_region_settings_url(nil, region), :params => {:api => {:authentication_timeout => "10.minutes"}})
      }.not_to change { region.settings_for_resource[:api][:authentication_timeout] }

      expect(response).to have_http_status(:unauthorized)
    end

    context "with an existing settings change" do
      before do
        region.add_settings_for_resource("api" => {"authentication_timeout" => "7331.minutes"})
      end

      context "as an authenticated super-admin" do
        let(:role_name) { 'super_administrator' }

        it "allows user to delete settings" do
          api_basic_authorize
          expect(region.settings_for_resource["api"]["authentication_timeout"]).to eq("7331.minutes")

          expect {
            delete(
              api_region_settings_url(nil, region),
              :params => %i[api authentication_timeout].to_json # => hack because Rails will interpret these as query params in a DELETE
            )
          }.to change { region.settings_for_resource["api"]["authentication_timeout"] }.from("7331.minutes").to("30.seconds")

          expect(response).to have_http_status(:no_content)
        end
      end

      it "does not allow an authenticated non-super-admin user to delete settings" do
        api_basic_authorize

        expect {
          delete(
            api_region_settings_url(nil, region),
            :params => %i[api authentication_timeout].to_json # => hack because Rails will interpret these as query params in a DELETE
          )
        }.not_to change { region.settings_for_resource["api"]["authentication_timeout"] }

        expect(response).to have_http_status(:forbidden)
      end

      it "does not allow an unauthenticated user to delete settings`" do
        expect {
          delete(
            api_region_settings_url(nil, region),
            :params => %i[api authentication_timeout].to_json # => hack because Rails will interpret these as query params in a DELETE
          )
        }.not_to change { region.settings_for_resource["api"]["authentication_timeout"] }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
