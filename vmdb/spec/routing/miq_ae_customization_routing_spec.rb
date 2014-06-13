require "spec_helper"

describe MiqAeCustomizationController do
  describe "#ab_group_reorder" do
    it "routes with POST" do
      expect(post("/miq_ae_customization/ab_group_reorder")).to route_to("miq_ae_customization#ab_group_reorder")
    end
  end

  describe "#ae_tree_select" do
    it "routes with POST" do
      expect(post("/miq_ae_customization/ae_tree_select")).to route_to("miq_ae_customization#ae_tree_select")
    end
  end

  describe "#ae_tree_select_toggle" do
    it "routes with POST" do
      expect(post("/miq_ae_customization/ae_tree_select_toggle")).to route_to(
        "miq_ae_customization#ae_tree_select_toggle"
      )
    end
  end

  describe "#accordion_select" do
    it "routes with POST" do
      expect(post("/miq_ae_customization/accordion_select")).to route_to("miq_ae_customization#accordion_select")
    end
  end

  describe "#automate_button_field_changed" do
    it "routes with POST" do
      expect(post("/miq_ae_customization/automate_button_field_changed")).to route_to(
        "miq_ae_customization#automate_button_field_changed"
      )
    end
  end

  describe "#button_create" do
    it "routes with POST" do
      expect(post("/miq_ae_customization/button_create")).to route_to("miq_ae_customization#button_create")
    end
  end

  describe "#button_update" do
    it "routes with POST" do
      expect(post("/miq_ae_customization/button_update")).to route_to("miq_ae_customization#button_update")
    end
  end

  describe "#cancel_import" do
    it "routes with POST" do
      expect(post("/miq_ae_customization/cancel_import")).to route_to("miq_ae_customization#cancel_import")
    end
  end

  describe "#change_tab" do
    it "routes with POST" do
      expect(post("/miq_ae_customization/change_tab")).to route_to("miq_ae_customization#change_tab")
    end
  end

  describe "#dialog_edit" do
    it "routes with POST" do
      expect(post("/miq_ae_customization/dialog_edit")).to route_to("miq_ae_customization#dialog_edit")
    end
  end

  describe "#dialog_form_field_changed" do
    it "routes with POST" do
      expect(post("/miq_ae_customization/dialog_form_field_changed")).to route_to(
        "miq_ae_customization#dialog_form_field_changed"
      )
    end
  end

  describe "#dialog_res_remove" do
    it "routes with POST" do
      expect(post("/miq_ae_customization/dialog_res_remove")).to route_to("miq_ae_customization#dialog_res_remove")
    end
  end

  describe "#dialog_res_reorder" do
    it "routes with GET" do
      expect(get("/miq_ae_customization/dialog_res_reorder")).to route_to("miq_ae_customization#dialog_res_reorder")
    end
  end

  describe "#explorer" do
    it "routes with GET" do
      expect(get("/miq_ae_customization/explorer")).to route_to("miq_ae_customization#explorer")
    end

    it "routes with POST" do
      expect(post("/miq_ae_customization/explorer")).to route_to("miq_ae_customization#explorer")
    end
  end

  describe "#export_service_dialogs" do
    it "routes with GET" do
      expect(get("/miq_ae_customization/export_service_dialogs")).to route_to(
        "miq_ae_customization#export_service_dialogs"
      )
    end
  end

  describe "#field_value_accept" do
    it "routes with POST" do
      expect(post("/miq_ae_customization/field_value_accept")).to route_to("miq_ae_customization#field_value_accept")
    end
  end

  describe "#field_value_delete" do
    it "routes with POST" do
      expect(post("/miq_ae_customization/field_value_delete")).to route_to("miq_ae_customization#field_value_delete")
    end
  end

  describe "#field_value_select" do
    it "routes with POST" do
      expect(post("/miq_ae_customization/field_value_select")).to route_to("miq_ae_customization#field_value_select")
    end
  end

  describe "#group_create" do
    it "routes with POST" do
      expect(post("/miq_ae_customization/group_create")).to route_to("miq_ae_customization#group_create")
    end
  end

  describe "#group_form_field_changed" do
    it "routes with POST" do
      expect(post("/miq_ae_customization/group_form_field_changed")).to route_to(
        "miq_ae_customization#group_form_field_changed"
      )
    end
  end

  describe "#group_reorder_field_changed" do
    it "routes with POST" do
      expect(post("/miq_ae_customization/group_reorder_field_changed")).to route_to(
        "miq_ae_customization#group_reorder_field_changed"
      )
    end
  end

  describe "#group_update" do
    it "routes with POST" do
      expect(post("/miq_ae_customization/group_update")).to route_to("miq_ae_customization#group_update")
    end
  end

  describe "#import_service_dialogs" do
    it "routes with POST" do
      expect(post("/miq_ae_customization/import_service_dialogs")).to route_to(
        "miq_ae_customization#import_service_dialogs"
      )
    end
  end

  describe "#old_dialogs_form_field_changed" do
    it "routes with POST" do
      expect(post("/miq_ae_customization/old_dialogs_form_field_changed")).to route_to(
        "miq_ae_customization#old_dialogs_form_field_changed"
      )
    end
  end

  describe "#old_dialogs_list" do
    it "routes with POST" do
      expect(post("/miq_ae_customization/old_dialogs_list")).to route_to("miq_ae_customization#old_dialogs_list")
    end
  end

  describe "#old_dialogs_update" do
    it "routes with POST" do
      expect(post("/miq_ae_customization/old_dialogs_update")).to route_to("miq_ae_customization#old_dialogs_update")
    end
  end

  describe "#reload" do
    it "routes with POST" do
      expect(post("/miq_ae_customization/reload")).to route_to("miq_ae_customization#reload")
    end
  end

  describe "#resolve" do
    it "routes with POST" do
      expect(post("/miq_ae_customization/resolve")).to route_to("miq_ae_customization#resolve")
    end
  end

  describe "#review_import" do
    it "routes with GET" do
      expect(get("/miq_ae_customization/review_import")).to route_to("miq_ae_customization#review_import")
    end
  end

  describe "#service_dialog_json" do
    it "routes with GET" do
      expect(get("/miq_ae_customization/service_dialog_json")).to route_to("miq_ae_customization#service_dialog_json")
    end
  end

  describe "#tree_autoload_dynatree" do
    it "routes with POST" do
      expect(post("/miq_ae_customization/tree_autoload_dynatree")).to route_to(
        "miq_ae_customization#tree_autoload_dynatree"
      )
    end
  end

  describe "#tree_select" do
    it "routes with POST" do
      expect(post("/miq_ae_customization/tree_select")).to route_to("miq_ae_customization#tree_select")
    end
  end

  describe "#upload_import_file" do
    it "routes with POST" do
      expect(post("/miq_ae_customization/upload_import_file")).to route_to("miq_ae_customization#upload_import_file")
    end
  end

  describe "#x_button" do
    it "routes with POST" do
      expect(post("/miq_ae_customization/x_button")).to route_to("miq_ae_customization#x_button")
    end
  end

  describe "#x_history" do
    it "routes with POST" do
      expect(post("/miq_ae_customization/x_history")).to route_to("miq_ae_customization#x_history")
    end
  end

  describe "#x_settings_changed" do
    it "routes with POST" do
      expect(post("/miq_ae_customization/x_settings_changed")).to route_to("miq_ae_customization#x_settings_changed")
    end
  end

  describe "#x_show" do
    it "routes with POST" do
      expect(post("/miq_ae_customization/x_show")).to route_to("miq_ae_customization#x_show")
    end
  end
end
