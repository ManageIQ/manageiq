class MiqWidgetSet < ApplicationRecord
  acts_as_miq_set

  before_destroy :destroy_user_versions
  before_save    :keep_group_when_saving

  WIDGET_DIR =  File.expand_path(File.join(Rails.root, "product/dashboard/dashboards"))

  def self.default_dashboard
    find_by(:name => 'default', :read_only => true)
  end

  def self.with_users
    where.not(:userid => nil)
  end

  def destroy_user_versions
    # userid, group_id and name are set for user version
    # group_id, owner_type and owner_id are set for group version
    return if userid

    # When we destroy a WidgetSet for a group, we also want to destroy all user-modified versions
    MiqWidgetSet.with_users.where(:name => name, :group_id => owner_id).destroy_all
  end

  def self.destroy_user_versions
    MiqWidgetSet.with_users.destroy_all
  end

  def self.where_unique_on(name, user = nil)
    # user is nil for dashboards set for group
    userid = user.try(:userid)
    # a unique record is defined by name, group_id and userid
    if userid.present?
      where(:name => name, :group_id => user.current_group_id, :userid => userid)
    else
      where(:name => name, :userid => nil)
    end
  end

  def self.subscribed_for_user(user)
    where(:userid => user.userid)
  end

  def self.sync_from_dir
    Dir.glob(File.join(WIDGET_DIR, "*.yaml")).sort.each { |f| sync_from_file(f) }
  end

  def self.sync_from_file(filename)
    attrs = YAML.load_file(filename)

    ws = find_by(:name => attrs["name"])

    if ws.nil? || ws.updated_on.utc < File.mtime(filename).utc
      # Convert widget descriptions to ids in set_data
      members = []
      attrs["set_data"] = attrs.delete("set_data_by_description").inject({}) do |h, k|
        col, arr = k
        h[col] = arr.collect do |d|
          w = MiqWidget.find_by(:description => d)
          members << w if w
          w.try(:id)
        end.compact
        h
      end

      owner = attrs.delete("owner_description")
      attrs["owner_id"] = MiqGroup.find_by(:description => owner).try(:id) if owner
    end

    if ws
      if ws.updated_on.utc < File.mtime(filename).utc
        $log.info("Widget Set: [#{ws.description}] file has been updated on disk, synchronizing with model")
        ws.update!(attrs)
        ws.replace_children(members)
      end
    else
      $log.info("Widget Set: [#{attrs["description"]}] file has been added to disk, adding to model")
      ws = create(attrs)
      ws.replace_children(members)
    end
  end

  def self.copy_dashboard(source_widget_set, destination_name, destination_description, assign_to_group_id = nil)
    assign_to_group = MiqGroup.find(assign_to_group_id || source_widget_set.group_id || source_widget_set.owner_id)
    MiqWidgetSet.create!(:name        => destination_name,
                         :description => destination_description,
                         :owner_type  => "MiqGroup",
                         :set_type    => source_widget_set.set_type,
                         :set_data    => source_widget_set.set_data,
                         :owner_id    => assign_to_group.id)
  end

  def self.seed
    sync_from_dir
  end

  def self.find_with_same_order(ids)
    recs = where(:id => ids).index_by(&:id)
    ids.map { |id| recs[id.to_i] }
  end

  def self.display_name(number = 1)
    n_('Dashboard', 'Dashboards', number)
  end

  private

  def keep_group_when_saving
    self.group_id = owner_id if owner_type == "MiqGroup" && owner_id.present?
  end
end
