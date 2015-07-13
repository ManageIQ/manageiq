class AddResourceToMiqWidgetContents < ActiveRecord::Migration
  class MiqWidgetContent < ActiveRecord::Base
    belongs_to :user
  end

  class User < ActiveRecord::Base
    belongs_to :miq_group

    serialize :settings, Hash

    # use the existing User#get_timezone but skip checking the server's configured timezone
    def get_timezone
      self.settings.fetch_path(:display, :timezone) || "UTC"
    end

    def self_service_user?
      return false if self.miq_group.nil?
      self.miq_group.self_service_group?
    end

    def limited_self_service_user?
      return false if self.miq_group.nil?
      self.miq_group.limited_self_service_group?
    end
  end

  class MiqGroup < ActiveRecord::Base
    belongs_to :miq_user_role

    def self_service_group?
      return false if self.miq_user_role.nil?
      self.miq_user_role.self_service_role?
    end

    def limited_self_service_group?
      return false if self.miq_user_role.nil?
      self.miq_user_role.limited_self_service_role?
    end
  end

  class MiqUserRole < ActiveRecord::Base
    serialize :settings

    def self_service_role?
      [:user_or_group, :user].include?((self.settings || {}).fetch_path(:restrictions, :vms))
    end

    def limited_self_service_role?
      (self.settings || {}).fetch_path(:restrictions, :vms) == :user
    end
  end

  def up
    add_column :miq_widget_contents, :owner_id,   :bigint
    add_column :miq_widget_contents, :owner_type, :string
    add_column :miq_widget_contents, :timezone,   :string

    contents = MiqWidgetContent.select([:id, :owner_type, :owner_id, :user_id]).includes(:user)

    contents.each do |c|
      user = c.user
      if user && (user.self_service_user? || user.limited_self_service_user? || user.miq_group.nil?)
        c.owner_id   = user.id
        c.owner_type = 'User'
      else
        c.owner_id   = user.miq_group.id if user
        c.owner_type = 'MiqGroup'
      end
      c.timezone   = user.get_timezone if user
      c.user_id    = nil
      c.save
    end

    add_index     :miq_widget_contents, :owner_id
    remove_index  :miq_widget_contents, :user_id
    remove_column :miq_widget_contents, :user_id
  end

  def down
    add_column :miq_widget_contents, :user_id, :bigint

    contents = MiqWidgetContent.select([:id, :owner_type, :owner_id, :user_id])
    contents.each do |content|
      if content.owner_type == 'User'
        content.update_attributes(:owner_id => nil, :owner_type => nil, :user_id => content.owner_id)
      else
        # Since we can't work out the owner and the value would just be deleted, it would be orphaned, so:
        content.destroy
      end
    end

    add_index     :miq_widget_contents, :user_id

    remove_index  :miq_widget_contents, :owner_id
    remove_column :miq_widget_contents, :owner_id
    remove_column :miq_widget_contents, :owner_type
    remove_column :miq_widget_contents, :timezone
  end
end
