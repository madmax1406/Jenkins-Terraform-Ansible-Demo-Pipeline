// Jenkinsfile: Triggered via Build with Parameters to deploy infra using Terraform

pipeline {
agent any

parameters {
string(name: 'REGION', defaultValue: 'us-east-1', description: 'AWS region')
string(name: 'ENV', defaultValue: 'dev', description: 'Environment (dev/stage/prod)')
string(name: 'INSTANCE_COUNT', defaultValue: '2', description: 'Number of EC2 instances')
}

environment {
AWS_ACCESS_KEY    = credentials('aws_access_key')
AWS_ACCESS_SECRET = credentials('aws_access_secret')
TF_VAR_region = "${params.REGION}"
TF_VAR_env = "${params.ENV}"
TF_VAR_instance_count = "${params.INSTANCE_COUNT}"
}

stages {

stage('Clone Repo') {
steps {
git branch: 'main', url: 'https://github.com/madmax1406/Jenkins-Terraform-Ansible-Demo-Pipeline.git'
}
}
stage('Initialise Terraform') {
  steps {
    sh 'terraform init'
  }
}

stage('Select Workspace') {
  steps {
    sh '''
      terraform workspace select $TF_VAR_env || terraform workspace new $TF_VAR_env
    '''
  }
}

stage('Plan Infra') {
  steps {
    sh 'terraform plan -var="region=$TF_VAR_region" -var="instance_count=$TF_VAR_instance_count"'
  }
}

stage('Apply Infra') {
  steps {
    input message: 'Proceed with apply?'
    sh 'terraform apply -auto-approve -var="region=$TF_VAR_region" -var="instance_count=$TF_VAR_instance_count"'
  }
}

stage('Extract EC2 IPs') {
  steps {
    sh '''
      terraform output -json public_ip_for_ec2 | jq -r '.[]' > inventory_ips.txt
    '''
  }
}

stage('Generate Ansible Inventory ( Host File)') {
  steps {
    sh '''
      echo "[ec2_instances]" > hosts.ini
      cat inventory_ips.txt >> hosts.ini
    '''
  }
}

stage('Configure with Ansible') {
  steps {
    sh '''
      ansible-playbook -i hosts.ini playbook.yml --private-key ~/.ssh/your-key.pem
    '''
  }
}

}

post {
always {
archiveArtifacts artifacts: '**/terraform.tfstate*', fingerprint: true
}
}
}