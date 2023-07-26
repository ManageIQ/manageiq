RSpec.describe MiqPolicy::ImportExport do
  describe ".import" do
    it "imports" do
      fd = StringIO.new(<<~YAML)
        - MiqPolicy:
            name: analyse incoming container images
            description: Analyse incoming container images
            expression:
            towhat: ContainerImage
            guid: e7a270bc-109b-11e6-86ba-02424d459b45
            created_by: admin
            updated_by: admin
            notes:
            active: true
            mode: control
            read_only: true
            MiqPolicyContent:
            - qualifier: success
              success_sequence: 1
              failure_sequence: 1
              failure_synchronous: true
              MiqEventDefinition:
                name: containerimage_created
                description: Container Image Discovered
                guid: ab5c4cf5-4e71-43f8-964c-6446d9db10ec
                event_type: Default
                definition:
                default:
                enabled:
              MiqAction:
                name: container_image_analyze
                description: Initiate SmartState Analysis for Container Image
                guid: 0ac47229-b8dd-49f7-9051-45a4ada5b709
                action_type: default
                options: {}
            Condition:
            - name: Do not scan image-inspector's image
              description: Don't scan image-inspector's image
              expression: !ruby/object:MiqExpression
                exp:
                  not:
                    ENDS WITH:
                      field: ContainerImage-name
                      value: "/image-inspector"
                context_type:
              towhat: ContainerImage
              file_mtime:
              guid: e744245a-3d08-11e6-8d39-02422087d789
              filename:
              applies_to_exp:
              miq_policy_id:
              notes:
              read_only: true
      YAML

      MiqPolicy.import(fd, :save => true)

      expect(MiqPolicy.count).to eq(1)

      policy = MiqPolicy.first
      expect(policy).to have_attributes(
        :name        => "analyse incoming container images",
        :description => "Analyse incoming container images",
        :expression  => nil,
        :towhat      => "ContainerImage",
        :guid        => "e7a270bc-109b-11e6-86ba-02424d459b45",
        :created_by  => "admin",
        :updated_by  => "admin",
        :notes       => nil,
        :active      => true,
        :mode        => "control",
        :read_only   => true
      )

      expect(policy.conditions.size).to eq(1)
      condition = policy.conditions.first
      expect(condition).to have_attributes(
        :name           => "Do not scan image-inspector's image",
        :description    => "Don't scan image-inspector's image",
        :towhat         => "ContainerImage",
        :file_mtime     => nil,
        :guid           => "e744245a-3d08-11e6-8d39-02422087d789",
        :filename       => nil,
        :applies_to_exp => nil,
        :miq_policy_id  => nil,
        :notes          => nil,
        :read_only      => true
      )

      expression = condition.expression
      expect(expression).to be_a(MiqExpression)
      expect(expression.exp).to eq({"not" => {"ENDS WITH" => {"field" => "ContainerImage-name", "value" => "/image-inspector"}}})
    end
  end

  context '.import_from_hash' do
    it "loads attributes" do
      p_hash = {
        "name"             => "t_name",
        "description"      => "t_description",
        "expression"       => nil,
        "towhat"           => "ContainerImage",
        "guid"             => "e7a270bc-109b-11e6-86ba-02424d459b45",
        "mode"             => "control",
        "read_only"        => true,
        "MiqPolicyContent" => []
      }
      policy, _status = MiqPolicy.import_from_hash(p_hash)
      expect(policy).to have_attributes(p_hash.except("MiqPolicyContent"))
    end

    it "creates an active policy when the 'active' attribute is missing" do
      policy, _status = MiqPolicy.import_from_hash("MiqPolicyContent" => [])
      expect(policy.active).to be_truthy
    end

    it "creates an inactive policy when the 'active' attribute is true" do
      policy, _status = MiqPolicy.import_from_hash("active" => true, "MiqPolicyContent" => [])
      expect(policy.active).to be_truthy
    end

    it "creates an inactive policy when the 'active' attribute is false" do
      policy, _status = MiqPolicy.import_from_hash("active" => false, "MiqPolicyContent" => [])
      expect(policy.active).to be_falsey
    end
  end
end
