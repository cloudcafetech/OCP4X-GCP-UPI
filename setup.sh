#!/bin/bash
# Setting GCP Project for OCP

CTX=ocp4gcp
DOMAIN=cloudcafe.tech
OCPVER=4.14.34
OCPVERM=4.14
REGION=asia-northeast1
PULLSECRET='copy-and-paste-secret-file'
gcp_project="$CTX"-project


###### GCP Cloud Setup #######
gcpsetup() {

# APIs enable for OCP GCP Project
echo - Enabling APIs for OCP GCP Project
gcloud services enable compute.googleapis.com --project "$gcp_project"
gcloud services enable cloudapis.googleapis.com --project "$gcp_project"
gcloud services enable cloudresourcemanager.googleapis.com --project "$gcp_project"
gcloud services enable dns.googleapis.com --project "$gcp_project"
gcloud services enable iamcredentials.googleapis.com --project "$gcp_project"
gcloud services enable iam.googleapis.com --project "$gcp_project"
gcloud services enable servicemanagement.googleapis.com --project "$gcp_project"
gcloud services enable serviceusage.googleapis.com --project "$gcp_project"
gcloud services enable storage-api.googleapis.com --project "$gcp_project"
gcloud services enable storage-component.googleapis.com --project "$gcp_project"

gcloud config set project "$gcp_project"

# Create service account & Change permission of new service account to the role “owner”.
echo - Creating service account and change permission
echo $HOME
mkdir -p ~/.gcp
gcloud iam service-accounts create "$CTX"-sa
gcloud projects add-iam-policy-binding "$gcp_project" --member 'serviceAccount:"$CTX"-sa@"$gcp_project".iam.gserviceaccount.com' --role "roles/owner"

# Downloaded json key
gcloud iam service-accounts keys create $HOME/.gcp/osServiceAccount.json --iam-account "$CTX"-sa@"$gcp_project".iam.gserviceaccount.com

# Create Network (VPC)
echo - Creating VPC Network
gcloud compute networks create "$CTX"-network --subnet-mode=custom
gcloud compute networks describe "$CTX"-network
gcloud compute networks subnets create "$CTX"-master-subnet --network="$CTX"-network --range=10.1.10.0/24 --region=$REGION --enable-private-ip-google-access --enable-flow-logs=false
gcloud compute networks subnets create "$CTX"-worker-subnet --network="$CTX"-network --range=10.1.20.0/24 --region=$REGION --enable-private-ip-google-access --enable-flow-logs=false

# Create Firewall Rule to allow all traffic communication to & from bastion host
echo - Creating Firewall Rule to allow all traffic to and from bastion host
gcloud compute firewall-rules create allow-all-bastion --direction=INGRESS --priority=100 --network="$CTX"-network --target-tags=bastion --source-ranges=0.0.0.0/0 --action=ALLOW --rules=all --enable-logging=false

# Create Cloud Router
echo - Creating Cloud Router
gcloud compute routers create "$CTX"-route --network="$CTX"-network --region=$REGION --advertisement-mode=DEFAULT

# Create NAT components connected to the router for two subnets
echo - Creating NAT for two subnets connected to the router
gcloud compute routers nats create "$CTX"-nat-master-gw --router="$CTX"-route --nat-custom-subnet-ip-ranges="$CTX"-master-subnet --region=$REGION
gcloud compute routers nats create "$CTX"-nat-worker-gw --router="$CTX"-route --nat-custom-subnet-ip-ranges="$CTX"-worker-subnet --region=$REGION

# Create Private DNS zone
echo - Creating Private DNS zone
gcloud dns managed-zones create "$CTX"-private-zone --dns-name="$CTX.$DOMAIN" --description="OCP Private Zone" --visibility="private" --network="$CTX"-network
}

###### OCP Setup #######

toolsetup() {

# Download and extract OCP binary & COREOS Image
echo - # Download and extract OCP binary COREOS Image
curl -s -o rhcos-gcp-x86_64.tar.gz https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/$OCPVERM/$OCPVER/rhcos-$OCPVER-x86_64-gcp.x86_64.tar.gz
curl -s -o openshift-install-linux.tar.gz https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/$OCPVER/openshift-install-linux.tar.gz
curl -s -o openshift-client-linux.tar.gz https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/$OCPVER/openshift-client-linux.tar.gz
tar xvf openshift-install-linux.tar.gz
tar xvf openshift-client-linux.tar.gz
mv oc kubectl openshift-install /usr/local/bin/
rm -rf openshift-install-linux.tar.gz
rm -rf openshift-client-linux.tar.gz
curl -s -o install-config.yaml https://raw.githubusercontent.com/cloudcafetech/OCP4X-GCP-UPI/main/sample-install-config.yaml

# Clone GIT repository
#git clone https://github.com/cloudcafetech/OCP4X-GCP-UPI.git
#cp ~/OCP4X-GCP-UPI/scripts/* ~/ 
}

###### Generate SSH Keys, Manifests and Ignition files
manifes() {

# Generate SSH Key
echo - Generating SSH Key
ssh-keygen -q -t rsa -N '' -f ~/.ssh/id_rsa <<<y >/dev/null 2>&1
PUBKEY=`cat ~/.ssh/id_rsa.pub`
echo $PUBKEY

# Create an installation directory which will be used to generate the manifests & ignition config files.
mkdir ocp4-install

# Prepare install-config.yaml file into the installation directory
cat <<EOF > ~/ocp4-install/install-config.yaml
apiVersion: v1
baseDomain: $DOMAIN #Change this value to your base domain 
compute:
- architecture: amd64
  hyperthreading: Enabled
  name: worker
  replicas: 2
controlPlane:
  architecture: amd64
  hyperthreading: Enabled
  name: master
  replicas: 3
metadata:
  creationTimestamp: null
  name: $CTX # clustername 
networking:
  clusterNetwork:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  machineNetwork:
  - cidr: 10.1.0.0/16
  networkType: OVNKubernetes
  serviceNetwork:
  - 172.30.0.0/16
platform:
  gcp:
    projectID: $gcp_project # GCP Project ID
    network: "$CTX"-network # GCP network (VPC)
    region: $REGION # Region
    controlPlaneSubnet: "$CTX"-master-subnet # Master subnet
    computeSubnet: "$CTX"-worker-subnet # Worker subnet
publish: Internal
fips: false
pullSecret: 'PULL_SECRET'  
sshKey: "ssh-rsa PUBLIC_SSH_KEY"  
EOF

sed -i "s%PULL_SECRET%$PULLSECRET%" ~/ocp4-install/install-config.yaml
sed -i "s%ssh-rsa PUBLIC_SSH_KEY%$PUBKEY%" ~/ocp4-install/install-config.yaml
cp ~/ocp4-install/install-config.yaml ~/ocp4-install/install-config.yaml-bak
cp ~/ocp4-install/install-config.yaml /root/install-config.yaml

# Create the manifest files for your OpenShift cluster
openshift-install create manifests --dir ocp4-install/

# Manifests need some changes
sed -i 's/mastersSchedulable: true/mastersSchedulable: false/' ~/ocp4-install/manifests/cluster-scheduler-02-config.yml
#ocp4-install/manifests/cluster-ingress-default-ingresscontroller.yaml

# Remove the manifest files for the worker & master machines, as we will be creating the master & worker nodes using the Deployment Manager templates.
rm -f ocp4-install/openshift/99_openshift-cluster-api_master-machines-*
rm -f ocp4-install/openshift/99_openshift-cluster-api_worker-machineset-*

# Create the ignition config files
openshift-install create ignition-configs --dir ocp4-install/
}

# Install ALL
setupall () {

gcpsetup
toolsetup
manifes
}

case "$1" in
    'gcpsetup')
            gcpsetup
            ;;
    'toolsetup')
            toolsetup
            ;;
    'manifes')
            manifes
            ;;
    'setupall')
            setupall
            ;;
    *)
            clear
            echo
            echo "Usage: $0 { gcpsetup | toolsetup | manifes | setupall }"
            echo
            exit 1
            ;;
esac

exit 0
