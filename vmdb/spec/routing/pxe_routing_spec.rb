require "spec_helper"

describe PxeController do
  describe "#accordion_select" do
    it "routes with POST" do
      expect(post("/pxe/accordion_select")).to route_to("pxe#accordion_select")
    end
  end

  describe "#explorer" do
    it "routes with GET" do
      expect(get("/pxe/explorer")).to route_to("pxe#explorer")
    end

    it "routes with POST" do
      expect(post("/pxe/explorer")).to route_to("pxe#explorer")
    end
  end

  describe "#iso_datastore_create" do
    it "routes with POST" do
      expect(post("/pxe/iso_datastore_create")).to route_to("pxe#iso_datastore_create")
    end
  end

  describe "#iso_datastore_form_field_changed" do
    it "routes with POST" do
      expect(post("/pxe/iso_datastore_form_field_changed")).to route_to("pxe#iso_datastore_form_field_changed")
    end
  end

  describe "#iso_datastore_list" do
    it "routes with POST" do
      expect(post("/pxe/iso_datastore_list")).to route_to("pxe#iso_datastore_list")
    end
  end

  describe "#log_depot_validate" do
    it "routes with POST" do
      expect(post("/pxe/log_depot_validate")).to route_to("pxe#log_depot_validate")
    end
  end

  describe "#pxe_image_edit" do
    it "routes with POST" do
      expect(post("/pxe/pxe_image_edit")).to route_to("pxe#pxe_image_edit")
    end
  end

  describe "#pxe_image_type_edit" do
    it "routes with POST" do
      expect(post("/pxe/pxe_image_type_edit")).to route_to("pxe#pxe_image_type_edit")
    end
  end

  describe "#pxe_image_type_form_field_changed" do
    it "routes with POST" do
      expect(post("/pxe/pxe_image_type_form_field_changed")).to route_to("pxe#pxe_image_type_form_field_changed")
    end
  end

  describe "#pxe_image_type_list" do
    it "routes with POST" do
      expect(post("/pxe/pxe_image_type_list")).to route_to("pxe#pxe_image_type_list")
    end
  end

  describe "#pxe_img_form_field_changed" do
    it "routes with POST" do
      expect(post("/pxe/pxe_img_form_field_changed")).to route_to("pxe#pxe_img_form_field_changed")
    end
  end

  describe "#pxe_server_create_update" do
    it "routes with POST" do
      expect(post("/pxe/pxe_server_create_update")).to route_to("pxe#pxe_server_create_update")
    end
  end

  describe "#pxe_server_form_field_changed" do
    it "routes with POST" do
      expect(post("/pxe/pxe_server_form_field_changed")).to route_to("pxe#pxe_server_form_field_changed")
    end
  end

  describe "#pxe_server_list" do
    it "routes with POST" do
      expect(post("/pxe/pxe_server_list")).to route_to("pxe#pxe_server_list")
    end
  end

  describe "#pxe_wimg_edit" do
    it "routes with POST" do
      expect(post("/pxe/pxe_wimg_edit")).to route_to("pxe#pxe_wimg_edit")
    end
  end

  describe "#pxe_wimg_form_field_changed" do
    it "routes with POST" do
      expect(post("/pxe/pxe_wimg_form_field_changed")).to route_to("pxe#pxe_wimg_form_field_changed")
    end
  end

  describe "#reload" do
    it "routes with POST" do
      expect(post("/pxe/reload")).to route_to("pxe#reload")
    end
  end

  describe "#template_create_update" do
    it "routes with POST" do
      expect(post("/pxe/template_create_update")).to route_to("pxe#template_create_update")
    end
  end

  describe "#template_form_field_changed" do
    it "routes with POST" do
      expect(post("/pxe/template_form_field_changed")).to route_to("pxe#template_form_field_changed")
    end
  end

  describe "#template_list" do
    it "routes with POST" do
      expect(post("/pxe/template_list")).to route_to("pxe#template_list")
    end
  end

  describe "#tree_autoload_dynatree" do
    it "routes with POST" do
      expect(post("/pxe/tree_autoload_dynatree")).to route_to("pxe#tree_autoload_dynatree")
    end
  end

  describe "#tree_select" do
    it "routes with POST" do
      expect(post("/pxe/tree_select")).to route_to("pxe#tree_select")
    end
  end

  describe "#x_button" do
    it "routes with POST" do
      expect(post("/pxe/x_button")).to route_to("pxe#x_button")
    end
  end

  describe "#x_history" do
    it "routes with POST" do
      expect(post("/pxe/x_history")).to route_to("pxe#x_history")
    end
  end

  describe "#x_settings_changed" do
    it "routes with POST" do
      expect(post("/pxe/x_settings_changed")).to route_to("pxe#x_settings_changed")
    end
  end
end
