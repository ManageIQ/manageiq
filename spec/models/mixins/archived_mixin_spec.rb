RSpec.describe ArchivedMixin do
  let(:model_name) { :container }
  let(:klass) { Container }

  let(:timestamp) { Time.now.utc }
  let(:active_model) { FactoryBot.create(model_name) }
  let(:archived_model) { FactoryBot.create(model_name, :deleted_on => timestamp) }

  describe ".archived" do
    it "fetches archived records" do
      active_model
      archived_model

      expect(klass.archived).to eq([archived_model])
    end
  end

  describe ".active" do
    it "fetches active records" do
      active_model
      archived_model

      expect(klass.active).to eq([active_model])
    end
  end

  describe ".not_archived_before" do
    it "detects active are in the range" do
      active_model
      expect(klass.not_archived_before(2.years.ago)).to eq([active_model])
    end

    it "detects not yet deleted records are in the range" do
      archived_model
      expect(klass.not_archived_before(2.years.ago)).to eq([archived_model])
    end

    it "detects already deleted records are not in the range" do
      archived_model
      expect(klass.not_archived_before(1.year.from_now)).to be_empty
    end

    # some associations have active as a default scope e.g.: ContainerProject#container_groups
    # this makes sure not_archived_before will override the scope
    it "overrides active scope" do
      archived_model
      expect(klass.active.not_archived_before(2.years.ago)).to eq([archived_model])
    end
  end

  describe "#archived?", "#archived" do
    it "detects not archived" do
      expect(active_model.archived?).to be false
    end

    it "detects archived" do
      expect(archived_model.archived?).to be true
    end
  end

  describe "#active", "#active?" do
    it "detects not active" do
      expect(archived_model.active?).to be false
    end

    it "detects active" do
      expect(active_model.active?).to be true
    end
  end

  describe "#archive!" do
    let(:model) { active_model }
    it "makes archived" do
      expect(model.archived?).to be false
      model.archive!
      expect(model.archived?).to be true
      expect(model.deleted_on).not_to be_nil
    end
  end

  describe "#unarchive!" do
    let(:model) { archived_model }
    it "makes unarchived" do
      expect(model.archived?).to be true
      model.unarchive!
      expect(model.archived?).to be false
      expect(model.deleted_on).to be_nil
    end
  end
end
