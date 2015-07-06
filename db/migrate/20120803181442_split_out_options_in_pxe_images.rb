class SplitOutOptionsInPxeImages < ActiveRecord::Migration
  def up
    change_table :pxe_images do |t|
      t.string     :kernel,         :limit => 1024
      t.string     :kernel_options, :limit => 1024
      t.string     :initrd,         :limit => 1024
      t.remove     :options
    end
  end

  def down
    change_table :pxe_images do |t|
      t.remove     :kernel
      t.remove     :kernel_options
      t.remove     :initrd
      t.text       :options
    end
  end
end
