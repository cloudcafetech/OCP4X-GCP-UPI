#!/bin/bash

# Function to generate configuration
generate_config() {
    local infra_id=$1
    local region=$2
    local root_volume_size=$3
    local image=$4
    local zone=$5
    local machine_type=$6
    local bootstrap_ign=$7
    local control_subnet=$8
    local cluster_network=$9

    echo "Generating configuration for infra_id: $infra_id"

    # Create public IP address for bootstrap
    echo "Creating public IP address for bootstrap"
    gcloud compute addresses create "${infra_id}-bootstrap-public-ip" --region "$region"

    # Create bootstrap instance
    echo "Creating bootstrap instance"
    gcloud compute instances create "${infra_id}-bootstrap" \
        --zone "$zone" \
        --machine-type "$machine_type" \
        --subnet "$control_subnet" \
        --tags "${infra_id}-master,${infra_id}-bootstrap" \
        --metadata user-data="{\"ignition\":{\"config\":{\"replace\":{\"source\":\"$bootstrap_ign\"}},\"version\":\"3.1.0\"}}" \
        --image "$image" \
        --boot-disk-size "$root_volume_size" \
        --boot-disk-type "pd-standard" \
        --boot-disk-device-name "${infra_id}-bootstrap" \
        --address "${infra_id}-bootstrap-public-ip"

    # Create instance group for bootstrap
    echo "Creating instance group for bootstrap"
    gcloud compute instance-groups unmanaged create "${infra_id}-bootstrap-instance-group" --zone "$zone"
    gcloud compute instance-groups unmanaged set-named-ports "${infra_id}-bootstrap-instance-group" \
        --named-ports ignition:22623,https:6443 --zone "$zone"
}

# Example usage
#generate_config "my-infra" "us-central1" "10" "my-image" "us-central1-a" "n1-standard-1" "http://example.com/bootstrap.ign" "my-control-subnet" "my-cluster-network"
