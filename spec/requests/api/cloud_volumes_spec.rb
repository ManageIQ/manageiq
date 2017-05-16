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

  it 'can delete cloud volumes through POST' do
    zone = FactoryGirl.create(:zone, :name => "api_zone")
    aws = FactoryGirl.create(:ems_amazon, :zone => zone)

    cloud_volume1 = FactoryGirl.create(:cloud_volume, :ext_management_system => aws, :name => "CloudVolume1")
    cloud_volume2 = FactoryGirl.create(:cloud_volume, :ext_management_system => aws, :name => "CloudVolume2")

    api_basic_authorize collection_action_identifier(:cloud_volumes, :delete, :post)

    expected = {
      'results' => [
        a_hash_including(
          'success' => true,
          'message' => a_string_including('Deleting Cloud Volume CloudVolume1'),
          'task_id' => a_kind_of(Numeric)
        ),
        a_hash_including(
          'success' => true,
          'message' => a_string_including('Deleting Cloud Volume CloudVolume2'),
          'task_id' => a_kind_of(Numeric)
        )
      ]
    }
    run_post(cloud_volumes_url, :action => 'delete', :resources => [{ 'id' => cloud_volume1.id }, { 'id' => cloud_volume2.id }])

    expect(response.parsed_body).to include(expected)
    expect(response).to have_http_status(:ok)
  end
end
