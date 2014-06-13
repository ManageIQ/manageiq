require "spec_helper"

describe MiqAeClassController do
  context "#set_record_vars" do
    it "dashboard owner remains unchanged" do
      ns = FactoryGirl.create(:miq_ae_namespace)
      cls = FactoryGirl.create(:miq_ae_class, :namespace_id => ns.id)
      ns_id = cls.namespace_id
      new = {:name => "New Name", :description => "New Description", :display_name => "Display Name", :inherits => "Some_Class"}
      controller.instance_variable_set(:@sb,
                                       {:trees => {
                                           :ae_tree => {:active_node => "aec-#{cls.id}"}
                                       },
                                        :active_tree => :ae_tree
                                       })
      controller.instance_variable_set(:@edit, {:new => new})
      controller.send(:set_record_vars, cls)
      cls.namespace_id.should == ns_id
    end
  end

  context "#set_right_cell_text" do
    it "check if correct namespace_path is being set" do
      ns = FactoryGirl.create(:miq_ae_namespace)
      cls = FactoryGirl.create(:miq_ae_class, :namespace_id => ns.id)
      controller.instance_variable_set(:@sb, {})
      id = "aec-#{cls.id}"
      fq_name = cls.fqname
      controller.send(:set_right_cell_text, id, cls)
      assigns(:sb)[:namespace_path].should == fq_name.gsub!(/\//," / ")

      id = "root"
      fq_name = ""
      controller.send(:set_right_cell_text, id)
      assigns(:sb)[:namespace_path].should == fq_name

    end
  end
end
