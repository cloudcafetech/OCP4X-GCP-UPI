#!/bin/bash

generate_config() {
    local infra_id=$1
    local root_volume_size=$2
    local image=$3
    local machine_type=$4
    local ignition=$5
    local control_subnet=$6
    local service_account_email=$7
    local zones=("${!8}")

    cat <<EOF
resources:
- name: ${infra_id}-master-0
  type: compute.v1.instance
  properties:
    disks:
    - autoDelete: true
      boot: true
      initializeParams:
        diskSizeGb: ${root_volume_size}
        diskType: zones/${zones[0]}/diskTypes/pd-ssd
        sourceImage: ${image}
    machineType: zones/${zones[0]}/machineTypes/${machine_type}
    metadata:
      items:
      - key: user-data
        value: ${ignition}
    networkInterfaces:
    - subnetwork: ${control_subnet}
    serviceAccounts:
    - email: ${service_account_email}
      scopes:
      - https://www.googleapis.com/auth/cloud-platform
    tags:
      items:
      - ${infra_id}-master
    zone: ${zones[0]}
- name: ${infra_id}-master-1
  type: compute.v1.instance
  properties:
    disks:
    - autoDelete: true
      boot: true
      initializeParams:
        diskSizeGb: ${root_volume_size}
        diskType: zones/${zones[1]}/diskTypes/pd-ssd
        sourceImage: ${image}
    machineType: zones/${zones[1]}/machineTypes/${machine_type}
    metadata:
      items:
      - key: user-data
        value: ${ignition}
    networkInterfaces:
    - subnetwork: ${control_subnet}
    serviceAccounts:
    - email: ${service_account_email}
      scopes:
      - https://www.googleapis.com/auth/cloud-platform
    tags:
      items:
      - ${infra_id}-master
    zone: ${zones[1]}
- name: ${infra_id}-master-2
  type: compute.v1.instance
  properties:
    disks:
    - autoDelete: true
      boot: true
      initializeParams:
        diskSizeGb: ${root_volume_size}
        diskType: zones/${zones[2]}/diskTypes/pd-ssd
        sourceImage: ${image}
    machineType: zones/${zones[2]}/machineTypes/${machine_type}
    metadata:
      items:
      - key: user-data
        value: ${ignition}
    networkInterfaces:
    - subnetwork: ${control_subnet}
    serviceAccounts:
    - email: ${service_account_email}
      scopes:
      - https://www.googleapis.com/auth/cloud-platform
    tags:
      items:
      - ${infra_id}-master
    zone: ${zones[2]}
EOF
}

# Example usage
#infra_id="example-infra"
#root_volume_size="10"
#image="example-image"
#machine_type="n1-standard-1"
#ignition="example-ignition"
#control_subnet="example-subnet"
#service_account_email="example@example.com"
#zones=("zone-1" "zone-2" "zone-3")

#generate_config "$infra_id" "$root_volume_size" "$image" "$machine_type" "$ignition" "$control_subnet" "$service_account_email" zones[@]
