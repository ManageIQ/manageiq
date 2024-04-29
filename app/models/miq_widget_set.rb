class MiqWidgetSet < ApplicationRecord
  include SetData

  acts_as_miq_set

  before_destroy :ensure_can_be_destroyed
  before_destroy :destroy_user_versions
  before_destroy :delete_from_dashboard_order

  before_validation :keep_group_when_saving
  after_save        :add_to_dashboard_order
  after_save        :update_members

  validates :group_id, :presence => true, :unless => :read_only?

  validates :name, :format => {:with => /\A[^|]*\z/, :on => :create, :message => "cannot contain \"|\""}

  validates :description, :uniqueness_when_changed => {:scope   => [:owner_id, :userid],
                                                       :message => _("must be unique for this group and userid")}

  # group used to be for only group widgets, now it is for all widgets
  # so if you see conditional logic on group/group_id, chances are it is wrong. change to userid
  # userid, group_id and name are set for user version
  # group_id, owner_type and owner_id are set for group version
  belongs_to :group, :class_name => 'MiqGroup'

  scope :with_array_order, lambda { |ids, column = :id, column_type = :bigint|
    order = sanitize_sql_array(["array_position(ARRAY[?]::#{column_type}[], #{table_name}.#{column}::#{column_type})", ids])
    order(Arel.sql(order))
  }

  WIDGET_DIR = File.expand_path(Rails.root.join("product/dashboard/dashboards").to_s)

  def self.default_dashboard
    find_by(:name => 'default', :read_only => true)
  end

  def self.with_users
    where.not(:userid => nil)
  end

  def update_members
    replace_children(Array(set_data_widgets)) if members.map(&:id).sort != set_data_widgets.ids.sort
    current_user = User.current_user
    members.each { |w| w.create_initial_content_for_user(current_user.userid) } if current_user # Generate content if not there
  end

  # update the group's dashboard (only valid for non user dashboards)
  def add_to_dashboard_order
    return if user_version? || group.nil?

    group.add_to_dashboard_order(id)
    group.save
  end

  # update the group's dashboard (only valid for non user dashboards)
  def delete_from_dashboard_order
    return if user_version? || group.nil?

    group.delete_from_dashboard_order(id)
    group.save
  end

  def ensure_can_be_destroyed
    if read_only?
      errors.add(:base, _("Unable to delete read-only WidgetSet"))
      throw(:abort)
    end
  end

  # @return true for user version of a dashboard
  #         false for group dashboards
  def user_version?
    userid.present?
  end

  # destroy all related user versions (only valid for non user dashboards)
  def destroy_user_versions
    return if user_version?

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

    lookup_attributes = {}
    lookup_attributes[:name] = attrs["name"]
    lookup_attributes[:userid] = nil
    lookup_attributes[:read_only] = true

    ws = find_by(lookup_attributes)

    if ws.nil? || ws.updated_on.utc < File.mtime(filename).utc
      # Convert widget descriptions to ids in set_data
      members = []
      attrs["set_data"] = attrs.delete("set_data_by_description").each_with_object({}) do |k, h|
        col, arr = k
        h[col] = arr.collect do |d|
          w = MiqWidget.find_by(:description => d)
          members << w if w
          w.try(:id)
        end.compact
      end

      owner_description = attrs.delete("owner_description")
      owner = MiqGroup.find_by(:description => owner_description) if owner_description
      if owner
        attrs["owner_type"] = "MiqGroup"
        attrs["owner_id"] = owner.id
      end
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

  def self.display_name(number = 1)
    n_('Dashboard', 'Dashboards', number)
  end

  private

  def keep_group_when_saving
    self.group_id = owner_id if owner_type == "MiqGroup" && owner_id.present?
  end
end
