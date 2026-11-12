pipeline {
    agent any

    environment {
        DOCKERHUB_USER = 'aycha123'
        APP_NAME       = 'flask-app'
        IMAGE          = "${DOCKERHUB_USER}/${APP_NAME}"
        TAG            = "${BUILD_NUMBER}"

        // A adapter pour le deploiement sur EKS
        AWS_REGION     = 'eu-west-3'
        EKS_CLUSTER    = 'mon-cluster-eks'
        HELM_RELEASE   = 'flask-app'
        HELM_CHART     = './helm/flask-app'
    }

    options {
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('SonarQube Analysis') {
            steps {
                // 'sonarqube' = nom du serveur dans Manage Jenkins > System
                withSonarQubeEnv('sonarqube') {
                    sh '''
                        sonar-scanner \
                          -Dsonar.projectKey=flask-app \
                          -Dsonar.sources=. \
                          -Dsonar.exclusions=**/venv/**,**/tests/**
                    '''
                }
            }
        }

        // Necessite un webhook dans SonarQube :
        // Administration > Configuration > Webhooks > http://IP_JENKINS:8080/sonarqube-webhook/
        // stage('Quality Gate') {
        //     steps {
        //         timeout(time: 5, unit: 'MINUTES') {
        //             waitForQualityGate abortPipeline: true
        //         }
        //     }
        // }

        stage('Snyk - Dependances') {
            steps {
                withCredentials([string(credentialsId: 'snyk-token', variable: 'SNYK_TOKEN')]) {
                    // || true : le pipeline continue meme si des vulnerabilites sont trouvees (lab)
                    sh 'snyk test --file=requirements.txt --severity-threshold=high || true'
                }
            }
        }

        stage('Docker Build') {
            steps {
                sh 'docker build -t ${IMAGE}:${TAG} -t ${IMAGE}:latest .'
            }
        }

        stage('Trivy - Scan image') {
            steps {
                // --exit-code 0 : n'echoue pas (lab). Mettre 1 pour bloquer sur HIGH/CRITICAL
                sh 'trivy image --severity HIGH,CRITICAL --exit-code 0 ${IMAGE}:${TAG}'
            }
        }

        stage('Push Docker Hub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds',
                                                  usernameVariable: 'DH_USER',
                                                  passwordVariable: 'DH_PASS')]) {
                    sh '''
                        echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin
                        docker push ${IMAGE}:${TAG}
                        docker push ${IMAGE}:latest
                    '''
                }
            }
        }

        stage('Deploy EKS (Helm)') {
            steps {
                // 'aws-creds' = credentials AWS dans Jenkins (plugin AWS Credentials)
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: 'aws-creds']]) {
                    sh '''
                        aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER}
                        helm upgrade --install ${HELM_RELEASE} ${HELM_CHART} \
                          --set image.repository=${IMAGE} \
                          --set image.tag=${TAG} \
                          --wait --timeout 5m
                    '''
                }
            }
        }
    }

    post {
        always {
            sh 'docker logout || true'
            sh 'docker image prune -f || true'
        }
        success {
            echo "Pipeline OK : ${IMAGE}:${TAG} deploye."
        }
        failure {
            echo 'Pipeline en echec : consulte les logs du stage concerne.'
        }
    }
}