module PasswordMixin
  extend ActiveSupport::Concern

  included do
    class_attribute :encrypted_columns
    self.encrypted_columns = []
  end

  module ClassMethods
    def encrypt_column(column)
      # Given a column of "password", create 4 instance methods:
      #   password            : Get the password in plain text
      #   password=           : Set the password in plain text
      #   password_encrypted  : Get the password in cryptext
      #   password_encrypted= : Set the password in cryptext

      encrypted_columns << column.to_s
      encrypted_columns << "#{column}_encrypted"

      mod = generated_methods_for_password_mixin

      mod.send(:define_method, column) do
        val = send("#{column}_encrypted")
        val.blank? ? val : ManageIQ::Password.decrypt(val)
      end

      mod.send(:define_method, "#{column}=") do |val|
        val = ManageIQ::Password.try_encrypt(val) unless val.blank?
        send("#{column}_encrypted=", val)
      end

      mod.send(:define_method, "#{column}_encrypted") do
        read_attribute(column)
      end

      mod.send(:define_method, "#{column}_encrypted=") do |val|
        write_attribute(column, val)
      end
    end

    private

    def generated_methods_for_password_mixin
      @generated_methods_for_password_mixin ||= begin
        mod = const_set(:GeneratedMethodsForPasswordMixin, Module.new)
        include mod
        mod
      end
    end
  end
end
