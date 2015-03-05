require "spec_helper"

describe OrchestrationTemplate do

  describe ".find_or_create_by_contents" do
    context "when the template does not exist" do
      let(:query_hash) { FactoryGirl.build(:orchestration_template).as_json.symbolize_keys }

      it "creates a new template" do
        OrchestrationTemplate.count.should == 0
        record = OrchestrationTemplate.find_or_create_by_contents(query_hash)[0]
        OrchestrationTemplate.count.should == 1
        record.name.should        == query_hash[:name]
        record.content.should     == query_hash[:content]
        record.description.should == query_hash[:description]
        record.ems_ref.should_not be_nil
      end
    end

    context "when the template already exists" do
      before do
        @existing_record = FactoryGirl.create(:orchestration_template)
        # prepare the query with different name and description; it is considered the same template
        # because the body (:template and :ems_ref) does not change
        @query_hash = @existing_record.as_json.symbolize_keys
        @query_hash[:name]        = "renamed"
        @query_hash[:description] = "modified description"
      end

      it "finds the existing template regardless the new name or description" do
        OrchestrationTemplate.count.should == 1
        @existing_record.should == OrchestrationTemplate.find_or_create_by_contents(@query_hash)[0]
        OrchestrationTemplate.count.should == 1
      end
    end
  end

  context "when both types of templates, either alone or with deployed stacks, are present" do
    before do
      # prepare a mini environment with an orphan template and a template with deployed stacks
      @template_alone      = FactoryGirl.create(:orchestration_template)
      @template_with_stack = FactoryGirl.create(:orchestration_template_with_stacks)
    end

    describe "#in_use?" do
      it "knows whether a template is in use" do
        @template_alone.in_use?.should      be_false
        @template_with_stack.in_use?.should be_true
      end
    end

    describe ".in_use" do
      it "finds all templates that are in use" do
        inused_templates = OrchestrationTemplate.in_use
        inused_templates.size.should == 1
        inused_templates[0].should == @template_with_stack
      end
    end

    describe ".not_in_use" do
      it "finds all templates that are never deployed" do
        alone_templates = OrchestrationTemplate.not_in_use
        alone_templates.size.should == 1
        alone_templates[0].should == @template_alone
      end
    end
  end

  describe "#eligible_managers" do
    before do
      OrchestrationTemplate.stub(:eligible_manager_types => [EmsAmazon, EmsOpenstack])
      @template = FactoryGirl.create(:orchestration_template)
      @aws = FactoryGirl.create(:ems_amazon)
      @openstack = FactoryGirl.create(:ems_openstack)
    end

    it "lists all eligible managers for a template" do
      @template.eligible_managers.should =~ [@aws, @openstack]
    end
  end

  describe "#validate_content" do
    before do
      @template = FactoryGirl.create(:orchestration_template)
      @manager = FactoryGirl.create(:ems_amazon)
      @manager.stub(:orchestration_template_validate => "Validation Message")
    end

    it "uses caller provided manager to do validation" do
      @template.validate_content(@manager).should == "Validation Message"
    end

    it "uses all eligible managers to do validation" do
      @template.stub(:eligible_managers => [@manager])
      @template.validate_content.should == "Validation Message"
    end

    it "gets an error message if no eligible managers" do
      @template.stub(:eligible_managers => ["Invalid Object"])
      @template.validate_content.should match(/No (.*) is capable to validate the template/)
    end
  end
end
