describe "ops/_zone_form.html.haml" do
  before do
    assign(:sb, :active_tab => "zone")
  end

  context "adding a zone with a duplicate name" do
    it "should display an error and allow teh name to be changed" do
      render :partial => "ops/zone_form"
      expect(response.body).to include('Name')
    end
  end
end
