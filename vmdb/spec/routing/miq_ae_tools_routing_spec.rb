require "spec_helper"

describe MiqAeToolsController do
  describe "#button" do
    it "routes with POST" do
      expect(post("/miq_ae_tools/button")).to route_to("miq_ae_tools#button")
    end
  end

  describe "#export_datastore" do
    it "routes with GET" do
      expect(get("/miq_ae_tools/export_datastore")).to route_to("miq_ae_tools#export_datastore")
    end
  end

  describe "#fetch_log" do
    it "routes with GET" do
      expect(get("/miq_ae_tools/fetch_log")).to route_to("miq_ae_tools#fetch_log")
    end
  end

  describe "#form_field_changed" do
    it "routes with POST" do
      expect(post("/miq_ae_tools/form_field_changed")).to route_to("miq_ae_tools#form_field_changed")
    end
  end

  describe "#import_export" do
    it "routes with GET" do
      expect(get("/miq_ae_tools/import_export")).to route_to("miq_ae_tools#import_export")
    end
  end

  describe "#log" do
    it "routes with GET" do
      expect(get("/miq_ae_tools/log")).to route_to("miq_ae_tools#log")
    end
  end

  describe "#reset_datastore" do
    it "routes with POST" do
      expect(post("/miq_ae_tools/reset_datastore")).to route_to("miq_ae_tools#reset_datastore")
    end
  end

  describe "#resolve" do
    it "routes with GET" do
      expect(get("/miq_ae_tools/resolve")).to route_to("miq_ae_tools#resolve")
    end

    it "routes with POST" do
      expect(post("/miq_ae_tools/resolve")).to route_to("miq_ae_tools#resolve")
    end
  end

  describe "#upload" do
    it "routes with POST" do
      expect(post("/miq_ae_tools/upload")).to route_to("miq_ae_tools#upload")
    end
  end

  describe "#wait_for_task" do
    it "routes with POST" do
      expect(post("/miq_ae_tools/wait_for_task")).to route_to("miq_ae_tools#wait_for_task")
    end
  end
end
