pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        timeout(time: 60, unit: 'MINUTES')
        ansiColor('xterm')
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    parameters {
        string(name: 'MY_IP', defaultValue: '', description: 'IP CIDR autorisée pour SSH vers l\'instance AWS (ex: 1.2.3.4/32)')
        string(name: 'KEY_NAME', defaultValue: 'ma-cle-devsecops', description: 'Nom de la paire de clés AWS existante')
        string(name: 'ONPREM_IP', defaultValue: '', description: 'IP de la VM on-premise (infra privée, environnement hybride)')
        booleanParam(name: 'DESTROY_AFTER_TESTS', defaultValue: false, description: 'Détruire l\'infra AWS automatiquement après les tests (démo/pédagogique)')
    }

    environment {
        AWS_REGION       = 'eu-west-3'
        TF_IN_AUTOMATION = 'true'
        TF_INPUT         = 'false'

        // Jenkins expose déjà nativement les paramètres comme variables shell dans les steps sh.
        // Cette déclaration explicite est redondante fonctionnellement, mais conservée pour la lisibilité.
        MY_IP       = "${params.MY_IP}"
        KEY_NAME    = "${params.KEY_NAME}"
        ONPREM_IP   = "${params.ONPREM_IP}"
    }

    stages {

        // ══════════════════════════════════════════════
        // ÉTAPE 1 : Récupération du code
        // ══════════════════════════════════════════════
        stage('Checkout') {
            steps {
                git url: 'https://github.com/Dsadio/DevSecOps_hybrid_project.git', branch: 'main'
            }
        }

        // ══════════════════════════════════════════════
        // ÉTAPE 2 : Vérification de la syntaxe Terraform
        // ══════════════════════════════════════════════
        stage('Terraform Format & Validate') {
            steps {
                dir('terraform') {
                    sh '''
                        set -e
                        echo "=== terraform fmt ==="
                        terraform fmt -check -recursive -diff

                        echo "=== terraform init (backend S3 déjà configuré dans backend.tf) ==="
                        terraform init -input=false

                        echo "=== terraform validate ==="
                        terraform validate
                    '''
                }
            }
        }

        // ══════════════════════════════════════════════
        // ÉTAPE 3 : Analyse de sécurité Terraform (tfsec) — BLOQUANT
        // ══════════════════════════════════════════════
        stage('Security - tfsec') {
            steps {
                dir('terraform') {
                    sh '''
                        set -e
                        echo "=== Scan tfsec (bloquant sur sévérité HIGH+) ==="
                        tfsec . --minimum-severity HIGH --format sarif --out tfsec-report.sarif
                    '''
                }
            }
        }

        // ══════════════════════════════════════════════
        // ÉTAPE 4 : Vérification de la qualité Ansible
        // ══════════════════════════════════════════════
        stage('Quality - ansible-lint') {
            steps {
                dir('ansible') {
                    sh '''
                        set -e
                        mkdir -p ../security
                        echo "=== Scan ansible-lint ==="
                        ansible-lint playbook.yml --format json > ../security/ansible-lint-report.json || true
                    '''
                }
            }
        }

        // ══════════════════════════════════════════════
        // ÉTAPE 5 : Provisionnement AWS via Terraform
        // ══════════════════════════════════════════════
        stage('Terraform Plan') {
            steps {
                script {
                    if (params.MY_IP == null || params.MY_IP.trim().isEmpty()) {
                        error('Le paramètre MY_IP est requis pour lancer le plan.')
                    }
                    if (params.ONPREM_IP == null || params.ONPREM_IP.trim().isEmpty()) {
                        error('Le paramètre ONPREM_IP est requis (environnement hybride : VM on-premise à configurer).')
                    }
                }
                withAWS(credentials: 'aws-creds', region: env.AWS_REGION) {
                    dir('terraform') {
                        sh """
                            set -e
                            terraform plan -input=false -no-color \
                                -var="key_name=${params.KEY_NAME}" \
                                -var="my_ip=${params.MY_IP}" \
                                -out=tfplan
                        """
                    }
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'terraform/tfplan', allowEmptyArchive: true
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                withAWS(credentials: 'aws-creds', region: env.AWS_REGION) {
                    dir('terraform') {
                        sh 'terraform apply -input=false -no-color -auto-approve tfplan'
                    }
                }
            }
        }

        stage('Get Terraform Outputs') {
            steps {
                withAWS(credentials: 'aws-creds', region: env.AWS_REGION) {
                    script {
                        dir('terraform') {
                            env.AWS_IP = sh(
                                script: 'terraform output -raw public_ip',
                                returnStdout: true
                            ).trim()
                            env.LOGS_BUCKET = sh(
                                script: 'terraform output -raw logs_bucket_name',
                                returnStdout: true
                            ).trim()
                        }
                        if (!env.AWS_IP) {
                            error('IP publique EC2 vide - impossible de continuer.')
                        }
                        echo "IP publique de l'instance : ${env.AWS_IP}"
                    }
                }
            }
        }

        // ══════════════════════════════════════════════
        // ÉTAPE 6 : Attente de disponibilité SSH (EC2)
        // ══════════════════════════════════════════════
        stage('Wait for SSH') {
            steps {
                sh '''
                    set -e
                    echo "=== Attente de la disponibilité SSH sur $AWS_IP ==="
                    for i in $(seq 1 20); do
                        if nc -z -w3 "$AWS_IP" 22; then
                            echo "SSH disponible"
                            exit 0
                        fi
                        echo "Tentative $i/20 - SSH pas encore prêt, attente 10s..."
                        sleep 10
                    done
                    echo "SSH indisponible après 200s - abandon"
                    exit 1
                '''
            }
        }

        // ══════════════════════════════════════════════
        // ÉTAPE 7 : Configuration via Ansible - AWS (cloud public)
        // ══════════════════════════════════════════════
        stage('Ansible Deploy - AWS') {
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: 'ssh-key-aws',
                                  keyFileVariable: 'AWS_KEY_FILE')]) {
                    sh '''
                        set -e
                        chmod 600 "$AWS_KEY_FILE"

                        mkdir -p ansible/inventory
                        cat > ansible/inventory/aws.ini <<EOF
[aws]
$AWS_IP ansible_user=ubuntu ansible_ssh_private_key_file=$AWS_KEY_FILE ansible_ssh_common_args='-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null'
EOF

                        cd ansible
                        ansible -i inventory/aws.ini aws -m ping
                        ansible-playbook -i inventory/aws.ini playbook.yml -b
                    '''
                }
            }
        }

        // ══════════════════════════════════════════════
        // ÉTAPE 7bis : Configuration via Ansible - VM on-premise (infra privée)
        // ══════════════════════════════════════════════
        stage('Ansible Deploy - Onprem VM') {
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: 'ssh-key-onprem',
                                  keyFileVariable: 'ONPREM_KEY_FILE',
                                  usernameVariable: 'ONPREM_USER')]) {
                    sh '''
                        set -e
                        chmod 600 "$ONPREM_KEY_FILE"

                        mkdir -p ansible/inventory
                        cat > ansible/inventory/onprem.ini <<EOF
[onprem]
$ONPREM_IP ansible_user=$ONPREM_USER ansible_ssh_private_key_file=$ONPREM_KEY_FILE ansible_ssh_common_args='-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null'
EOF

                        cd ansible
                        ansible -i inventory/onprem.ini onprem -m ping
                        ansible-playbook -i inventory/onprem.ini playbook.yml -b
                    '''
                }
            }
        }

        // ══════════════════════════════════════════════
        // ÉTAPE 8 : Tests fonctionnels (EC2 public)
        // ══════════════════════════════════════════════
        stage('Functional Tests') {
            steps {
                sh '''
                    set -e
                    echo "=== Test HTTP ==="
                    curl -fsS -o /dev/null -w "HTTP %{http_code}\\n" "http://$AWS_IP"

                    echo "=== En-têtes de sécurité ==="
                    curl -sI "http://$AWS_IP" | grep -iE 'X-Frame-Options|X-Content-Type-Options|Strict-Transport' || echo "⚠️ En-têtes manquants"

                    echo "=== Page web accessible ==="
                    curl -fsS "http://$AWS_IP" | head -n 5
                '''
            }
        }

        // ══════════════════════════════════════════════
        // ÉTAPE 9 (optionnelle) : Destruction automatique de l'infra AWS
        // ══════════════════════════════════════════════
        stage('Terraform Destroy (optional)') {
            when {
                expression { return params.DESTROY_AFTER_TESTS }
            }
            steps {
                withAWS(credentials: 'aws-creds', region: env.AWS_REGION) {
                    dir('terraform') {
                        sh '''
                            set -e
                            terraform destroy -input=false -no-color -auto-approve \
                                -var="key_name=$KEY_NAME" \
                                -var="my_ip=$MY_IP"
                        '''
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════════════
    // POST-ACTIONS
    // ══════════════════════════════════════════════
    post {
        always {
            // Archivage centralisé : couvre tfsec, ansible-lint et le plan Terraform
            // en un seul point, exécuté quel que soit le stage où le pipeline s'arrête.
            archiveArtifacts artifacts: 'security/**/*,terraform/tfsec-report.sarif,terraform/tfplan', allowEmptyArchive: true
        }
        success {
            echo """
                ✅ DÉPLOIEMENT RÉUSSI
                URL AWS     : http://${env.AWS_IP}
                Logs S3     : ${env.LOGS_BUCKET}
                VM on-prem  : ${params.ONPREM_IP} (configurée via Ansible)
            """
        }
        failure {
            echo '❌ Pipeline échoué.'
            script {
                if (params.DESTROY_AFTER_TESTS) {
                    echo 'Rollback automatique demandé (DESTROY_AFTER_TESTS=true) - destruction en cours...'
                    withAWS(credentials: 'aws-creds', region: env.AWS_REGION) {
                        dir('terraform') {
                            sh '''
                                # Init défensif : couvre le cas où le pipeline échoue
                                # avant même d'avoir initialisé Terraform sur cet agent.
                                terraform init -input=false || true
                                terraform destroy -input=false -no-color -auto-approve \
                                    -var="key_name=$KEY_NAME" \
                                    -var="my_ip=$MY_IP" || true
                            '''
                        }
                    }
                } else {
                    echo 'Pas de destruction automatique (DESTROY_AFTER_TESTS=false) - infra laissée en place pour investigation manuelle.'
                }
            }
        }
    }
}
