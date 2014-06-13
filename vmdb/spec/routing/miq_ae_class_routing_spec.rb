require "spec_helper"

describe MiqAeClassController do
  describe "#change_tab" do
    it "routes with POST" do
      expect(post("/miq_ae_class/change_tab")).to route_to("miq_ae_class#change_tab")
    end
  end

  describe "#create" do
    it "routes with POST" do
      expect(post("/miq_ae_class/create")).to route_to("miq_ae_class#create")
    end
  end

  describe "#create_instance" do
    it "routes with POST" do
      expect(post("/miq_ae_class/create_instance")).to route_to("miq_ae_class#create_instance")
    end
  end

  describe "#create_method" do
    it "routes with POST" do
      expect(post("/miq_ae_class/create_method")).to route_to("miq_ae_class#create_method")
    end
  end

  describe "#create_ns" do
    it "routes with POST" do
      expect(post("/miq_ae_class/create_ns")).to route_to("miq_ae_class#create_ns")
    end
  end

  describe "#explorer" do
    it "routes with GET" do
      expect(get("/miq_ae_class/explorer")).to route_to("miq_ae_class#explorer")
    end

    it "routes with POST" do
      expect(post("/miq_ae_class/explorer")).to route_to("miq_ae_class#explorer")
    end
  end

  describe "#expand_toggle" do
    it "routes with POST" do
      expect(post("/miq_ae_class/expand_toggle")).to route_to("miq_ae_class#expand_toggle")
    end
  end

  describe "#field_accept" do
    it "routes with POST" do
      expect(post("/miq_ae_class/field_accept")).to route_to("miq_ae_class#field_accept")
    end
  end

  describe "#field_delete" do
    it "routes with POST" do
      expect(post("/miq_ae_class/field_delete")).to route_to("miq_ae_class#field_delete")
    end
  end

  describe "#field_method_accept" do
    it "routes with POST" do
      expect(post("/miq_ae_class/field_method_accept")).to route_to("miq_ae_class#field_method_accept")
    end
  end

  describe "#field_method_delete" do
    it "routes with POST" do
      expect(post("/miq_ae_class/field_method_delete")).to route_to("miq_ae_class#field_method_delete")
    end
  end

  describe "#field_method_select" do
    it "routes with POST" do
      expect(post("/miq_ae_class/field_method_select")).to route_to("miq_ae_class#field_method_select")
    end
  end

  describe "#field_select" do
    it "routes with POST" do
      expect(post("/miq_ae_class/field_select")).to route_to("miq_ae_class#field_select")
    end
  end

  describe "#fields_form_field_changed" do
    it "routes with POST" do
      expect(post("/miq_ae_class/fields_form_field_changed")).to route_to("miq_ae_class#fields_form_field_changed")
    end
  end

  describe "#fields_seq_edit" do
    it "routes with POST" do
      expect(post("/miq_ae_class/fields_seq_edit")).to route_to("miq_ae_class#fields_seq_edit")
    end
  end

  describe "#fields_seq_field_changed" do
    it "routes with POST" do
      expect(post("/miq_ae_class/fields_seq_field_changed")).to route_to("miq_ae_class#fields_seq_field_changed")
    end
  end

  describe "#form_field_changed" do
    it "routes with POST" do
      expect(post("/miq_ae_class/form_field_changed")).to route_to("miq_ae_class#form_field_changed")
    end
  end

  describe "#form_instance_field_changed" do
    it "routes with POST" do
      expect(post("/miq_ae_class/form_instance_field_changed")).to route_to("miq_ae_class#form_instance_field_changed")
    end
  end

  describe "#form_method_field_changed" do
    it "routes with POST" do
      expect(post("/miq_ae_class/form_method_field_changed")).to route_to("miq_ae_class#form_method_field_changed")
    end
  end

  describe "#form_ns_field_changed" do
    it "routes with POST" do
      expect(post("/miq_ae_class/form_ns_field_changed")).to route_to("miq_ae_class#form_ns_field_changed")
    end
  end

  describe "#reload" do
    it "routes with POST" do
      expect(post("/miq_ae_class/reload")).to route_to("miq_ae_class#reload")
    end
  end

  describe "#tree_select" do
    it "routes with POST" do
      expect(post("/miq_ae_class/tree_select")).to route_to("miq_ae_class#tree_select")
    end
  end

  describe "#tree_autoload_dynatree" do
    it "routes with POST" do
      expect(post("/miq_ae_class/tree_autoload_dynatree")).to route_to("miq_ae_class#tree_autoload_dynatree")
    end
  end

  describe "#update" do
    it "routes with POST" do
      expect(post("/miq_ae_class/update")).to route_to("miq_ae_class#update")
    end
  end

  describe "#update_fields" do
    it "routes with POST" do
      expect(post("/miq_ae_class/update_fields")).to route_to("miq_ae_class#update_fields")
    end
  end

  describe "#update_instance" do
    it "routes with POST" do
      expect(post("/miq_ae_class/update_instance")).to route_to("miq_ae_class#update_instance")
    end
  end

  describe "#update_method" do
    it "routes with POST" do
      expect(post("/miq_ae_class/update_method")).to route_to("miq_ae_class#update_method")
    end
  end

  describe "#update_ns" do
    it "routes with POST" do
      expect(post("/miq_ae_class/update_ns")).to route_to("miq_ae_class#update_ns")
    end
  end

  describe "#validate_method_data" do
    it "routes with POST" do
      expect(post("/miq_ae_class/validate_method_data")).to route_to("miq_ae_class#validate_method_data")
    end
  end

  describe "#x_button" do
    it "routes with POST" do
      expect(post("/miq_ae_class/x_button")).to route_to("miq_ae_class#x_button")
    end
  end

  describe "#x_history" do
    it "routes with POST" do
      expect(post("/miq_ae_class/x_history")).to route_to("miq_ae_class#x_history")
    end
  end

  describe "#x_settings_changed" do
    it "routes with POST" do
      expect(post("/miq_ae_class/x_settings_changed")).to route_to("miq_ae_class#x_settings_changed")
    end
  end
end
