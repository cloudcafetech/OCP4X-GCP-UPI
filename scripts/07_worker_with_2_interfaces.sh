#!/bin/bash

generate_config() {
    local infra_id=$1
    local env_name=$2
    local root_volume_size=$3
    local image=$4
    local zone=$5
    local machine_type=$6
    local ignition=$7
    local compute_subnet=$8
    local additional_subnet=$9
    local service_account_email=${10}

    cat <<EOF
{
    "resources": [{
        "name": "${infra_id}-${env_name}",
        "type": "compute.v1.instance",
        "properties": {
            "disks": [{
                "autoDelete": true,
                "boot": true,
                "initializeParams": {
                    "diskSizeGb": ${root_volume_size},
                    "sourceImage": "${image}"
                }
            }],
            "machineType": "zones/${zone}/machineTypes/${machine_type}",
            "metadata": {
                "items": [{
                    "key": "user-data",
                    "value": "${ignition}"
                }]
            },
            "networkInterfaces": [
                {
                    "subnetwork": "${compute_subnet}"
                }, {
                    "subnetwork": "${additional_subnet}"
                }
            ],
            "serviceAccounts": [{
                "email": "${service_account_email}",
                "scopes": ["https://www.googleapis.com/auth/cloud-platform"]
            }],
            "tags": {
                "items": [
                    "${infra_id}-worker"
                ]
            },
            "zone": "${zone}"
        }
    }]
}
EOF
}

# Example usage
#generate_config "example-infra" "dev" 50 "projects/debian-cloud/global/images/family/debian-9" "us-central1-a" "n1-standard-1" "example-ignition" "default" "additional" "service-account@example.com"
