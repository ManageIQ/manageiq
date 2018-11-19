describe OrchestrationTemplate do
  describe ".find_or_create_by_contents" do
    context "when the template does not exist" do
      let(:query_hash) { FactoryGirl.build(:orchestration_template).as_json.symbolize_keys }

      it "creates a new template" do
        expect(OrchestrationTemplate.count).to eq(0)
        record = OrchestrationTemplate.find_or_create_by_contents(query_hash)[0]
        expect(OrchestrationTemplate.count).to eq(1)
        expect(record.name).to eq(query_hash[:name])
        expect(record.content).to eq(query_hash[:content])
        expect(record.description).to eq(query_hash[:description])
        expect(record.md5).not_to be_nil
      end
    end

    context "when the template already exists" do
      before do
        @existing_record = FactoryGirl.create(:orchestration_template)
        # prepare the query with different name and description; it is considered the same template
        # because the body (:template and :md5) does not change
        @query_hash = @existing_record.as_json.symbolize_keys.except(:id)
        @query_hash[:name]        = "renamed"
        @query_hash[:description] = "modified description"
      end

      it "finds the existing template regardless the new name or description" do
        expect(OrchestrationTemplate.count).to eq(1)
        expect(@existing_record).to eq(OrchestrationTemplate.find_or_create_by_contents(@query_hash)[0])
        expect(OrchestrationTemplate.count).to eq(1)
      end

      it "creates a draft template even though the content is a duplicate" do
        expect(OrchestrationTemplate.count).to eq(1)
        @query_hash[:draft] = true
        expect(@existing_record).not_to eq(OrchestrationTemplate.find_or_create_by_contents(@query_hash)[0])
        expect(OrchestrationTemplate.count).to eq(2)
      end

      it "uses subclass if type is present" do
        expect(ManageIQ::Providers::Vmware::CloudManager::OrchestrationTemplate).to receive(:calc_md5).at_least(:once)
        expect(described_class).not_to receive(:calc_md5)

        @query_hash[:draft] = false
        @query_hash[:type] = ManageIQ::Providers::Vmware::CloudManager::OrchestrationTemplate.name
        OrchestrationTemplate.find_or_create_by_contents(@query_hash)
      end

      it "uses parent if type is not present" do
        expect(described_class).to receive(:calc_md5).at_least(:once)

        @query_hash[:draft] = false
        @query_hash[:type] = nil
        OrchestrationTemplate.find_or_create_by_contents(@query_hash)
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
        expect(@template_alone.in_use?).to      be_falsey
        expect(@template_with_stack.in_use?).to be_truthy
      end
    end

    describe ".in_use" do
      it "finds all templates that are in use" do
        inused_templates = OrchestrationTemplate.in_use
        expect(inused_templates.size).to eq(1)
        expect(inused_templates[0]).to eq(@template_with_stack)
      end
    end

    describe ".not_in_use" do
      it "finds all templates that are never deployed" do
        alone_templates = OrchestrationTemplate.not_in_use
        expect(alone_templates.size).to eq(1)
        expect(alone_templates[0]).to eq(@template_alone)
      end
    end

    describe ".destroy" do
      it "allows only stand alone template to be destroyed" do
        expect(@template_alone.destroy).to      be_truthy
        expect(@template_with_stack.destroy).to be_falsey
      end
    end
  end

  describe "#eligible_managers" do
    let!(:miq_server)  { EvmSpecHelper.local_miq_server }
    let(:user_admin)   { FactoryGirl.create(:user_admin) }
    let(:tenant)       { FactoryGirl.create(:tenant) }
    let(:other_tenant) { FactoryGirl.create(:tenant) }
    let!(:user)        { FactoryGirl.create(:user_with_group, :tenant => tenant) }

    before do
      allow(OrchestrationTemplate).to receive_messages(:eligible_manager_types =>
                                                         [ManageIQ::Providers::Amazon::CloudManager,
                                                          ManageIQ::Providers::Openstack::CloudManager])
      @template = FactoryGirl.create(:orchestration_template)
      @aws = FactoryGirl.create(:ems_amazon, :tenant => other_tenant)
      @openstack = FactoryGirl.create(:ems_openstack, :tenant => tenant)
    end

    it "lists all eligible managers for a template" do
      User.with_user(user_admin) do
        expect(@template.eligible_managers).to match_array([@aws, @openstack])
      end
    end

    it "lists all eligible managers for a template regard to user's tenant" do
      User.with_user(user) do
        expect(@template.eligible_managers).to match_array([@openstack])
      end
    end
  end

  describe "#validate_content" do
    before do
      @template = FactoryGirl.create(:orchestration_template)
      @manager = FactoryGirl.create(:ems_amazon)
      allow(@manager).to receive_messages(:orchestration_template_validate => "Validation Message")
    end

    it "uses caller provided manager to do validation" do
      expect(@template.validate_content(@manager)).to eq("Validation Message")
    end

    it "uses all eligible managers to do validation" do
      allow(@template).to receive_messages(:eligible_managers => [@manager])
      expect(@template.validate_content).to eq("Validation Message")
    end

    it "gets an error message if no eligible managers" do
      allow(@template).to receive_messages(:eligible_managers => ["Invalid Object"])
      expect(@template.validate_content).to match(/No (.*) is capable to validate the template/)
    end
  end

  describe "#draft=" do
    context "when existing record is not a draft" do
      let(:existing_template) { FactoryGirl.create(:orchestration_template, :draft => false) }

      it "allows duplicated draft record to be added" do
        dup_template = existing_template.dup
        dup_template.update_attributes!(:draft => true)
      end

      it "forbids duplicated final record from being added" do
        dup_template = existing_template.dup
        dup_template.draft = false
        expect { dup_template.save! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context "when existing record is a draft" do
      let(:existing_template) { FactoryGirl.create(:orchestration_template, :draft => true) }

      it "allows duplicated draft record to be added" do
        dup_template = existing_template.dup
        dup_template.update_attributes!(:draft => true)
      end

      it "allows duplicated final record to be added" do
        dup_template = existing_template.dup
        dup_template.update_attributes!(:draft => false)
      end
    end
  end

  describe ".find_with_content" do
    it "avoids content comparison but through content hash value comparison" do
      existing_template = FactoryGirl.create(:orchestration_template)
      allow(Digest::MD5).to receive(:hexdigest).and_return(existing_template.md5)

      result = OrchestrationTemplate.find_with_content("#{existing_template.content} content changed")
      expect(result).to eq(existing_template)
    end
  end

  context "when content has non-universal newlines" do
    let(:raw_text) { "abc\r\nxyz\r123\nend" }
    let(:content) { "abc\nxyz\n123\nend\n" }
    let(:existing_template) { FactoryGirl.create(:orchestration_template, :content => raw_text) }

    it "stores content with universal newlines" do
      expect(existing_template.content).to eq(content)
    end

    it "is retrievable through either raw or normalized content" do
      expect(existing_template).to eq(OrchestrationTemplate.find_with_content(raw_text))
      expect(existing_template).to eq(OrchestrationTemplate.find_with_content(content))
    end

    it "does not save a new template if the request has either the raw or normalized content" do
      expect(existing_template).to eq(OrchestrationTemplate.find_or_create_by_contents(:content => raw_text)[0])
      expect(existing_template).to eq(OrchestrationTemplate.find_or_create_by_contents(:content => content)[0])
      expect(OrchestrationTemplate.count).to eq(1)
    end
  end

  describe ".save_as_orderable!" do
    let(:content) { "content of the test template" }
    let(:existing_orderable_template) do
      FactoryGirl.create(:orchestration_template, :content => content, :orderable => true)
    end
    let(:existing_discovered_template) do
      FactoryGirl.create(:orchestration_template, :content => content, :orderable => false)
    end

    context "save new template" do
      let(:template) { FactoryGirl.build(:orchestration_template, :content => content) }

      context "when format validation fails" do
        it "raises an error showing the failure reason" do
          allow(template).to receive_messages(:validate_format => "format is invalid")
          expect { template.save_as_orderable! }
            .to raise_error(MiqException::MiqParsingError, "format is invalid")
        end
      end

      context "when format validation passes" do
        it "saves the template" do
          allow(template).to receive_messages(:validate_format => nil)
          expect(template.save_as_orderable!).to be_truthy
        end
      end

      context "when the template is draft" do
        it "always saves the template" do
          template.draft = true
          allow(template).to receive_messages(:validate_format => "format is invalid")
          expect(template.save_as_orderable!).to be_truthy
        end
      end

      context "when conflicts with existing orderable template" do
        before { existing_orderable_template }

        it "raises an error" do
          allow(template).to receive_messages(:validate_format => nil)
          expect { template.save_as_orderable! }.to raise_error(ActiveRecord::RecordInvalid)
        end
      end

      context "when conflicts with existing discovered template" do
        before { existing_discovered_template }

        it "updates the existing template" do
          allow(template).to receive_messages(:validate_format => nil)
          expect(template.save_as_orderable!).to be_truthy
          expect(template).to have_attributes(:id => existing_discovered_template.id, :orderable => true)
        end
      end
    end

    context "modify and save an existing template" do
      let(:template) { FactoryGirl.create(:orchestration_template, :content => "old content") }

      before { template.content = content }

      context "when conflicts with existing orderable template" do
        before { existing_orderable_template }

        it "raises an error" do
          allow(template).to receive_messages(:validate_format => nil)
          expect { template.save_as_orderable! }.to raise_error(ActiveRecord::RecordInvalid)
        end
      end

      context "when conflicts with existing discovered template" do
        let!(:stack) do
          FactoryGirl.create(:orchestration_stack_cloud, :orchestration_template => existing_discovered_template)
        end

        it "updates the stacks from the discovered template to use the working template" do
          allow(template).to receive_messages(:validate_format => nil)
          expect(template.save_as_orderable!).to be_truthy
          stack.reload
          expect(stack.orchestration_template.id).to eq(template.id)
          expect(described_class.find_by(:id => existing_discovered_template.id)).to be_nil
        end
      end

      context "when there is no conflict" do
        it "converts a discovered template to orderable" do
          allow(existing_discovered_template).to receive_messages(:validate_format => nil)
          expect(existing_discovered_template.orderable).to be_falsey
          expect(existing_discovered_template.save_as_orderable!).to be_truthy
          expect(existing_discovered_template.orderable).to be_truthy
        end
      end
    end
  end

  describe "#deployment_options" do
    it do
      options = subject.deployment_options
      assert_deployment_option(options[0], "stack_name", :OrchestrationParameterPattern, true)
    end
  end

  describe ".tabs" do
    it do
      expect(subject).to receive(:deployment_options).and_return('deployment-options')
      expect(subject).to receive(:parameter_groups).and_return('parameter-groups')
      expect(subject.tabs).to eq(
        [
          {
            :title        => 'Basic Information',
            :stack_group  => 'deployment-options',
            :param_groups => 'parameter-groups'
          }
        ]
      )
    end
  end

  def assert_deployment_option(option, name, constraint_type, required)
    expect(option.name).to eq(name)
    expect(option.required?).to eq(required)
    expect(option.constraints[0]).to be_kind_of("OrchestrationTemplate::#{constraint_type}".constantize)
  end
end
