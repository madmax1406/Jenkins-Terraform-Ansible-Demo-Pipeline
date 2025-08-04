🚀 How I Built Jenkins CI/CD Pipeline on AWS (And What I Learned)

A demo pipeline showcasing end-to-end infrastructure provisioning using Terraform, configuration management with Ansible, and orchestration via Jenkins for beginners.

---

## 🧩 Pipeline Overview

This pipeline is basically a way for developers to create working EC2 instances without needing DevOps team intervention or AWS console access. It ensures that infrastructure is created in the desired environment, automatically and securely.

The Jenkins pipeline is parameterized and takes the following inputs from the user:

1. **Region** : Where the resource should be deployed.
2. **Environment** : (dev, test , stage)
3. **Number of Instances** : How many EC2 instances to deploy.

Once the inputs are received, they’re passed to Terraform which initializes, validates, plans, and applies the configuration. Once the EC2 instances are created, the pipeline proceeds with the Ansible stage to install Nginx and display a custom HTML page when the EC2 public IP is accessed.

The Build Parameter screen looks like below to the users 

![image.png](attachment:81c68524-0fd3-4918-843d-d23f2cd3e1c0:image.png)

---

## 🔧 Prerequisites

### AWS

- IAM role/user with permissions for EC2, VPC, S3, and DynamoDB.
- Key pair created in EC2 (e.g., `jenkinskey`).

### Jenkins

- Installed and running on an EC2 instance (t2.large or higher preferred).
- Listens on port 8080.

### Jenkins Credentials

- **AWS**: Access key/secret or an IAM role attached to the instance.
- **SSH Key**: ID = `ansible_ssh_key`, Username = `ubuntu`, Private key = content of your `.pem` file used in EC2 creation.

### Tools Installed on Jenkins Host

- Terraform ≥ v1.6.x
- Ansible ≥ v2.9
- AWS CLI
- Git
- Java (for Jenkins)

---

## ⚙️ Technologies Used

### 1. **Terraform**

- Provisions AWS infrastructure:
    - VPC, Subnet, Security Group (SSH & HTTP open)
    - EC2 instances with key pair and public IP
- Uses modular and reusable variable structure.

### 2. **Jenkins**

- Declarative pipeline with input parameters:
    - `REGION`, `ENV`, `INSTANCE_COUNT`
- Key stages:
    1. Clone repo
    2. Terraform init/plan/apply
    3. Extract public IPs
    4. Generate Ansible inventory
    5. SSH host key pre-scan
    6. Ansible configuration
    7. Output EC2 IP and archive Terraform state

### 3. **Ansible**

- Installs and configures Nginx with a custom HTML page.
- Uses dynamic inventory created from Terraform output.

---

## 🧱 Step-by-Step Pipeline (Jenkinsfile)

Let’s walk through each part of the Jenkins pipeline:

### 1. Pipeline Header

```groovy
groovy
CopyEdit
pipeline {
  agent any

```

We choose `agent any` to run the job on the Jenkins master (for demo). In production, you'd use agents/slaves.

---

### 2. Input Parameters

```groovy
groovy
CopyEdit
parameters {
  string(name: 'REGION', defaultValue: 'us-east-1', description: 'AWS region')
  string(name: 'ENV', defaultValue: 'dev', description: 'Environment (dev/test/stage)')
  string(name: 'INSTANCE_COUNT', defaultValue: '1', description: 'Number of EC2 instances')
}

```

These parameters define how the infrastructure is created based on user input.

---

### 3. Environment Variables

```groovy
groovy
CopyEdit
environment {
  AWS_ACCESS_KEY    = credentials('aws_access_key')
  AWS_ACCESS_SECRET = credentials('aws_access_secret')
  TF_VAR_region     = "${params.REGION}"
  TF_VAR_env        = "${params.ENV}"
  TF_VAR_instance_count = "${params.INSTANCE_COUNT}"
}

```

Sensitive credentials are securely pulled from Jenkins’ credential store.

---

### 4. Stages

This is where all magic happens , we will now proceed defining stages of the pipeline , a stage is small set of task defined to segregate each operation being performed.

Lets start one by one 

### Stage: Clone Repo

```groovy
groovy
CopyEdit
stage('Clone Repo') {
  steps {
    git branch: 'main', url: 'https://github.com/madmax1406/Jenkins-Terraform-Ansible-Demo-Pipeline.git'
  }
}
```

---

### Stage: Initialize Terraform

This will initialize terraform in your current working directory , this command will work only if there is a [main.tf](http://main.tf) in your directory 

```groovy
groovy
CopyEdit
stage('Initialise Terraform') {
  steps {
    sh '''
      rm -rf .terraform
      terraform init
    '''
  }
}
```

---

### Stage: Select Workspace

Workspaces are very important to segregate the resources , this step  helps us select the workspace where the resource is to be deployed . Read more about Terraform workspaces HERE.

```groovy
groovy
CopyEdit
stage('Select Workspace') {
  steps {
    sh '''
      terraform workspace select $TF_VAR_env || terraform workspace new $TF_VAR_env
    '''
  }
}

```

---

### Stage: Plan Infra

This step basically gives you the plan about the infra its going to create as per your input 

```groovy
groovy
CopyEdit
stage('Plan Infra') {
  steps {
    sh 'terraform validate'
    echo "Planning for workspace $TF_VAR_env"
    sh 'terraform plan -var="region=$TF_VAR_region" -var="instance_count=$TF_VAR_instance_count"'
  }
}

```

---

### Stage: Apply Infra

If you are good with everything , this step will apply the infra , this step also contains gate stop asking whether to proceed or abort , it will prompt something like below 

![image.png](attachment:9e68dce6-2d75-4cd4-ae49-036e72f4e9ba:image.png)

```groovy
groovy
CopyEdit
stage('Apply Infra') {
  steps {
    input message: 'Proceed with apply?'
    sh 'terraform apply -auto-approve -var="region=$TF_VAR_region" -var="instance_count=$TF_VAR_instance_count"'
  }
}
```

---

![image.png](attachment:bdf336e7-e631-4fd0-883d-764b5501bf71:image.png)

![image.png](attachment:d1e3ade9-0554-434a-b369-a27da243ca8a:image.png)

### Stage: Extract EC2 IPs

Once your infra is created , terraform would output the public ip’s of the EC2 machines and then add these IP’s to the list of known hosts on Jenkins Master server so that it trusts these hosts . This is necessary so that in our next step when Ansible tries to SSH the servers it does so without any hassle 

```groovy
groovy
CopyEdit
stage('Extract EC2 IPs') {
  steps {
    sh '''
      terraform output -json public_ip_for_ec2 | jq -r '.[]' > inventory_ips.txt
    '''
  }
}

```

---

### Stage: Add EC2 Hosts to Known Hosts

```groovy
groovy
CopyEdit
stage('Add EC2 Host to known_hosts') {
  steps {
    sh '''
      EC2_IP=$(cat inventory_ips.txt | head -n 1)
      ssh-keyscan -H $EC2_IP >> ~/.ssh/known_hosts
    '''
  }
}

```

---

### Stage: Generate Ansible Inventory

This steps copies the IP’s to the host file required by Ansible 

```groovy
groovy
CopyEdit
stage('Generate Ansible Inventory (Host File)') {
  steps {
    sh '''
      echo "[ec2_instances]" > hosts.ini
      cat inventory_ips.txt >> hosts.ini
    '''
  }
}

```

---

### Stage: Configure with Ansible

```groovy
groovy
CopyEdit
stage('Configure with Ansible') {
  steps {
    withCredentials([sshUserPrivateKey(credentialsId: 'ansible_ssh_key', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {
      sh '''
        ansible-playbook -i hosts.ini playbook.yml --private-key "$SSH_KEY" -u "$SSH_USER"
      '''
    }
  }
}

```

---

![image.png](attachment:87711057-6ddb-4440-8eef-6db5d9a5fd71:image.png)

This step does the magic of installing nginx on our newly created hosts by terraform.

Here we are passing the ansible-ssh-key which we have configured in the Jenkins UI credentials as a SSH Key with Username type . This credential contains the username , the private key (.pem) file from which the ec2 can be accessed. 

We are also passing playbook.yml in which the actual ansible code resides

### Sample Ansible Playbook

```yaml
yaml
CopyEdit
---
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

---

Once nginx is installed on the machine , you can access your custom HTML page by simply putting public ip of the machine in the browser 

![image.png](attachment:c6c68062-a337-4439-a514-3a889b01c500:image.png)

### Post Block

```groovy
groovy
CopyEdit
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

---

This post block outputs the EC2 public IP to the user on Jenkins Console as a final step .

Notice that we have written output of IP under success block , it means this step only gets executed if all above stages are success only then this is executed.

Now as for the always {} block , it gets executed no matter the result of the stages , this would archive the terraform state file.

You can choose to remote lock this state file by storing it in a secure S3 bucket and lock it using DynamoDB , i have not used this in the demo for now.

If you have implemented all of the above steps correctly , your pipeline should execute and should look like a complete green signal 🙂

![image.png](attachment:8294390b-370d-4fc3-8e5d-cf5807bf1d40:image.png)

## 🛡️ Security Best Practices

1. **Don’t commit `.tfvars` or `.pem` files** to version control. Add them to `.gitignore`.
2. Use **Jenkins credentials plugin** for secrets and SSH keys.
3. Consider **remote state storage** using:
    - S3 bucket for `.tfstate`
    - DynamoDB for state locking
4. Never disable host key checking in production (`StrictHostKeyChecking=no`). Instead:
    - Use `ssh-keyscan` in a pre-step to add EC2 hosts to `known_hosts`.

---

## ✅ Final Output

Once the pipeline completes, you’ll see the EC2 IPs printed and Nginx running with your custom HTML.

Congrats , your CI/CD pipeline using Jenkins, Terraform, and Ansible is up and running!

If you want you can have a look at my Github Repo here , suggestions and new learning are always welcomed !

---

## 💬 Final Words

> “Don’t stop learning. If things don’t work, debug, experiment, and stay open-minded.”
> 

If you’re setting up your first Jenkins pipeline , don’t stress. Break things, fix them, and enjoy the process. You’ve got this!
