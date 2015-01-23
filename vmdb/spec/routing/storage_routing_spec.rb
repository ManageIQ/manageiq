require "spec_helper"
require "routing/shared_examples"

describe "routes for StorageController" do
  let(:controller_name) { "storage" }

  it_behaves_like "A controller that has advanced search routes"
  it_behaves_like "A controller that has column width routes"
  it_behaves_like "A controller that has compare routes"
  it_behaves_like "A controller that has dialog runner routes"
  it_behaves_like "A controller that has download_data routes"
  it_behaves_like "A controller that has performance routes"
  it_behaves_like "A controller that has policy protect routes"
  it_behaves_like "A controller that has show list routes"
  it_behaves_like "A controller that has tagging routes"

  describe "#button" do
    it "routes with GET" do
      expect(get("/#{controller_name}/button")).to route_to("#{controller_name}#button")
    end

    it "routes with POST" do
      expect(post("/#{controller_name}/button")).to route_to("#{controller_name}#button")
    end
  end

  describe "#debris_files" do
    it "routes with GET" do
      expect(get("/#{controller_name}/debris_files")).to route_to("#{controller_name}#debris_files")
    end
  end

  describe "#disk_files" do
    it "routes with GET" do
      expect(get("/#{controller_name}/disk_files")).to route_to("#{controller_name}#disk_files")
    end
  end

  describe "#files" do
    it "routes with GET" do
      expect(get("/#{controller_name}/files")).to route_to("#{controller_name}#files")
    end
  end

  describe "#index" do
    it "routes with GET" do
      expect(get("/#{controller_name}")).to route_to("#{controller_name}#index")
    end
  end

  describe "#listnav_search_selected" do
    it "routes with POST" do
      expect(post("/#{controller_name}/listnav_search_selected")).to route_to(
                                                                       "#{controller_name}#listnav_search_selected"
                                                                     )
    end
  end

  describe "#save_default_search" do
    it "routes with POST" do
      expect(post("/#{controller_name}/save_default_search")).to route_to("#{controller_name}#save_default_search")
    end
  end

  describe "#sections_field_changed" do
    it "routes with POST" do
      expect(
        post("/#{controller_name}/sections_field_changed")
      ).to route_to("#{controller_name}#sections_field_changed")
    end
  end

  describe "#show" do
    it "routes with GET" do
      expect(get("/#{controller_name}/show")).to route_to("#{controller_name}#show")
    end
  end

  describe "#show_details" do
    it "routes with POST" do
      expect(post("/#{controller_name}/show_details")).to route_to("#{controller_name}#show_details")
    end
  end

  describe "#show_association" do
    it "routes with POST" do
      expect(post("/#{controller_name}/show_association")).to route_to("#{controller_name}#show_association")
    end
  end

  describe "#snapshot_files" do
    it "routes with GET" do
      expect(get("/#{controller_name}/snapshot_files")).to route_to("#{controller_name}#snapshot_files")
    end
  end

  describe "#vm_misc_files" do
    it "routes with GET" do
      expect(get("/#{controller_name}/vm_misc_files")).to route_to("#{controller_name}#vm_misc_files")
    end
  end

  describe "#vm_ram_files" do
    it "routes with GET" do
      expect(get("/#{controller_name}/vm_ram_files")).to route_to("#{controller_name}#vm_ram_files")
    end
  end
end
