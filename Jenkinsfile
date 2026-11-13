pipeline {
    agent any

    environment {
        DOCKERHUB_USER = 'aycha123'
        APP_NAME       = 'flask-app'
        IMAGE          = "${DOCKERHUB_USER}/${APP_NAME}"
        TAG            = "${BUILD_NUMBER}"
        APP_DIR        = 'app'
        GITOPS_REPO    = 'github.com/missaouiaycha2021-cmd/devsecops-gitops-eks.git'
        VALUES_FILE    = 'helm/flask-app/values.yaml'
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

        stage('Docker Build') {
            steps {
                sh 'docker build -t ${IMAGE}:${TAG} -t ${IMAGE}:latest ${APP_DIR}'
            }
        }

        stage('Snyk - Image') {
            steps {
                withCredentials([string(credentialsId: 'snyk-token', variable: 'SNYK_TOKEN')]) {
                    // Analyse l'image (OS + dependances Python), sans installer les paquets sur la VM
                    // || true : le pipeline continue meme si des vulnerabilites sont trouvees (lab)
                    sh 'snyk container test ${IMAGE}:${TAG} --file=${APP_DIR}/Dockerfile --severity-threshold=high || true'
                }
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

        // CD gere par ArgoCD : Jenkins met seulement a jour le tag de l'image dans Git
        stage('Update GitOps (tag image)') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'github-creds',
                                                  usernameVariable: 'GIT_USER',
                                                  passwordVariable: 'GIT_TOKEN')]) {
                    sh '''
                        git config user.email "jenkins@local"
                        git config user.name "jenkins"
                        sed -i "s|^  tag: .*|  tag: \\"${TAG}\\"|" ${VALUES_FILE}
                        git add ${VALUES_FILE}
                        git commit -m "ci: image tag ${TAG}" || echo "Rien a commiter"
                        git push https://${GIT_USER}:${GIT_TOKEN}@${GITOPS_REPO} HEAD:main
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
            echo "Pipeline OK : ${IMAGE}:${TAG} poussee, ArgoCD deploiera le nouveau tag."
        }
        failure {
            echo 'Pipeline en echec : consulte les logs du stage concerne.'
        }
    }
}