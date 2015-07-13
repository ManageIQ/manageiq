require "spec_helper"

describe "miq_ae_tools/_results_xml.html.haml" do
  before do
    assign(:sb, :active_tab => "xml")
    assign(:results, "<MiqAeAttribute>MiqAeService \n \"EmsCluster\"</send></MiqAeAttribute>")
  end

  it "html_safe XML and escape characters in results" do
    render
    response.should include("<MiqAeAttribute>MiqAeService  \\\"EmsCluster\\\"</send></MiqAeAttribute>")
  end
end
