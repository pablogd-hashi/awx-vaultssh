#Adding appRole capabilities
path "auth/approle/role/awx-role/role-id" {
  capabilities = ["read"]
}

path "auth/approle/role/awx-role/secret-id" {
  capabilities = ["update"]
}

#SSH engine 
path "ssh-client-signer/sign/awx-role" {
  capabilities = ["create", "update"]
}

path "ssh-client-signer/issue/awx-role" {
  capabilities = ["create", "update"]
}
