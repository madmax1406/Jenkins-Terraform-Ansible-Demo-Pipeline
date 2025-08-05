# 🚀 How I Built Terraform & Ansible Automation CI/CD Pipeline on AWS using Jenkins

### A demo pipeline showcasing end-to-end infrastructure provisioning with Terraform, and configuration management with Ansible, all orchestrated by Jenkins for beginners.

#### 📊 Pipeline Overview

This pipeline is basically a way where developers can get a working EC2 instance created without intervention from the DevOps Team. It ensures the desired infrastructure is created in the right environment without giving AWS Console access to the devs.

The Jenkins pipeline is parameterized and takes below inputs from the user:

- Region (Where the resource should be deployed)
- Environment (dev, test)
- Number of Instances (How many do you want to deploy)

Once inputs are received, they're passed to Terraform which then initializes, validates, plans and applies the configuration. After EC2 instances are created, the pipeline moves to the Ansible stage which installs NGINX and displays our custom HTML page at: http://<ec2-public-ip>.

##### 📅 Tech Stack Overview

**1. Terraform**
    Provisions AWS resources:

- VPC, Subnet, Security Group (SSH & HTTP open)
- EC2 instances (key-pair, public IP)
- Uses modules with reusable variables.

**2. Jenkins**

Declarative pipeline (Jenkinsfile) with parameters:
    REGION, ENV, INSTANCE_COUNT

Stages:
- Clone repo
- Terraform init/plan/apply
- Extract public IPs
- Generate Ansible inventory
- SSH host key pre-scan
- Run Ansible playbook
- Publish outputs & archive state

**3. Ansible**

Installs and configures NGINX with a custom HTML page
Uses IPs extracted from Terraform output as dynamic inventory

🔧 Prerequisites

**AWS**

- IAM role or user with access to EC2, VPC, S3, and DynamoDB
- Key pair (e.g., jenkinskey) should be created in AWS EC2

**Jenkins**

- Should be installed on an EC2 instance (t2.large recommended)
- Port 8080 must be open in Security Group

**Credentials setup:**

- AWS credentials (either via IAM role or Jenkins UI)
- Ansible SSH key: ansible_ssh_key (type: SSH Username with private key)

**Tools on Jenkins Agent:**

Terraform >= 1.6.x
Ansible >= 2.9
AWS CLI
Git
Java

#### 📂 Jenkins Pipeline Breakdown

**1. Define Agent**
```
pipeline {
  agent any
```
We use agent any for simplicity, but ideally, use dedicated build agents.

**2. Define Parameters**
```
parameters {
  string(name: 'REGION', defaultValue: 'us-east-1', description: 'AWS region')
  string(name: 'ENV', defaultValue: 'dev', description: 'Environment (dev/test)')
  string(name: 'INSTANCE_COUNT', defaultValue: '1', description: 'Number of EC2 instances')
}
```
**3. Set Environment Variables**
```
environment {
  AWS_ACCESS_KEY    = credentials('aws_access_key')
  AWS_ACCESS_SECRET = credentials('aws_access_secret')
  TF_VAR_region = "${params.REGION}"
  TF_VAR_env = "${params.ENV}"
  TF_VAR_instance_count = "${params.INSTANCE_COUNT}"
}
```
**4. Clone Git Repository**
```
stage('Clone Repo') {
  steps {
    git branch: 'main', url: 'https://github.com/madmax1406/Jenkins-Terraform-Ansible-Demo-Pipeline.git'
  }
}
```
**5. Initialize Terraform**
```
stage('Initialise Terraform') {
  steps {
    sh '''
      rm -rf .terraform
      terraform init
    '''
  }
}
```
**6. Select or Create Workspace**
```
stage('Select Workspace') {
  steps {
    sh 'terraform workspace select $TF_VAR_env || terraform workspace new $TF_VAR_env'
  }
}
```
**7. Terraform Plan**
```
stage('Plan Infra') {
  steps {
    sh 'terraform validate'
    echo "Planning for workspace $TF_VAR_env"
    sh 'terraform plan -var="region=$TF_VAR_region" -var="instance_count=$TF_VAR_instance_count"'
  }
}
```
**8. Terraform Apply**
```
stage('Apply Infra') {
  steps {
    input message: 'Proceed with apply?'
    sh 'terraform apply -auto-approve -var="region=$TF_VAR_region" -var="instance_count=$TF_VAR_instance_count"'
  }
}
```
**9. Extract Public IPs from Output**
```
stage('Extract EC2 IPs') {
  steps {
    sh 'terraform output -json public_ip_for_ec2 | jq -r '.[]' > inventory_ips.txt'
  }
}
```
**10. Add Hosts to known_hosts**
```
stage('Add EC2 Host to known_hosts') {
  steps {
    sh '''
      EC2_IP=$(cat inventory_ips.txt | head -n 1)
      echo "Fetching SSH host key for $EC2_IP..."
      ssh-keyscan -H $EC2_IP >> ~/.ssh/known_hosts
    '''
  }
}
```
**11. Generate Ansible Inventory File**
```
stage('Generate Ansible Inventory ( Host File)') {
  steps {
    sh '''
      echo "[ec2_instances]" > hosts.ini
      cat inventory_ips.txt >> hosts.ini
    '''
  }
}
```
**12. Configure with Ansible**
```
stage('Configure with Ansible') {
  steps {
    withCredentials([sshUserPrivateKey(credentialsId: 'ansible_ssh_key', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {
      sh 'ansible-playbook -i hosts.ini playbook.yml --private-key "$SSH_KEY" -u "$SSH_USER"'
    }
  }
}
```
**13. Post Actions**
```
post {
  success {
    sh '''
      terraform output -json public_ip_for_ec2 | jq -r '.[]' > createdinstance_ip.txt
      echo 'The IP for your created EC2 machine are below:'
      cat createdinstance_ip.txt
    '''
  }
  always {
    archiveArtifacts artifacts: '**/terraform.tfstate*', fingerprint: true
  }
}
```
#### 🌐 Ansible Playbook Sample

```
- name: Install and configure Nginx to load static HTML Page
  hosts: all
  become: true

  tasks:
    - name: Install nginx
      apt:
        name: nginx
        state: latest
        update_cache: yes

    - name: Ensure nginx is running and enabled at boot
      service:
        name: nginx
        state: started
        enabled: yes

    - name: Create custom index.html file
      copy:
        content: |
          <html>
            <head><title>Welcome to DevOps</title></head>
            <body>
              <h1>Jenkins Terraform Ansible Demo 🚀</h1>
            </body>
          </html>
        dest: /var/www/html/index.html
        owner: www-data
        group: www-data
        mode: '0644'
```
#### 📈 Output

Once the pipeline completes, you'll get an IP printed in the Jenkins console. 
Open http://<public-ip> in browser , you’ll see your custom DevOps welcome page! ✅

####🛡️ Security Considerations (Best Practices)

- Avoid committing .tfvars to Git (use .gitignore)
- Use IAM roles for Jenkins EC2 (instead of hardcoding AWS keys)
- Use Ansible Vault to encrypt secrets (if passing them in playbooks)
- Harden EC2 Security Groups — open only needed ports (e.g., 22 and 80)
- Use remote backend for Terraform state (S3 + DynamoDB locking)

####🔎 Conclusion

If you've followed everything above, your full CI/CD pipeline using Jenkins + Terraform + Ansible should be green ✅.
“Don’t stop learning. If things don’t work, debug, experiment, and stay open-minded.”
Check out my GitHub repo here for the full project.

Kudos if you made it this far! 🚀😊
