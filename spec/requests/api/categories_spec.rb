require "spec_helper"

RSpec.describe "categories API" do
  include Rack::Test::Methods

  before { init_api_spec_env }

  def app
    Vmdb::Application
  end

  it "can list all the categories" do
    categories = FactoryGirl.create_list(:category, 2)
    api_basic_authorize

    run_get categories_url

    expect_result_resources_to_include_hrefs(
      "resources",
      categories.map { |category| categories_url(category.id) }
    )
    expect_request_success
  end

  it "can read a category" do
    category = FactoryGirl.create(:category)
    api_basic_authorize

    run_get categories_url(category.id)
    expect_result_to_match_hash(
      @result,
      "description" => category.description,
      "href"        => categories_url(category.id),
      "id"          => category.id
    )
    expect_request_success
  end

  it "can list all the tags under a category" do
    classification = FactoryGirl.create(:classification_tag)
    category = FactoryGirl.create(:category, :children => [classification])
    tag = classification.tag
    Tag.create(:name => "some_other_tag")
    api_basic_authorize

    run_get "#{categories_url(category.id)}/tags"

    expect_result_resources_to_include_hrefs(
      "resources",
      ["#{categories_url(category.id)}/tags/#{tag.id}"]
    )
    expect_request_success
  end

  context "with an appropriate role" do
    it "can create a category" do
      api_basic_authorize collection_action_identifier(:categories, :create)

      expect do
        run_post categories_url, :name => "test", :description => "Test"
      end.to change(Category, :count).by(1)

      expect_request_success
    end

    it "can set read_only/show/single_value when creating a category" do
      api_basic_authorize collection_action_identifier(:categories, :create)

      options = {
        :name         => "test",
        :description  => "test",
        :read_only    => true,
        :show         => true,
        :single_value => true
      }
      run_post categories_url, options

      expect_result_to_match_hash(
        @result["results"].first,
        "read_only"    => true,
        "show"         => true,
        "single_value" => true
      )
    end

    it "can create an associated tag" do
      api_basic_authorize collection_action_identifier(:categories, :create)

      run_post categories_url, :name => "test", :description => "Test"
      category = Category.find(@result["results"].first["id"])

      expect(category.tag.name).to eq("/managed/test")
    end

    it "can update a category" do
      category = FactoryGirl.create(:category)
      api_basic_authorize action_identifier(:categories, :edit)

      expect do
        run_post categories_url(category.id), gen_request(:edit, :description => "New description")
      end.to change { category.reload.description }.to("New description")

      expect_request_success
    end

    it "can delete a category through POST" do
      category = FactoryGirl.create(:category)
      api_basic_authorize action_identifier(:categories, :delete)

      expect do
        run_post categories_url(category.id), gen_request(:delete)
      end.to change(Category, :count).by(-1)

      expect_request_success
    end

    it "can delete a category through DELETE" do
      category = FactoryGirl.create(:category)
      api_basic_authorize action_identifier(:categories, :delete)

      expect do
        run_delete categories_url(category.id)
      end.to change(Category, :count).by(-1)

      expect_request_success_with_no_content
    end

    context "read-only categories" do
      it "can't delete a read-only category" do
        category = FactoryGirl.create(:category, :read_only => true)
        api_basic_authorize action_identifier(:categories, :delete)

        expect do
          run_post categories_url(category.id), gen_request(:delete)
        end.not_to change(Category, :count)

        expect_request_forbidden
      end

      it "can't update a read-only category" do
        category = FactoryGirl.create(:category, :description => "old description", :read_only => true)
        api_basic_authorize action_identifier(:categories, :edit)

        expect do
          run_post categories_url(category.id), gen_request(:edit, :description => "new description")
        end.not_to change { category.reload.description }

        expect_request_forbidden
      end
    end

    context "without an appropriate role" do
      it "cannot create a category" do
        api_basic_authorize

        expect do
          run_post categories_url, :name => "test", :description => "Test"
        end.not_to change(Category, :count)

        expect_request_forbidden
      end

      it "cannot update a category" do
        category = FactoryGirl.create(:category)
        api_basic_authorize

        expect do
          run_post categories_url(category.id), gen_request(:edit, :description => "New description")
        end.not_to change { category.reload.description }

        expect_request_forbidden
      end

      it "cannot delete a category through POST" do
        category = FactoryGirl.create(:category)
        api_basic_authorize

        expect do
          run_post categories_url(category.id), gen_request(:delete)
        end.not_to change(Category, :count)

        expect_request_forbidden
      end

      it "cannot delete a category through DELETE" do
        category = FactoryGirl.create(:category)
        api_basic_authorize

        expect do
          run_delete categories_url(category.id)
        end.not_to change(Category, :count)

        expect_request_forbidden
      end
    end
  end
end
