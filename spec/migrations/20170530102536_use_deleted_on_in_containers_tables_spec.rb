require_migration

describe UseDeletedOnInContainersTables do
  let(:container_definitions_stub) { migration_stub(:ContainerDefinition) }
  let(:container_groups_stub)      { migration_stub(:ContainerGroup) }
  let(:container_images_stub)      { migration_stub(:ContainerImage) }
  let(:container_projects_stub)    { migration_stub(:ContainerProject) }
  let(:containers_stub)            { migration_stub(:Container) }

  def create_before_migration_stub_data_for(model)
    model.create!(:ems_id => 10, :old_ems_id => nil)
    model.create!(:ems_id => 10, :old_ems_id => 10)
    model.create!(:ems_id => nil, :old_ems_id => 10, :deleted_on => Time.now.utc)
    model.create!(:ems_id => nil, :old_ems_id => 20, :deleted_on => Time.now.utc)
    model.create!(:ems_id => nil, :old_ems_id => nil, :deleted_on => Time.now.utc)
  end

  def create_after_migration_stub_data_for(model)
    model.create!(:ems_id => 10, :old_ems_id => nil)
    model.create!(:ems_id => 10, :old_ems_id => 10)
    model.create!(:ems_id => 10, :old_ems_id => 10, :deleted_on => Time.now.utc)
    model.create!(:ems_id => 20, :old_ems_id => 20, :deleted_on => Time.now.utc)
    model.create!(:ems_id => nil, :old_ems_id => nil, :deleted_on => Time.now.utc)
  end

  def assert_before_migration_data_of(model)
    expect(model.where.not(:deleted_on => nil).count).to eq 3
    expect(model.where(:deleted_on => nil).count).to eq 2
    expect(model.where(:ems_id => nil).count).to eq 3
    expect(model.where.not(:ems_id => nil).count).to eq 2
  end

  def assert_after_migration_data_of(model)
    expect(model.where.not(:deleted_on => nil).count).to eq 3
    expect(model.where(:deleted_on => nil).count).to eq 2
    expect(model.where(:ems_id => nil).count).to eq 1
    expect(model.where.not(:ems_id => nil).count).to eq 4
  end

  def assert_up_migration_for(model)
    create_before_migration_stub_data_for(model)

    assert_before_migration_data_of(model)
    migrate
    assert_after_migration_data_of(model)
  end

  def assert_down_migration_for(model)
    create_after_migration_stub_data_for(model)

    assert_after_migration_data_of(model)
    migrate
    assert_before_migration_data_of(model)
  end

  migration_context :up do
    it "Changes :ems_id => nil to :deleted_on => Time.now and set :ems_id using :old_ems_id for ContainerDefinition" do
      assert_up_migration_for(container_definitions_stub)
    end

    it "Changes :ems_id => nil to :deleted_on => Time.now and set :ems_id using :old_ems_id for ContainerGroup" do
      assert_up_migration_for(container_groups_stub)
    end

    it "Changes :ems_id => nil to :deleted_on => Time.now and set :ems_id using :old_ems_id for ContainerImages" do
      assert_up_migration_for(container_images_stub)
    end

    it "Changes :ems_id => nil to :deleted_on => Time.now and set :ems_id using :old_ems_id for ContainerProjects" do
      assert_up_migration_for(container_projects_stub)
    end

    it "Changes :ems_id => nil to :deleted_on => Time.now and set :ems_id using :old_ems_id for Containers" do
      assert_up_migration_for(containers_stub)
    end

    it "Fills up :deleted_on where missing" do
      # It's enough to d oa test for containers_stub, the rest are the same
      timestamp = Time.now.utc

      containers_stub.create!(:ems_id => nil, :old_ems_id => 10)
      containers_stub.create!(:ems_id => nil, :old_ems_id => 10, :deleted_on => nil)

      expect(containers_stub.where.not(:deleted_on => nil).count).to eq 0
      expect(containers_stub.where(:deleted_on => nil).count).to eq 2

      migrate

      expect(containers_stub.where.not(:deleted_on => nil).count).to eq 2
      expect(containers_stub.where(:deleted_on => nil).count).to eq 0
      containers_stub.all.each do |container|
        expect(container.deleted_on).to be >= timestamp
      end
    end
  end

  migration_context :down do
    it "Changes :deleted_on => Time.now to :ems_id => nil for ContainerDefinition" do
      assert_down_migration_for(container_definitions_stub)
    end

    it "Changes :deleted_on => Time.now to :ems_id => nil for ContainerGroup" do
      assert_down_migration_for(container_groups_stub)
    end

    it "Changes :deleted_on => Time.now to :ems_id => nil for ContainerImages" do
      assert_down_migration_for(container_images_stub)
    end

    it "Changes :deleted_on => Time.now to :ems_id => nil for ContainerProjects" do
      assert_down_migration_for(container_projects_stub)
    end

    it "Changes :deleted_on => Time.now to :ems_id => nil for Containers" do
      assert_down_migration_for(containers_stub)
    end
  end
end
