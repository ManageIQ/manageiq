class AddTypeToAuthentications < ActiveRecord::Migration

  class Authentication < ActiveRecord::Base
    self.inheritance_column = :_type_disabled    # disable STI
  end

  def up
    add_column :authentications, :type, :string

    say_with_time("Setting type for authenications") do
      Authentication.update_all(:type => 'AuthUseridPassword')
    end
  end

  def down
    say_with_time("Deleting non 'AuthUseridPassword' type authenications") do
      Authentication.where("type != 'AuthUseridPassword'").each(&:destroy)
    end

    remove_column :authentications, :type
  end

end
