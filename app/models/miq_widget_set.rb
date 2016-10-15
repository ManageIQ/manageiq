class MiqWidgetSet < ApplicationRecord
  acts_as_miq_set

  before_destroy :destroy_user_versions

  WIDGET_DIR =  File.expand_path(File.join(Rails.root, "product/dashboard/dashboards"))

  def self.with_users
    where.not(:userid => nil)
  end

  def destroy_user_versions
    # userid, group_id and name are set for user version
    # owner_type and owner_id are set for group version
    return if userid

    # When we destroy a WidgetSet for a group, we also want to destroy all user-modified versions
    MiqWidgetSet.with_users.where(:name => name, :group_id => owner_id).destroy_all
  end

  def self.where_unique_on(name, user = nil)
    userid = user.try(:userid)
    group_id = user.try(:current_group_id)
    # a unique record is defined by name, group_id and userid
    where(:name => name, :group_id => group_id, :userid => userid)
  end

  def self.subscribed_for_user(user)
    where(:userid => user.userid)
  end

  def self.sync_from_dir
    Dir.glob(File.join(WIDGET_DIR, "*.yaml")).sort.each { |f| sync_from_file(f) }
  end

  def self.sync_from_file(filename)
    attrs = YAML.load_file(filename)

    ws = find_by_name(attrs["name"])

    if ws.nil? || ws.updated_on.utc < File.mtime(filename).utc
      # Convert widget descriptions to ids in set_data
      members = []
      attrs["set_data"] = attrs.delete("set_data_by_description").inject({}) do |h, k|
        col, arr = k
        h[col] = arr.collect do |d|
          w = MiqWidget.find_by_description(d)
          members << w if w
          w.try(:id)
        end.compact
        h
      end
    end

    if ws
      if ws.updated_on.utc < File.mtime(filename).utc
        $log.info("Widget Set: [#{ws.description}] file has been updated on disk, synchronizing with model")
        ws.update_attributes(attrs)
        ws.save
        ws.replace_children(members)
      end
    else
      $log.info("Widget Set: [#{attrs["description"]}] file has been added to disk, adding to model")
      ws = create(attrs)
      ws.replace_children(members)
    end
  end

  def self.seed
    sync_from_dir
  end

  def self.find_with_same_order(ids)
    recs = where(:id => ids).index_by(&:id)
    ids.map { |id| recs[id.to_i] }
  end
end
