require "spec_helper"
require "routing/shared_examples"

describe "routes for MiqTemplateController" do
  let(:controller_name) { "miq_proxy" }

  it_behaves_like "A controller that has show list routes"
  it_behaves_like "A controller that has download_data routes"
  it_behaves_like "A controller that has policy protect routes"

  describe "#ownership" do
    it "routes with GET" do
      expect(get("/miq_template/ownership")).to route_to("miq_template#ownership")
    end

    it "routes with POST" do
      expect(post("/miq_template/ownership")).to route_to("miq_template#ownership")
    end
  end

  describe "#ownership_field_changed" do
    it "routes with POST" do
      expect(post("/miq_template/ownership_field_changed")).to route_to("miq_template#ownership_field_changed")
    end
  end

  describe "#ownership_update" do
    it "routes with POST" do
      expect(post("/miq_template/ownership_update")).to route_to("miq_template#ownership_update")
    end
  end

  describe "#show" do
    it "routes with GET" do
      expect(get("miq_template/show")).to route_to("miq_template#show")
    end

    it "routes with POST" do
      expect(post("/miq_template/show")).to route_to("miq_template#show")
    end
  end

  describe "#edit" do
    it "routes with GET" do
      expect(get("miq_template/edit")).to route_to("miq_template#edit")
    end

    it "routes with POST" do
      expect(post("/miq_template/edit")).to route_to("miq_template#edit")
    end
  end

  describe "#edit_vm" do
    it "routes with POST" do
      expect(post("/miq_template/edit_vm")).to route_to("miq_template#edit_vm")
    end
  end

  describe "#form_field_changed" do
    it "routes with POST" do
      expect(post("/miq_template/form_field_changed")).to route_to("miq_template#form_field_changed")
    end
  end
end
