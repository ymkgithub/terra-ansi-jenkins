pipeline {
    agent any
    tools {
        terraform 'terraform'
}


 environment {
        PATH=sh(script:"echo $PATH:/usr/local/bin", returnStdout:true).trim()
        AWS_REGION = "us-west-2"
        AWS_ACCOUNT_ID=sh(script:'export PATH="$PATH:/usr/local/bin" && aws sts get-caller-identity --query Account --output text', returnStdout:true).trim()
        ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        APP_REPO_NAME = "mahesh-clarusway-repo/cw-todo-app"
        APP_NAME = "todo"
    }


    stages {

        // stage('Git Clone') {
        //     steps {
        //         // Clone the repository
        //         sh 'git clone https://github.com/ymkgithub/terra-ansi-jenkins.git'
        //     }
        // }

        stage('Create Infrastructure for the App') {
            steps {
                echo 'Creating Infrastructure for the App on AWS Cloud'
                sh 'terraform init -no-color'
                sh 'terraform apply --auto-approve -no-color'
            }
        }

        stage('Create ECR Repo') {
            steps {
                echo 'Creating ECR Repo for App'
                sh """
                aws ecr create-repository \
                  --repository-name ${APP_REPO_NAME} \
                  --image-scanning-configuration scanOnPush=false \
                  --image-tag-mutability MUTABLE \
                  --region ${AWS_REGION}
                """
            }
        }
        
        stage('Substitute Terraform Outputs into .env Files') {
            steps {
                echo 'Substituting Terraform Outputs into .env Files'
                script {
                    env.NODE_IP = sh(script: 'terraform output -raw node_public_ip', returnStdout:true).trim()
                    env.DB_HOST = sh(script: 'terraform output -raw postgre_private_ip', returnStdout:true).trim()
                }
                sh 'echo ${DB_HOST}'
                sh 'echo ${NODE_IP}'
                sh 'envsubst < node-env-template > ./nodejs/server/.env'
                sh 'cat ./nodejs/server/.env'
                sh 'envsubst < react-env-template > ./react/client/.env'
                sh 'cat ./react/client/.env'
            }
        }

        stage('Build App Docker Images') {
            steps {
                echo 'Building App Images'
                sh 'docker build --force-rm -t "$ECR_REGISTRY/$APP_REPO_NAME:postgr" -f ./postgresql/dockerfile-postgresql .'
                sh 'docker build --force-rm -t "$ECR_REGISTRY/$APP_REPO_NAME:nodejs" -f ./nodejs/dockerfile-nodejs .'
                sh 'docker build --force-rm -t "$ECR_REGISTRY/$APP_REPO_NAME:react" -f ./react/dockerfile-react .'
                sh 'docker image ls'
            }
        }
        
        stage('Push Image to ECR Repo') {
            steps {
                echo 'Pushing App Image to ECR Repo'
                sh 'aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin "$ECR_REGISTRY"'
                sh 'docker push "$ECR_REGISTRY/$APP_REPO_NAME:postgr"'
                sh 'docker push "$ECR_REGISTRY/$APP_REPO_NAME:nodejs"'
                sh 'docker push "$ECR_REGISTRY/$APP_REPO_NAME:react"'
            }
        }


        stage('wait the instance') {
            steps {
                script {
                    echo 'Waiting for the instance'
                    id = sh(script: 'aws ec2 describe-instances --region ${AWS_REGION} --filters Name=tag-value,Values=ansible_postgresql Name=instance-state-name,Values=running --query Reservations[*].Instances[*].[InstanceId] --output text',  returnStdout:true).trim()
                    sh 'aws ec2 wait instance-status-ok --region ${AWS_REGION} --instance-ids $id'
                }
            }
        }
        
         stage('Deploy the App') {
            steps {
                echo 'Deploy the App'
                sh 'ls -l'
                sh 'ansible --version'
                sh 'ansible-inventory --graph'
                ansiblePlaybook credentialsId: 'techcrux', disableHostKeyChecking: true, installation: 'ansible', inventory: 'inventory_aws_ec2.yml', playbook: 'playbook.yml'
             }
        }

        // stage('Destroy the infrastructure'){
        //     steps{
        //         timeout(time:1, unit:'DAYS'){
        //             input message:'Approve terminate'
        //         }
        //         sh """
        //         docker image prune -af
        //         terraform destroy --auto-approve
        //         aws ecr delete-repository \
        //           --repository-name ${APP_REPO_NAME} \
        //           --region ${AWS_REGION} \
        //           --force
        //         """
        //     }
        // }

    }

    // post {
    //     always {
    //         echo 'Deleting all local images'
    //         sh 'docker image prune -af'
    //     }
    //     failure {

    //         echo 'Delete the Image Repository on ECR due to the Failure'
    //         sh """
    //             aws ecr delete-repository \
    //               --repository-name ${APP_REPO_NAME} \
    //               --region ${AWS_REGION}\
    //               --force
    //             """
    //         echo 'Deleting Terraform Stack due to the Failure'
    //             sh 'terraform destroy --auto-approve'
    //     }
    // }

}
