#
# REST API Request Tests - /api/tags
#
require 'spec_helper'

describe ApiController do

  include Rack::Test::Methods

  before(:each) do
    init_api_spec_env

    @zone       = FactoryGirl.create(:zone, :name => "api_zone")
    @miq_server = FactoryGirl.create(:miq_server, :guid => miq_server_guid, :zone => @zone)
    @ems        = FactoryGirl.create(:ems_vmware, :zone => @zone)
    @host       = FactoryGirl.create(:host)

    Host.any_instance.stub(:miq_proxy).and_return(@miq_server)

    @vm1           = FactoryGirl.create(:vm_vmware, :host => @host, :ems_id => @ems.id, :raw_power_state => "poweredOn")
    @vm1_url       = "#{@cfme[:vms_url]}/#{@vm1.id}"
    @vm1_tags_url  = "#{@vm1_url}/tags"

    @vm2           = FactoryGirl.create(:vm_vmware, :host => @host, :ems_id => @ems.id, :raw_power_state => "poweredOn")
    @vm2_url       = "#{@cfme[:vms_url]}/#{@vm2.id}"
    @vm2_tags_url  = "#{@vm2_url}/tags"

    FactoryGirl.create(:classification_department_with_tags)
    FactoryGirl.create(:classification_cost_center_with_tags)

    @tag1 = {:category => "department", :name => "finance", :path => "/managed/department/finance"}
    @tag2 = {:category => "cc",         :name => "001",     :path => "/managed/cc/001"}

    Classification.classify(@vm2, @tag1[:category], @tag1[:name])
    Classification.classify(@vm2, @tag2[:category], @tag2[:name])
  end

  def app
    Vmdb::Application
  end

  context "Tag collection" do
    it "query all tags" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_get @cfme[:tags_url]

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("name")
      expect(@result["name"]).to eq("tags")
      expect(@result).to have_key("resources")
      expect(@result["resources"].size).to eq(Tag.count)
    end

    it "query a tag with an invalid Id" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_get "#{@cfme[:tags_url]}/999999"

      expect(@success).to be_false
      expect(@code).to eq(404)
    end

    it "query tags with expanded resources" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_get "#{@cfme[:tags_url]}?expand=resources"

      expect(@success).to be_true
      expect(@code).to eq(200)
      results = @result["resources"]
      expect(results.size).to eq(Tag.count)
      expect(results.all? { |r| r.key?("id") }).to be_true
      expect(results.all? { |r| r.key?("name") }).to be_true
    end

    it "query tag details with multiple virtual attributes" do
      basic_authorize @cfme[:user], @cfme[:password]

      tag = Tag.last
      tag_url = "#{@cfme[:tags_url]}/#{tag.id}"
      attr_list = "category.name,category.description,classification.name,classification.description"

      @success = run_get "#{tag_url}?attributes=#{attr_list}"

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result["href"]).to match(tag_url)
      expect(@result["id"]).to eq(tag.id)
      expect(@result["name"]).to eq(tag.name)
      expect(@result).to have_key("category")
      expect(@result["category"]["name"]).to eq(tag.category.name)
      expect(@result["category"]["description"]).to eq(tag.category.description)
      expect(@result).to have_key("classification")
      expect(@result["classification"]["name"]).to eq(tag.classification.name)
      expect(@result["classification"]["description"]).to eq(tag.classification.description)
    end

    it "query tag details with categorization" do
      basic_authorize @cfme[:user], @cfme[:password]

      tag = Tag.last
      tag_url = "#{@cfme[:tags_url]}/#{tag.id}"

      @success = run_get "#{tag_url}?attributes=categorization"

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result["href"]).to match(tag_url)
      expect(@result["id"]).to eq(tag.id)
      expect(@result["name"]).to eq(tag.name)
      expect(@result).to have_key("categorization")
      cat = @result["categorization"]
      expect(cat["name"]).to eq(tag.classification.name)
      expect(cat["description"]).to eq(tag.classification.description)
      expect(cat).to have_key("category")
      expect(cat["category"]["name"]).to eq(tag.category.name)
      expect(cat["category"]["description"]).to eq(tag.category.description)
      expect(cat["display_name"]).not_to be_empty
    end

    it "query all tags with categorization" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_get "#{@cfme[:tags_url]}?expand=resources&attributes=categorization"

      expect(@success).to be_true
      expect(@code).to eq(200)
      results = @result["resources"]
      expect(results.size).to eq(Tag.count)
      expect(results.all? { |r| r.key?("id") }).to be_true
      expect(results.all? { |r| r.key?("name") }).to be_true
      expect(results.all? { |r| r.key?("categorization") }).to be_true
    end
  end

  context "Vm Tag subcollection" do
    it "query all tags of a Vm with no tags" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_get @vm1_tags_url

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result["name"]).to eq("tags")
      expect(@result["subcount"]).to eq(0)
      expect(@result["resources"].size).to eq(0)
    end

    it "query all tags of a Vm" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_get @vm2_tags_url

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result["name"]).to eq("tags")
      expect(@result["count"]).to eq(Tag.count)
      expect(@result["subcount"]).to eq(2)
      expect(@result["resources"].size).to eq(2)
    end

    it "query all tags of a Vm and verify tag category and names" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_get "#{@vm2_tags_url}?expand=resources"

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result["name"]).to eq("tags")
      expect(@result["count"]).to eq(Tag.count)
      expect(@result["resources"].size).to eq(2)
      results = @result["resources"]
      expect(resources_include_suffix?(results, "name", @tag1[:path])).to be_true
      expect(resources_include_suffix?(results, "name", @tag2[:path])).to be_true
    end

    it "assigns a tag to a Vm without appropriate role" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_post(@vm1_tags_url, gen_request(:assign,
                                                     :category => @tag1[:category],
                                                     :name     => @tag1[:name]))
      expect(@success).to be_false
      expect(@code).to eq(403)
    end

    it "assigns a tag to a Vm" do
      update_user_role(@role, subcollection_action_identifier(:vms, :tags, :assign))
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_post(@vm1_tags_url, gen_request(:assign,
                                                     :category => @tag1[:category],
                                                     :name     => @tag1[:name]))
      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("results")
      results = @result["results"]
      expect(results.size).to eq(1)
      result = results.first
      expect(result["success"]).to be_true
      expect(result["href"]).to match(@vm1_url)
      expect(result["tag_category"]).to eq(@tag1[:category])
      expect(result["tag_name"]).to eq(@tag1[:name])
    end

    it "assigns a tag to a Vm by name path" do
      update_user_role(@role, subcollection_action_identifier(:vms, :tags, :assign))
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_post(@vm1_tags_url, gen_request(:assign, :name => @tag1[:path]))

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("results")
      results = @result["results"]
      expect(results.size).to eq(1)
      result = results.first
      expect(result["success"]).to be_true
      expect(result["href"]).to match(@vm1_url)
      expect(result["tag_category"]).to eq(@tag1[:category])
      expect(result["tag_name"]).to eq(@tag1[:name])
    end

    it "assigns a tag to a Vm by href" do
      update_user_role(@role, subcollection_action_identifier(:vms, :tags, :assign))
      basic_authorize @cfme[:user], @cfme[:password]

      tag = Tag.find_by_name(@tag1[:path])
      @success = run_post(@vm1_tags_url, gen_request(:assign, :href => "#{@cfme[:tags_url]}/#{tag.id}"))

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("results")
      results = @result["results"]
      expect(results.size).to eq(1)
      result = results.first
      expect(result["success"]).to be_true
      expect(result["href"]).to match(@vm1_url)
      expect(result["tag_category"]).to eq(@tag1[:category])
      expect(result["tag_name"]).to eq(@tag1[:name])
    end

    it "assigns an invalid tag by href to a Vm" do
      update_user_role(@role, subcollection_action_identifier(:vms, :tags, :assign))
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_post(@vm1_tags_url, gen_request(:assign, :href => "#{@cfme[:tags_url]}/999999"))

      expect(@success).to be_false
      expect(@code).to eq(404)
    end

    it "assigns an invalid tag to a Vm" do
      update_user_role(@role, subcollection_action_identifier(:vms, :tags, :assign))
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_post(@vm1_tags_url, gen_request(:assign, :name => "/managed/bad_category/bad_name"))

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("results")
      result = @result["results"].first
      expect(result["success"]).to be_false
      expect(result["href"]).to match(@vm1_url)
      expect(result["tag_category"]).to eq("bad_category")
      expect(result["tag_name"]).to eq("bad_name")
    end

    it "assigns multiple tags to a Vm" do
      update_user_role(@role, subcollection_action_identifier(:vms, :tags, :assign))
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_post(@vm1_tags_url, gen_request(:assign, [{:name => @tag1[:path]}, {:name => @tag2[:path]}]))

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("results")
      results = @result["results"]
      expect(results.size).to eq(2)
      expect(results.first["success"]).to be_true
      expect(results.first["href"]).to match(@vm1_url)
      expect(results.first["tag_category"]).to eq(@tag1[:category])
      expect(results.first["tag_name"]).to eq(@tag1[:name])
      expect(results.second["success"]).to be_true
      expect(results.second["href"]).to match(@vm1_url)
      expect(results.second["tag_category"]).to eq(@tag2[:category])
      expect(results.second["tag_name"]).to eq(@tag2[:name])
    end

    it "assigns tags by mixed specification to a Vm" do
      update_user_role(@role, subcollection_action_identifier(:vms, :tags, :assign))
      basic_authorize @cfme[:user], @cfme[:password]

      tag2 = Tag.find_by_name(@tag2[:path])
      @success = run_post(@vm1_tags_url, gen_request(:assign, [{:name => @tag1[:path]},
                                                               {:href => "#{@cfme[:tags_url]}/#{tag2.id}"}]))

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("results")
      results = @result["results"]
      expect(results.size).to eq(2)
      expect(results.first["success"]).to be_true
      expect(results.first["href"]).to match(@vm1_url)
      expect(results.first["tag_category"]).to eq(@tag1[:category])
      expect(results.first["tag_name"]).to eq(@tag1[:name])
      expect(results.second["success"]).to be_true
      expect(results.second["href"]).to match(@vm1_url)
      expect(results.second["tag_category"]).to eq(@tag2[:category])
      expect(results.second["tag_name"]).to eq(@tag2[:name])
    end

    it "unassigns a tag from a Vm without appropriate role" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_post(@vm1_tags_url, gen_request(:assign,
                                                     :category => @tag1[:category],
                                                     :name     => @tag1[:name]))
      expect(@success).to be_false
      expect(@code).to eq(403)
    end

    it "unassigns a tag from a Vm" do
      update_user_role(@role, subcollection_action_identifier(:vms, :tags, :unassign))
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_post(@vm2_tags_url, gen_request(:unassign,
                                                     :category => @tag1[:category],
                                                     :name     => @tag1[:name]))
      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("results")
      results = @result["results"]
      expect(results.size).to eq(1)
      result = results.first
      expect(result["success"]).to be_true
      expect(result["href"]).to match(@vm2_url)
      expect(result["tag_category"]).to eq(@tag1[:category])
      expect(result["tag_name"]).to eq(@tag1[:name])
      expect(@vm2.tags.count).to eq(1)
      expect(@vm2.tags.first.name).to eq(@tag2[:path])
    end

    it "unassigns multiple tags from a Vm" do
      update_user_role(@role, subcollection_action_identifier(:vms, :tags, :unassign))
      basic_authorize @cfme[:user], @cfme[:password]

      tag2 = Tag.find_by_name(@tag2[:path])
      @success = run_post(@vm2_tags_url, gen_request(:unassign, [{:name => @tag1[:path]},
                                                                 {:href => "#{@cfme[:tags_url]}/#{tag2.id}"}]))

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("results")
      results = @result["results"]
      expect(results.size).to eq(2)
      expect(results.first["success"]).to be_true
      expect(results.first["href"]).to match(@vm2_url)
      expect(results.first["tag_category"]).to eq(@tag1[:category])
      expect(results.first["tag_name"]).to eq(@tag1[:name])
      expect(results.second["success"]).to be_true
      expect(results.second["href"]).to match(@vm2_url)
      expect(results.second["tag_category"]).to eq(@tag2[:category])
      expect(results.second["tag_name"]).to eq(@tag2[:name])
      expect(@vm2.tags.count).to eq(0)
    end
  end
end
