# paperclip needs a bunch of AR defined to work
module PaperclipArMixin
  extend ActiveSupport::Concern

  included do
    # Paperclip required model work
    extend  ActiveModel::Callbacks
    extend  ActiveModel::Naming
    include ActiveModel::Model
    include Paperclip::Glue
    # Paperclip required callbacks
    define_model_callbacks :save, :only => [:after]
    define_model_callbacks :commit, :only => [:after]
    define_model_callbacks :destroy, :only => [:before, :after]
  end

  def new_record?
    false
  end

  module ClassMethods
    def save
      run_callbacks :save
      true
    end

    def destroy
      run_callbacks :destroy
    end
  end
end
