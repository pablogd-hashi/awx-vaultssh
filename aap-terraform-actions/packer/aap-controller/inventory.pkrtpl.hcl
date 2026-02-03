# AAP Inventory for Containerized Installation
# This file is templated by Packer during image build

[automationcontroller]
localhost ansible_connection=local

[all:vars]
admin_password='${aap_admin_password}'

# Controller settings
controller_hostname='${aap_hostname}'
controller_host='localhost'

# Container registry (uses Red Hat registry by default)
registry_url='registry.redhat.io'

# Database configuration (embedded PostgreSQL)
controller_pg_host='localhost'
controller_pg_port=5432
controller_pg_database='awx'
controller_pg_username='awx'
controller_pg_password='${aap_admin_password}'

# Redis configuration
redis_host='localhost'
redis_port=6379

# Don't require HTTPS verification for internal services
controller_tls_verify=false

# Installation options
automationcontroller_main=true
automationcontroller_rsyslog=true
