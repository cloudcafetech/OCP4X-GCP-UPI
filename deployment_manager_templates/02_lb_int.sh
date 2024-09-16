#!/bin/bash

# Function to generate configuration
generate_config() {
    local infra_id=$1
    local region=$2
    local control_subnet=$3
    local cluster_network=$4
    shift 4
    local zones=("$@")

    echo "Generating configuration for infra_id: $infra_id"

    # Create backend groups
    for zone in "${zones[@]}"; do
        echo "Creating instance group for zone: $zone"
        gcloud compute instance-groups unmanaged create "${infra_id}-master-${zone}-instance-group" --zone "$zone"
        gcloud compute instance-groups unmanaged set-named-ports "${infra_id}-master-${zone}-instance-group" \
            --named-ports ignition:22623,https:6443 --zone "$zone"
    done

    # Create internal IP address
    echo "Creating internal IP address"
    gcloud compute addresses create "${infra_id}-cluster-ip" --region "$region" --subnet "$control_subnet" --addresses-type INTERNAL

    # Create health check
    echo "Creating health check"
    gcloud compute health-checks create https "${infra_id}-api-internal-health-check" \
        --port 6443 --request-path /readyz

    # Create backend service
    echo "Creating backend service"
    gcloud compute backend-services create "${infra_id}-api-internal-backend-service" \
        --load-balancing-scheme INTERNAL --region "$region" --protocol TCP --timeout 120s \
        --health-checks "${infra_id}-api-internal-health-check"

    for zone in "${zones[@]}"; do
        gcloud compute backend-services add-backend "${infra_id}-api-internal-backend-service" \
            --instance-group "${infra_id}-master-${zone}-instance-group" --instance-group-zone "$zone" --region "$region"
    done

    # Create forwarding rule
    echo "Creating forwarding rule"
    gcloud compute forwarding-rules create "${infra_id}-api-internal-forwarding-rule" \
        --load-balancing-scheme INTERNAL --region "$region" --ports 6443,22623 \
        --backend-service "${infra_id}-api-internal-backend-service" \
        --address "${infra_id}-cluster-ip" --subnet "$control_subnet"
}

# Example usage
#generate_config "my-infra" "us-central1" "my-control-subnet" "my-cluster-network" "us-central1-a" "us-central1-b"
