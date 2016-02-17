def pre_validate()
  $evm.root['Phase'] = "pre_validate"
  $evm.log(:info, "********************** resources pre validation ***************************")

  #TODO: decide what the pre-validation should include (keep in mind openshif-ansible pre validation)
  $evm.root['ae_result'] = "ok"
  $evm.root['Message'] = "successfuly pre-validation"
end

pre_validate()