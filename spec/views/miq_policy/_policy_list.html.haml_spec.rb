require "ostruct"

describe "miq_policy/_policy_list.html.haml" do
  it "renders flash message for cancelled creation of new Policy" do
    assign(:sb, :active_tree => :policy_tree, :folder => "a-b")
    assign(:view, OpenStruct.new(:table => OpenStruct.new(:data => [])))
    assign(:flash_array, [{ :message => "Add of new Policy was cancelled by the user",
                            :level   => :success }])
    render :partial => "miq_policy/policy_list"
    expect(rendered).to match "Add of new Policy was cancelled by the user"
  end
end
