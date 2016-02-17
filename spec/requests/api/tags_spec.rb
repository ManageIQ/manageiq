#
# REST API Request Tests - /api/tags
#
describe ApiController do
  let(:zone)         { FactoryGirl.create(:zone, :name => "api_zone") }
  let(:miq_server)   { FactoryGirl.create(:miq_server, :guid => miq_server_guid, :zone => zone) }
  let(:ems)          { FactoryGirl.create(:ems_vmware, :zone => zone) }
  let(:host)         { FactoryGirl.create(:host) }

  let(:tag1)         { {:category => "department", :name => "finance", :path => "/managed/department/finance"} }
  let(:tag2)         { {:category => "cc",         :name => "001",     :path => "/managed/cc/001"} }

  let(:vm1) { FactoryGirl.create(:vm_vmware, :host => host, :ems_id => ems.id, :raw_power_state => "poweredOn") }
  let(:vm1_url)      { vms_url(vm1.id) }
  let(:vm1_tags_url) { "#{vm1_url}/tags" }

  let(:vm2) { FactoryGirl.create(:vm_vmware, :host => host, :ems_id => ems.id, :raw_power_state => "poweredOn") }
  let(:vm2_url)      { vms_url(vm2.id) }
  let(:vm2_tags_url) { "#{vm2_url}/tags" }

  let(:invalid_tag_url) { tags_url(999_999) }

  let(:tag_count)    { Tag.count }

  before(:each) do
    FactoryGirl.create(:classification_department_with_tags)
    FactoryGirl.create(:classification_cost_center_with_tags)

    Classification.classify(vm2, tag1[:category], tag1[:name])
    Classification.classify(vm2, tag2[:category], tag2[:name])
  end

  context "Tag collection" do
    it "query all tags" do
      api_basic_authorize

      run_get tags_url

      expect_query_result(:tags, :tag_count)
    end

    context "with an appropriate role" do
      it "can create a tag with category by href" do
        api_basic_authorize collection_action_identifier(:tags, :create)
        category = FactoryGirl.create(:category)
        options = {:name => "test_tag", :description => "Test Tag", :category => {:href => categories_url(category.id)}}

        expect { run_post tags_url, options }.to change(Tag, :count).by(1)

        tag = Tag.find(@result["results"].first["id"])
        tag_category = Category.find(tag.category.id)
        expect(tag_category).to eq(category)

        expect_request_success
      end

      it "can create a tag with a category by id" do
        api_basic_authorize collection_action_identifier(:tags, :create)
        category = FactoryGirl.create(:category)

        expect do
          run_post tags_url, :name => "test_tag", :description => "Test Tag", :category => {:id => category.id}
        end.to change(Tag, :count).by(1)

        tag = Tag.find(@result["results"].first["id"])
        tag_category = Category.find(tag.category.id)
        expect(tag_category).to eq(category)

        expect_request_success
      end

      it "can create a tag with a category by name" do
        api_basic_authorize collection_action_identifier(:tags, :create)
        category = FactoryGirl.create(:category)

        expect do
          run_post tags_url, :name => "test_tag", :description => "Test Tag", :category => {:name => category.name}
        end.to change(Tag, :count).by(1)

        tag = Tag.find(@result["results"].first["id"])
        tag_category = Category.find(tag.category.id)
        expect(tag_category).to eq(category)

        expect_request_success
      end

      it "can create a tag as a subresource of a category" do
        api_basic_authorize collection_action_identifier(:tags, :create)
        category = FactoryGirl.create(:category)

        expect do
          run_post "#{categories_url(category.id)}/tags", :name => "test_tag", :description => "Test Tag"
        end.to change(Tag, :count).by(1)
        tag = Tag.find(@result["results"].first["id"])
        tag_category = Category.find(tag.category.id)
        expect(tag_category).to eq(category)

        expect_request_success
      end

      it "returns bad request when the category doesn't exist" do
        api_basic_authorize collection_action_identifier(:tags, :create)

        run_post tags_url, :name => "test_tag", :description => "Test Tag"

        expect_bad_request
      end

      it "can update a tag's name" do
        api_basic_authorize action_identifier(:tags, :edit)
        classification = FactoryGirl.create(:classification_tag)
        category = FactoryGirl.create(:category, :children => [classification])
        tag = classification.tag

        expect do
          run_post tags_url(tag.id), gen_request(:edit, :name => "new_name")
        end.to change { classification.reload.tag.name }.to("#{category.tag.name}/new_name")
        expect(@result["name"]).to eq("#{category.tag.name}/new_name")
        expect_request_success
      end

      it "can update a tag's description" do
        api_basic_authorize action_identifier(:tags, :edit)
        classification = FactoryGirl.create(:classification_tag)
        FactoryGirl.create(:category, :children => [classification])
        tag = classification.tag

        expect do
          run_post tags_url(tag.id), gen_request(:edit, :description => "New Description")
        end.to change { tag.reload.classification.description }.to("New Description")

        expect_request_success
      end

      it "can delete a tag through POST" do
        api_basic_authorize action_identifier(:tags, :delete)
        classification = FactoryGirl.create(:classification_tag)
        tag = classification.tag

        expect { run_post tags_url(tag.id), :action => :delete }.to change(Tag, :count).by(-1)
        expect { classification.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect_request_success
      end

      it "can delete a tag through DELETE" do
        api_basic_authorize action_identifier(:tags, :delete)
        classification = FactoryGirl.create(:classification_tag)
        tag = classification.tag

        expect { run_delete tags_url(tag.id) }.to change(Tag, :count).by(-1)
        expect { classification.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect_request_success_with_no_content
      end

      it "will respond with 404 not found when deleting a non-existent tag through DELETE" do
        api_basic_authorize action_identifier(:tags, :delete)
        classification = FactoryGirl.create(:classification_tag)
        tag_id = classification.tag.id
        classification.destroy!

        run_delete tags_url(tag_id)

        expect_resource_not_found
      end

      it "will respond with 404 not found when deleting a non-existent tag through POST" do
        api_basic_authorize action_identifier(:tags, :delete)
        classification = FactoryGirl.create(:classification_tag)
        tag_id = classification.tag.id
        classification.destroy!

        run_post tags_url(tag_id), :action => :delete

        expect_resource_not_found
      end

      it "can delete multiple tags within a category by id" do
        api_basic_authorize action_identifier(:tags, :delete)
        classification1 = FactoryGirl.create(:classification_tag)
        classification2 = FactoryGirl.create(:classification_tag)
        category = FactoryGirl.create(:category, :children => [classification1, classification2])
        tag1 = classification1.tag
        tag2 = classification2.tag

        expect do
          run_post "#{categories_url(category.id)}/tags", gen_request(:delete, [{:id => tag1.id}, {:id => tag2.id}])
        end.to change(Tag, :count).by(-2)
        expect { classification1.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect { classification2.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect_result_to_match_hash(
          @result,
          "results" => [
            {"success" => true, "message" => "tags id: #{tag1.id} deleting"},
            {"success" => true, "message" => "tags id: #{tag2.id} deleting"}
          ]
        )
        expect_request_success
      end

      it "can delete multiple tags within a category by name" do
        api_basic_authorize action_identifier(:tags, :delete)
        classification1 = FactoryGirl.create(:classification_tag)
        classification2 = FactoryGirl.create(:classification_tag)
        category = FactoryGirl.create(:category, :children => [classification1, classification2])
        tag1 = classification1.tag
        tag2 = classification2.tag
        body = gen_request(:delete, [{:name => tag1.name}, {:name => tag2.name}])

        expect do
          run_post "#{categories_url(category.id)}/tags", body
        end.to change(Tag, :count).by(-2)
        expect { classification1.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect { classification2.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect_result_to_match_hash(
          @result,
          "results" => [
            {"success" => true, "message" => "tags id: #{tag1.id} deleting"},
            {"success" => true, "message" => "tags id: #{tag2.id} deleting"}
          ]
        )
        expect_request_success
      end
    end

    context "without an appropriate role" do
      it "cannot create a new tag" do
        api_basic_authorize

        expect do
          run_post tags_url, :name => "test_tag", :description => "Test Tag"
        end.not_to change(Tag, :count)

        expect_request_forbidden
      end

      it "cannot update a tag" do
        api_basic_authorize
        tag = Tag.create(:name => "Old name")

        expect do
          run_post tags_url(tag.id), gen_request(:edit, :name => "New name")
        end.not_to change { tag.reload.name }

        expect_request_forbidden
      end

      it "cannot delete a tag through POST" do
        api_basic_authorize
        tag = Tag.create(:name => "Test tag")

        expect { run_post tags_url(tag.id), :action => :delete }.not_to change(Tag, :count)

        expect_request_forbidden
      end

      it "cannot delete a tag through DELETE" do
        api_basic_authorize
        tag = Tag.create(:name => "Test tag")

        expect { run_delete tags_url(tag.id) }.not_to change(Tag, :count)

        expect_request_forbidden
      end
    end

    it "query a tag with an invalid Id" do
      api_basic_authorize

      run_get invalid_tag_url

      expect_resource_not_found
    end

    it "query tags with expanded resources" do
      api_basic_authorize

      run_get tags_url, :expand => "resources"

      expect_query_result(:tags, :tag_count, :tag_count)
      expect_result_resources_to_include_keys("resources", %w(id name))
    end

    it "query tag details with multiple virtual attributes" do
      api_basic_authorize

      tag = Tag.last
      attr_list = "category.name,category.description,classification.name,classification.description"
      run_get tags_url(tag.id), :attributes => attr_list

      expect_single_resource_query(
        "href"           => tags_url(tag.id),
        "id"             => tag.id,
        "name"           => tag.name,
        "category"       => {"name" => tag.category.name,       "description" => tag.category.description},
        "classification" => {"name" => tag.classification.name, "description" => tag.classification.description}
      )
    end

    it "query tag details with categorization" do
      api_basic_authorize

      tag = Tag.last
      run_get tags_url(tag.id), :attributes => "categorization"

      expect_single_resource_query(
        "href"           => tags_url(tag.id),
        "id"             => tag.id,
        "name"           => tag.name,
        "categorization" => {
          "name"         => tag.classification.name,
          "description"  => tag.classification.description,
          "display_name" => "#{tag.category.description}: #{tag.classification.description}",
          "category"     => {"name" => tag.category.name, "description" => tag.category.description}
        }
      )
    end

    it "query all tags with categorization" do
      api_basic_authorize

      run_get tags_url, :expand => "resources", :attributes => "categorization"

      expect_query_result(:tags, :tag_count, :tag_count)
      expect_result_resources_to_include_keys("resources", %w(id name categorization))
    end
  end

  context "Vm Tag subcollection" do
    it "query all tags of a Vm with no tags" do
      api_basic_authorize

      run_get vm1_tags_url

      expect_empty_query_result(:tags)
    end

    it "query all tags of a Vm" do
      api_basic_authorize

      run_get vm2_tags_url

      expect_query_result(:tags, 2, :tag_count)
    end

    it "query all tags of a Vm and verify tag category and names" do
      api_basic_authorize

      run_get vm2_tags_url, :expand => "resources"

      expect_query_result(:tags, 2, :tag_count)
      expect_result_resources_to_include_data("resources", "name" => [tag1[:path], tag2[:path]])
    end

    it "assigns a tag to a Vm without appropriate role" do
      api_basic_authorize

      run_post(vm1_tags_url, gen_request(:assign, :category => tag1[:category], :name => tag1[:name]))

      expect_request_forbidden
    end

    it "assigns a tag to a Vm" do
      api_basic_authorize subcollection_action_identifier(:vms, :tags, :assign)

      run_post(vm1_tags_url, gen_request(:assign, :category => tag1[:category], :name => tag1[:name]))

      expect_tagging_result(
        [{:success => true, :href => vm1_url, :tag_category => tag1[:category], :tag_name => tag1[:name]}]
      )
    end

    it "assigns a tag to a Vm by name path" do
      api_basic_authorize subcollection_action_identifier(:vms, :tags, :assign)

      run_post(vm1_tags_url, gen_request(:assign, :name => tag1[:path]))

      expect_tagging_result(
        [{:success => true, :href => vm1_url, :tag_category => tag1[:category], :tag_name => tag1[:name]}]
      )
    end

    it "assigns a tag to a Vm by href" do
      api_basic_authorize subcollection_action_identifier(:vms, :tags, :assign)

      run_post(vm1_tags_url, gen_request(:assign, :href => tags_url(Tag.find_by_name(tag1[:path]).id)))

      expect_tagging_result(
        [{:success => true, :href => vm1_url, :tag_category => tag1[:category], :tag_name => tag1[:name]}]
      )
    end

    it "assigns an invalid tag by href to a Vm" do
      api_basic_authorize subcollection_action_identifier(:vms, :tags, :assign)

      run_post(vm1_tags_url, gen_request(:assign, :href => invalid_tag_url))

      expect_resource_not_found
    end

    it "assigns an invalid tag to a Vm" do
      api_basic_authorize subcollection_action_identifier(:vms, :tags, :assign)

      run_post(vm1_tags_url, gen_request(:assign, :name => "/managed/bad_category/bad_name"))

      expect_tagging_result(
        [{:success => false, :href => vm1_url, :tag_category => "bad_category", :tag_name => "bad_name"}]
      )
    end

    it "assigns multiple tags to a Vm" do
      api_basic_authorize subcollection_action_identifier(:vms, :tags, :assign)

      run_post(vm1_tags_url, gen_request(:assign, [{:name => tag1[:path]}, {:name => tag2[:path]}]))

      expect_tagging_result(
        [{:success => true, :href => vm1_url, :tag_category => tag1[:category], :tag_name => tag1[:name]},
         {:success => true, :href => vm1_url, :tag_category => tag2[:category], :tag_name => tag2[:name]}]
      )
    end

    it "assigns tags by mixed specification to a Vm" do
      api_basic_authorize subcollection_action_identifier(:vms, :tags, :assign)

      tag = Tag.find_by_name(tag2[:path])
      run_post(vm1_tags_url, gen_request(:assign, [{:name => tag1[:path]}, {:href => tags_url(tag.id)}]))

      expect_tagging_result(
        [{:success => true, :href => vm1_url, :tag_category => tag1[:category], :tag_name => tag1[:name]},
         {:success => true, :href => vm1_url, :tag_category => tag2[:category], :tag_name => tag2[:name]}]
      )
    end

    it "unassigns a tag from a Vm without appropriate role" do
      api_basic_authorize

      run_post(vm1_tags_url, gen_request(:assign, :category => tag1[:category], :name => tag1[:name]))

      expect_request_forbidden
    end

    it "unassigns a tag from a Vm" do
      api_basic_authorize subcollection_action_identifier(:vms, :tags, :unassign)

      run_post(vm2_tags_url, gen_request(:unassign, :category => tag1[:category], :name => tag1[:name]))

      expect_tagging_result(
        [{:success => true, :href => vm2_url, :tag_category => tag1[:category], :tag_name => tag1[:name]}]
      )
      expect(vm2.tags.count).to eq(1)
      expect(vm2.tags.first.name).to eq(tag2[:path])
    end

    it "unassigns multiple tags from a Vm" do
      api_basic_authorize subcollection_action_identifier(:vms, :tags, :unassign)

      tag = Tag.find_by_name(tag2[:path])
      run_post(vm2_tags_url, gen_request(:unassign, [{:name => tag1[:path]}, {:href => tags_url(tag.id)}]))

      expect_tagging_result(
        [{:success => true, :href => vm2_url, :tag_category => tag1[:category], :tag_name => tag1[:name]},
         {:success => true, :href => vm2_url, :tag_category => tag2[:category], :tag_name => tag2[:name]}]
      )
      expect(vm2.tags.count).to eq(0)
    end
  end
end
