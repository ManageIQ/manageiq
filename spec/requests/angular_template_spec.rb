require "spec_helper"

describe "/angular_template/*" do
  context "foo" do
    it "returns test template" do
      get "/angular_template/test"
      expect(response.status).to eq(200)
      expect(response.body).to start_with('<!--')
    end

    it "renders haml template" do
      get "/angular_template/test_haml"
      expect(response.status).to eq(200)
      expect(response.body).to include('<div class="testclass">')
      expect(response.body).to not_include(".testclass")
    end
  end
end
