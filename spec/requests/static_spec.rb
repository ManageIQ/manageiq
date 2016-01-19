describe "/static/*" do
  context "foo" do
    before :each do
      allow_any_instance_of(ApplicationController).to receive(:set_user_time_zone)
    end

    it "returns test template" do
      get "/static/test"
      expect(response.status).to eq(200)
      expect(response.body).to start_with('<!--')
    end

    it "renders haml template" do
      get "/static/test_haml"
      expect(response.status).to eq(200)
      expect(response.body).to match(/<div class=['"]testclass['"]>/)
      expect(response.body).not_to include(".testclass")
    end
  end
end
