require "spec_helper"

describe OrchestrationTemplate do

  describe ".find_or_create_by_contents" do
    context "when the template does not exist" do
      before do
        @query_hash = FactoryGirl.build(:orchestration_template).as_json.symbolize_keys
      end

      it "creates a new template" do
        record = OrchestrationTemplate.find_or_create_by_contents([@query_hash])[0]
        record.name.should        == @query_hash[:name]
        record.template.should    == @query_hash[:template]
        record.description.should == @query_hash[:description]
        record.ems_ref.should_not be_nil
      end
    end

    context "when the template already exists" do
      before do
        @existing_record = FactoryGirl.create(:orchestration_template, :ems_ref => "md5hashed")
        # prepare the query with different name and description; it is considered the same template
        # because the body (:template and :ems_ref) does not change
        @query_hash = @existing_record.as_json.symbolize_keys
        @query_hash[:name]        = "renamed"
        @query_hash[:description] = "modified description"
      end

      it "finds the existing template regardless the new name or description" do
        record = OrchestrationTemplate.find_or_create_by_contents([@query_hash])[0]
        record.id.should          == @existing_record.id
        record.name.should        == @existing_record.name
        record.template.should    == @existing_record.template
        record.description.should == @existing_record.description
      end
    end
  end

  describe "template in use" do
    before do
      @template_alone      = FactoryGirl.create(:orchestration_template)
      @template_with_stack = FactoryGirl.create(:orchestration_template_with_stacks)
    end

    it "knows whether a template is in use" do
      @template_alone.in_use?.should be_false
      @template_with_stack.in_use?.should be_true
    end

    it "finds all templates that are in use" do
      returned_templates = OrchestrationTemplate.find_all_in_use
      returned_templates[0].should == @template_with_stack
    end

    it "finds alll templates that are not in use" do
      returned_templates = OrchestrationTemplate.find_all_not_in_use
      returned_templates[0].should == @template_alone
    end
  end
end
