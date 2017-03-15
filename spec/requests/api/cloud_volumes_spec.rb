#
# REST API Request Tests - Cloud Volumes
#
# Regions primary collections:
#   /api/cloud_volumes
#
# Tests for:
# GET /api/cloud_volumes/:id
#

describe "Cloud Volumes API" do
  it "forbids access to cloud volumes without an appropriate role" do
    api_basic_authorize

    run_get(cloud_volumes_url)

    expect(response).to have_http_status(:forbidden)
  end

  it "forbids access to a cloud volume resource without an appropriate role" do
    api_basic_authorize

    cloud_volume = FactoryGirl.create(:cloud_volume)

    run_get(cloud_volumes_url(cloud_volume.id))

    expect(response).to have_http_status(:forbidden)
  end

  it "allows GETs of a cloud volume" do
    api_basic_authorize action_identifier(:cloud_volumes, :read, :resource_actions, :get)

    cloud_volume = FactoryGirl.create(:cloud_volume)

    run_get(cloud_volumes_url(cloud_volume.id))

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include(
      "href" => a_string_matching(cloud_volumes_url(cloud_volume.id)),
      "id"   => cloud_volume.id
    )
  end
end
