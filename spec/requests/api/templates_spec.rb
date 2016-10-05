RSpec.describe "Templates API" do
  describe "tags subcollection" do
    it "can list a template's tags" do
      template = FactoryGirl.create(:template)
      FactoryGirl.create(:classification_department_with_tags)
      Classification.classify(template, "department", "finance")
      api_basic_authorize

      run_get("#{templates_url(template.id)}/tags")

      expect(response.parsed_body).to include("subcount" => 1)
      expect(response).to have_http_status(:ok)
    end

    it "can assign a tag to a template" do
      template = FactoryGirl.create(:template)
      FactoryGirl.create(:classification_department_with_tags)
      api_basic_authorize(subcollection_action_identifier(:templates, :tags, :assign))

      run_post("#{templates_url(template.id)}/tags", :action => "assign", :category => "department", :name => "finance")

      expected = {
        "results" => [
          a_hash_including(
            "success"      => true,
            "message"      => a_string_matching(/assigning tag/i),
            "tag_category" => "department",
            "tag_name"     => "finance"
          )
        ]
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end

    it "can unassign a tag from a template" do
      template = FactoryGirl.create(:template)
      FactoryGirl.create(:classification_department_with_tags)
      Classification.classify(template, "department", "finance")
      api_basic_authorize(subcollection_action_identifier(:templates, :tags, :unassign))

      run_post("#{templates_url(template.id)}/tags",
               :action   => "unassign",
               :category => "department",
               :name     => "finance")

      expected = {
        "results" => [
          a_hash_including(
            "success"      => true,
            "message"      => a_string_matching(/unassigning tag/i),
            "tag_category" => "department",
            "tag_name"     => "finance"
          )
        ]
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end
  end
end
