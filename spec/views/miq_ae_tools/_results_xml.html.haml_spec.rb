describe "miq_ae_tools/_results_xml.html.haml" do
  helper(JsHelper)

  before do
    assign(:sb, :active_tab => "xml")
    assign(:results, "<MiqAeAttribute>MiqAeService \n \"EmsCluster\"</send></MiqAeAttribute>")
  end

  it "html_safe XML and escape characters in results" do
    render
    expect(response).to include("\"<MiqAeAttribute>MiqAeService \\n \\\"EmsCluster\\\"<\\/send><\\/MiqAeAttribute>\"")
  end
end
