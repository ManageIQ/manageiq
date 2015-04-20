module MiqProvision::Ownership
  def set_ownership(vm, user)
    return if user.nil?

    _log.info "Setting Owning User to Name=#{user.name}, ID=#{user.id}"
    vm.evm_owner = user

    return if user.current_group.nil?

    _log.info "Setting Owning Group to Name=#{user.current_group.name}, ID=#{user.current_group.id}"
    vm.miq_group = user.current_group
  end
end
