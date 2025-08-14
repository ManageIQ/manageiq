#/usr/bin/env bats

# This test file is for testing ansible-runner on a production appliance to verify
# that the real installation is working as expected. It is a duplicate of the tests
# in runner_execution_spec.rb but without the rspec and rspec-rails overhead.
#
# This test requires the Bats test framework to be installed
#   macOS: brew install bats-core
#   appliance: dnf install bats
# as well as the bats-support and bats-assert plugins installed
#   git clone https://github.com/bats-core/bats-support ~/.bats/libs/bats-support
#   git clone https://github.com/bats-core/bats-assert ~/.bats/libs/bats-assert

setup_file() {
  export BATS_LIB_PATH="$HOME/.bats/libs:$BATS_LIB_PATH"

  export PYTHON_VERSION="3.12"

  export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" >/dev/null 2>&1 && pwd)"
  export DATA_DIR="$SCRIPT_DIR/runner/data"
  export TEST_DIR="/tmp/ansible-runner-test"
  export ROLES_DIR="/tmp/ansible-runner-test-roles"
  export VAULT_FILE="$TEST_DIR/vault_password"
}

setup() {
  bats_load_library 'bats-support'
  bats_load_library 'bats-assert'

  rm -rf $TEST_DIR
  rm -rf $ROLES_DIR

  mkdir -p $TEST_DIR
}

teardown() {
  rm -rf $DATA_DIR/hello_world_with_requirements_github/roles/manageiq.example
}

setup_roles_dir() {
  # In prod builds, ansible-galaxy lives in the venv, so set up the PATH temporarily to install the roles
  PATH="/var/lib/manageiq/venv/bin:$PATH"

  roles_path="$1"
  source_role_file="${2:-$1/requirements.yml}"
  role_file="$roles_path/requirements.yml"
  if [ "$source_role_file" != "$role_file" ]; then
    mkdir -p $roles_path
    cp $source_role_file $role_file
  fi
  ansible-galaxy install --roles-path=$roles_path --role-file=$role_file

  PATH="${PATH#*:}"
}

################################################################################

exec_ansible_runner_cli() {
  PATH="/var/lib/manageiq/venv/bin:$PATH" \
    PYTHONPATH="/var/lib/manageiq/venv/lib/python${PYTHON_VERSION}/site-packages:/usr/local/lib64/python${PYTHON_VERSION}/site-packages:/usr/local/lib/python${PYTHON_VERSION}/site-packages:/usr/lib64/python${PYTHON_VERSION}/site-packages:/usr/lib/python${PYTHON_VERSION}/site-packages" \
    ansible-runner run $TEST_DIR --ident result --playbook $1 --project-dir $DATA_DIR
}

exec_ansible_runner_cli_role() {
  PATH="/var/lib/manageiq/venv/bin:$PATH" \
    PYTHONPATH="/var/lib/manageiq/venv/lib/python${PYTHON_VERSION}/site-packages:/usr/local/lib64/python${PYTHON_VERSION}/site-packages:/usr/local/lib/python${PYTHON_VERSION}/site-packages:/usr/lib64/python${PYTHON_VERSION}/site-packages:/usr/lib/python${PYTHON_VERSION}/site-packages" \
    ansible-runner run $TEST_DIR --ident result --role $1 --roles-path $ROLES_DIR --role-skip-facts --hosts localhost
}

@test "[ansible-runner] runs a playbook" {
  run exec_ansible_runner_cli hello_world.yml
  assert_success
  assert_output --partial '"msg": "Hello World!"'
}

@test "[ansible-runner] runs a playbook with variables in a vars file" {
  run exec_ansible_runner_cli hello_world_vars_file.yml
  assert_success
  assert_output --partial '"msg": "Hello World! vars_file_1=vars_file_1_value, vars_file_2=vars_file_2_value"'
}

@test "[ansible-runner] runs a playbook with vault encrypted variables" {
  echo -n "vault" >> $VAULT_FILE
  ANSIBLE_VAULT_PASSWORD_FILE=$VAULT_FILE run exec_ansible_runner_cli hello_world_vault_encrypted_vars.yml
  assert_success
  assert_output --partial '"msg": "Hello World! (NOTE: This message has been encrypted with ansible-vault)"'
}

@test "[ansible-runner] runs a playbook with variables in a vault encrypted vars file" {
  echo -n "vault" >> $VAULT_FILE
  ANSIBLE_VAULT_PASSWORD_FILE=$VAULT_FILE run exec_ansible_runner_cli hello_world_vault_encrypted_vars_file.yml
  assert_success
  assert_output --partial '"msg": "Hello World! vars_file_1=vars_file_1_value, vars_file_2=vars_file_2_value"'
}

@test "[ansible-runner] runs a playbook using roles from github" {
  setup_roles_dir $DATA_DIR/hello_world_with_requirements_github/roles

  run exec_ansible_runner_cli hello_world_with_requirements_github/hello_world_with_requirements_github.yml
  assert_success
  assert_output --partial '"msg": "Hello World! example_var='\''example var value'\''"'
}

@test "[ansible-runner] runs a role" {
  setup_roles_dir $ROLES_DIR $DATA_DIR/hello_world_with_requirements_github/roles/requirements.yml

  run exec_ansible_runner_cli_role manageiq.example
  assert_success
  assert_output --partial '"msg": "Hello from manageiq.example role! example_var='\''example var value'\''"'
}

@test "[ansible-runner] vmware collection" {
  if [ ! -d /var/lib/manageiq/venv ]; then
    skip "manageiq venv collections are not present"
  fi

  run exec_ansible_runner_cli vmware.yml
  assert_failure # We expect to this to fail due to connecting to an unknown vcenter
  assert_output --partial '"msg": "Unknown error while connecting to vCenter or ESXi API at vcenter_hostname:443 : [Errno -2] Name or service not known"'
}

@test "[ansible-runner] aws collection" {
  if [ ! -d /var/lib/manageiq/venv ]; then
    skip "manageiq venv collections are not present"
  fi

  run exec_ansible_runner_cli aws.yml
  assert_failure # We expect to this to fail due to connecting with bad creds
  assert_output --partial '"msg": "Failed to describe instances: An error occurred (AuthFailure) when calling the DescribeInstances operation: AWS was not able to validate the provided access credentials"'
}

################################################################################

exec_ansible_runner() {
  rails runner "resp = Ansible::Runner.run({}, {}, '$DATA_DIR/$1'); puts resp.human_stdout; exit resp.return_code"
}

exec_ansible_runner_role() {
  rails runner "resp = Ansible::Runner.run_role({}, {}, '$1', roles_path: '$ROLES_DIR'); puts resp.human_stdout; exit resp.return_code"
}

@test "[Ansible::Runner] runs a playbook" {
  run exec_ansible_runner hello_world.yml
  assert_success
  assert_output --partial '"msg": "Hello World!"'
}

@test "[Ansible::Runner] runs a playbook with variables in a vars file" {
  run exec_ansible_runner hello_world_vars_file.yml
  assert_success
  assert_output --partial '"msg": "Hello World! vars_file_1=vars_file_1_value, vars_file_2=vars_file_2_value"'
}

@test "[Ansible::Runner] runs a playbook with vault encrypted variables" {
  skip "requires database access"

  run exec_ansible_runner hello_world_vault_encrypted_vars.yml
  assert_success
  assert_output --partial '"msg": "Hello World! (NOTE: This message has been encrypted with ansible-vault)"'
}

@test "[Ansible::Runner] runs a playbook with variables in a vault encrypted vars file" {
  skip "requires database access"

  run exec_ansible_runner hello_world_vault_encrypted_vars_file.yml
  assert_success
  assert_output --partial '"msg": "Hello World! vars_file_1=vars_file_1_value, vars_file_2=vars_file_2_value"'
}

@test "[Ansible::Runner] runs a playbook using roles from github" {
  run exec_ansible_runner hello_world_with_requirements_github/hello_world_with_requirements_github.yml
  assert_success
  assert_output --partial '"msg": "Hello World! example_var='\''example var value'\''"'
}

@test "[Ansible::Runner] runs a role" {
  setup_roles_dir $ROLES_DIR $DATA_DIR/hello_world_with_requirements_github/roles/requirements.yml

  run exec_ansible_runner_role manageiq.example
  assert_success
  assert_output --partial '"msg": "Hello from manageiq.example role! example_var='\''example var value'\''"'
}

@test "[Ansible::Runner] vmware collection" {
  if [ ! -d /var/lib/manageiq/venv ]; then
    skip "manageiq venv collections are not present"
  fi

  run exec_ansible_runner vmware.yml
  assert_failure # We expect to this to fail due to connecting to an unknown vcenter
  assert_output --partial '"msg": "Unknown error while connecting to vCenter or ESXi API at vcenter_hostname:443 : [Errno -2] Name or service not known"'
}

@test "[Ansible::Runner] aws collection" {
  if [ ! -d /var/lib/manageiq/venv ]; then
    skip "manageiq venv collections are not present"
  fi

  run exec_ansible_runner aws.yml
  assert_failure # We expect to this to fail due to connecting with bad creds
  assert_output --partial '"msg": "Failed to describe instances: An error occurred (AuthFailure) when calling the DescribeInstances operation: AWS was not able to validate the provided access credentials"'
}
