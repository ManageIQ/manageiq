class DialogFieldAssociation < ActiveRecord::Base
  belongs_to :trigger, :class_name => :DialogField
  belongs_to :respond, :class_name => :DialogField
end
