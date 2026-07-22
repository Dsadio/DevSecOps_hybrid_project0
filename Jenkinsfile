pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        timeout(time: 60, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    parameters {
        string(name: 'MY_IP', defaultValue: '', description: 'IP CIDR autorisée pour SSH vers l\'instance AWS (ex: 1.2.3.4/32)')
        string(name: 'KEY_NAME', defaultValue: 'ma-cle-devsecops', description: 'Nom de la paire de clés AWS existante')
        string(name: 'ONPREM_IP', defaultValue: '', description: 'IP de la VM on-premise (infra privée, environnement hybride) — non requis si DESTROY_ONLY')
        booleanParam(name: 'DESTROY_AFTER_TESTS', defaultValue: false, description: 'Détruire l\'infra AWS automatiquement après les tests, en fin de déploiement normal (démo/pédagogique)')
        booleanParam(name: 'DESTROY_ONLY', defaultValue: false, description: 'Raccourci : ignore le déploiement complet et détruit directement l\'infrastructure existante')
    }

    environment {
        AWS_REGION       = 'eu-west-3'
        TF_IN_AUTOMATION = 'true'
        TF_INPUT         = 'false'
        APPLIED          = 'false'

        // Exposées comme variables shell : à utiliser via $VAR dans sh ''' ... '''
        // (jamais via interpolation Groovy) pour éviter toute injection de commandes.
        MY_IP       = "${params.MY_IP}"
        KEY_NAME    = "${params.KEY_NAME}"
        ONPREM_IP   = "${params.ONPREM_IP}"
    }

    stages {

        // ══════════════════════════════════════════════
        // ÉTAPE 0 : Validation stricte des paramètres selon le mode
        // ══════════════════════════════════════════════
        stage('Validate Parameters') {
            steps {
                script {
                    def cidrIPv4 = /^((25[0-5]|2[0-4]\d|1?\d?\d)\.){3}(25[0-5]|2[0-4]\d|1?\d?\d)\/(3[0-2]|[12]?\d)$/
                    def ipv4     = /^((25[0-5]|2[0-4]\d|1?\d?\d)\.){3}(25[0-5]|2[0-4]\d|1?\d?\d)$/

                    if (!(params.MY_IP?.trim() ==~ cidrIPv4)) {
                        error('MY_IP invalide : format CIDR IPv4 requis (ex: 1.2.3.4/32). Requis pour apply comme pour destroy.')
                    }
                    if (!(params.KEY_NAME?.trim() ==~ /^[A-Za-z0-9._-]{1,64}$/)) {
                        error('KEY_NAME invalide : seuls les caractères A-Za-z0-9._- sont autorisés (64 max).')
                    }
                    if (!params.DESTROY_ONLY && !(params.ONPREM_IP?.trim() ==~ ipv4)) {
                        error('ONPREM_IP invalide : adresse IPv4 requise en mode déploiement normal (environnement hybride).')
                    }
                    if (params.DESTROY_ONLY) {
                        echo 'Mode DESTROY_ONLY activé : le déploiement complet sera ignoré, direction terraform destroy.'
                    }
                }
            }
        }

        // ══════════════════════════════════════════════
        // ÉTAPE 1 : Récupération du code (toujours nécessaire, même pour détruire)
        // ══════════════════════════════════════════════
        stage('Checkout') {
            steps {
                cleanWs(notFailBuild: true)
                git url: 'https://github.com/Dsadio/DevSecOps_hybrid_project0.git', branch: 'main'
            }
        }

        // ══════════════════════════════════════════════
        // ÉTAPE 2 : Vérification de la syntaxe Terraform
        // ══════════════════════════════════════════════
        stage('Terraform Format & Validate') {
            when { expression { return !params.DESTROY_ONLY } }
            steps {
                withAWS(credentials: 'aws-creds', region: env.AWS_REGION) {
                    dir('terraform') {
                        sh '''
                            #!/bin/bash

                            set -euo pipefail

                            echo "=== terraform fmt ==="
                            terraform fmt -check -recursive -diff

                            echo "=== terraform init (backend S3) ==="
                            terraform init -input=false

                            echo "=== terraform validate ==="
                            terraform validate
                        '''
                    }
                }
            }
        }

        // ══════════════════════════════════════════════
        // ÉTAPE 3 : Analyse de sécurité Terraform (trivy, remplaçant de tfsec) — BLOQUANT
        // ══════════════════════════════════════════════
        stage('Security - tfsec') {
            when { expression { return !params.DESTROY_ONLY } }
            steps {
                dir('terraform') {
                    sh '''
                        #!/bin/bash
                        set -euo pipefail
                        echo "=== Scan IaC (bloquant sur sévérité HIGH+) ==="
                        if command -v trivy >/dev/null 2>&1; then
                            trivy config . --severity HIGH,CRITICAL --exit-code 1 \
                                --format sarif --output tfsec-report.sarif
                        else
                            # Repli : tfsec est en fin de vie, migrer vers trivy dès que possible.
                            tfsec . --minimum-severity HIGH --format sarif --out tfsec-report.sarif
                        fi
                    '''
                }
            }
        }

        // ══════════════════════════════════════════════
        // ÉTAPE 4 : Vérification de la qualité Ansible (UNSTABLE si findings)
        // ══════════════════════════════════════════════
        stage('Quality - ansible-lint') {
            when { expression { return !params.DESTROY_ONLY } }
            steps {
                dir('ansible') {
                    catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                        sh '''
                            #!/bin/bash
                            set -euo pipefail
                            mkdir -p ../security
                            echo "=== Scan ansible-lint ==="
                            ansible-lint playbook.yml --format json > ../security/ansible-lint-report.json
                        '''
                    }
                }
            }
        }

        // ══════════════════════════════════════════════
        // ÉTAPE 5 : Provisionnement AWS via Terraform
        // ══════════════════════════════════════════════
        stage('Terraform Plan') {
            when { expression { return !params.DESTROY_ONLY } }
            steps {
                withAWS(credentials: 'aws-creds', region: env.AWS_REGION) {
                    dir('terraform') {
                        // Variables passées via l'environnement shell ($VAR),
                        // jamais par interpolation Groovy : pas d'injection possible.
                        sh '''    
                            #!/bin/bash 
                            set -euo pipefail
                            terraform init -input=false
                            terraform plan -input=false -no-color \
                                -var="key_name=$KEY_NAME" \
                                -var="my_ip=$MY_IP" \
                                -out=tfplan
                            # Version lisible pour archivage : le plan binaire peut
                            # contenir des valeurs sensibles et n'est pas archivé.
                            terraform show -no-color tfplan > tfplan.txt
                        '''
                    }
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'terraform/tfplan.txt', allowEmptyArchive: true
                }
            }
        }

        stage('Terraform Apply') {
            when { expression { return !params.DESTROY_ONLY } }
            steps {
                withAWS(credentials: 'aws-creds', region: env.AWS_REGION) {
                    dir('terraform') {
                        sh '''
                            #!/bin/bash 
                            set -euo pipefail
                            terraform apply -input=false -no-color -auto-approve tfplan
                        '''
                    }
                }
                script {
                    // Marqueur pour le rollback : ne détruire en post-failure
                    // que si un apply a réellement été tenté/effectué.
                    env.APPLIED = 'true'
                }
            }
        }

        stage('Get Terraform Outputs') {
            when { expression { return !params.DESTROY_ONLY } }
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
                        def ipv4 = /^((25[0-5]|2[0-4]\d|1?\d?\d)\.){3}(25[0-5]|2[0-4]\d|1?\d?\d)$/
                        if (!env.AWS_IP || !(env.AWS_IP ==~ ipv4)) {
                            error('IP publique EC2 vide ou invalide - impossible de continuer.')
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
            when { expression { return !params.DESTROY_ONLY } }
            steps {
                sh '''

                    #!/bin/bash
                    set -euo pipefail
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
            when { expression { return !params.DESTROY_ONLY } }
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: 'ssh-key-aws',
                                  keyFileVariable: 'AWS_KEY_FILE')]) {
                    sh '''
                        #!/bin/bash
                        set -euo pipefail
                        chmod 600 "$AWS_KEY_FILE"

                        # known_hosts persistant dans le workspace : la clé d'hôte est
                        # acceptée au premier contact (accept-new) puis vérifiée ensuite,
                        # au lieu d'être jetée via /dev/null (protection MITM).
                        KNOWN_HOSTS="$WORKSPACE/.ssh_known_hosts"
                        touch "$KNOWN_HOSTS" && chmod 600 "$KNOWN_HOSTS"
                        ssh-keyscan -T 5 -H "$AWS_IP" >> "$KNOWN_HOSTS" 2>/dev/null || true

                        mkdir -p ansible/inventory
                        cat > ansible/inventory/aws.ini <<EOF
[aws]
$AWS_IP ansible_user=ubuntu ansible_ssh_private_key_file=$AWS_KEY_FILE ansible_ssh_common_args='-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=$KNOWN_HOSTS'
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
            when { expression { return !params.DESTROY_ONLY } }
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: 'ssh-key-onprem',
                                  keyFileVariable: 'ONPREM_KEY_FILE',
                                  usernameVariable: 'ONPREM_USER')]) {
                    sh '''
                        #!/bin/bash
                        set -euo pipefail
                        chmod 600 "$ONPREM_KEY_FILE"

                        KNOWN_HOSTS="$WORKSPACE/.ssh_known_hosts"
                        touch "$KNOWN_HOSTS" && chmod 600 "$KNOWN_HOSTS"
                        ssh-keyscan -T 5 -H "$ONPREM_IP" >> "$KNOWN_HOSTS" 2>/dev/null || true

                        mkdir -p ansible/inventory
                        cat > ansible/inventory/onprem.ini <<EOF
[onprem]
$ONPREM_IP ansible_user=$ONPREM_USER ansible_ssh_private_key_file=$ONPREM_KEY_FILE ansible_ssh_common_args='-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=$KNOWN_HOSTS'
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
            when { expression { return !params.DESTROY_ONLY } }
            steps {
                sh '''
                    #!/bin/bash
                    set -euo pipefail
                    echo "=== Test HTTP ==="
                    curl -fsS -o /dev/null -w "HTTP %{http_code}\\n" "http://$AWS_IP"

                    echo "=== En-têtes de sécurité ==="
                    # HSTS n'est émis qu'en HTTPS : non testé ici sur HTTP.
                    curl -sI "http://$AWS_IP" | grep -iE 'X-Frame-Options|X-Content-Type-Options' || echo "AVERTISSEMENT: en-têtes manquants"

                    echo "=== Page web accessible ==="
                    curl -fsS "http://$AWS_IP" | head -n 5
                '''
            }
        }

        // ══════════════════════════════════════════════
        // ÉTAPE 9 (optionnelle) : Destruction en fin de déploiement normal
        // ══════════════════════════════════════════════
        stage('Terraform Destroy (optional)') {
            when {
                allOf {
                    expression { return params.DESTROY_AFTER_TESTS }
                    expression { return !params.DESTROY_ONLY }
                }
            }
            steps {
                withAWS(credentials: 'aws-creds', region: env.AWS_REGION) {
                    dir('terraform') {
                        sh '''
                            #!/bin/bash
                            set -euo pipefail
                            terraform init -input=false
                            terraform destroy -input=false -no-color -auto-approve \
                                -var="key_name=$KEY_NAME" \
                                -var="my_ip=$MY_IP"
                        '''
                    }
                }
            }
        }

        // ══════════════════════════════════════════════
        // ÉTAPE 10 : Raccourci de destruction rapide (DESTROY_ONLY)
        // ══════════════════════════════════════════════
        stage('Terraform Destroy Only') {
            when { expression { return params.DESTROY_ONLY } }
            steps {
                withAWS(credentials: 'aws-creds', region: env.AWS_REGION) {
                    dir('terraform') {
                        sh '''
                            #!/bin/bash
                            set -euo pipefail
                            echo "=== Initialisation Terraform (backend S3 existant) ==="
                            terraform init -input=false

                            echo "=== Destruction directe de l'infrastructure ==="
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
        success {
            script {
                if (params.DESTROY_ONLY) {
                    echo """
                        DESTRUCTION TERMINEE (mode DESTROY_ONLY)
                        L'infrastructure AWS a été détruite sans repasser par le déploiement complet.
                    """
                } else {
                    echo """
                        DEPLOIEMENT REUSSI
                        URL AWS     : http://${env.AWS_IP}
                        Logs S3     : ${env.LOGS_BUCKET}
                        VM on-prem  : ${params.ONPREM_IP} (configurée via Ansible)
                    """
                }
            }
        }
        failure {
            echo 'Pipeline échoué.'
            script {
                if (params.DESTROY_ONLY) {
                    echo 'Échec en mode DESTROY_ONLY - vérifier manuellement l\'état de l\'infrastructure et du state Terraform.'
                } else if (params.DESTROY_AFTER_TESTS && env.APPLIED == 'true') {
                    echo 'Rollback automatique (DESTROY_AFTER_TESTS=true, apply effectué) - destruction en cours...'
                    withAWS(credentials: 'aws-creds', region: env.AWS_REGION) {
                        dir('terraform') {
                            def rc = sh(returnStatus: true, script: '''
                                set -u
                                terraform init -input=false && \
                                terraform destroy -input=false -no-color -auto-approve \
                                    -var="key_name=$KEY_NAME" \
                                    -var="my_ip=$MY_IP"
                            ''')
                            if (rc != 0) {
                                unstable('Échec du destroy de rollback : infrastructure potentiellement orpheline, vérification manuelle requise.')
                            }
                        }
                    }
                } else if (params.DESTROY_AFTER_TESTS) {
                    echo 'Échec avant Terraform Apply : aucune infrastructure créée, pas de rollback nécessaire.'
                } else {
                    echo 'Pas de destruction automatique (DESTROY_AFTER_TESTS=false) - infra laissée en place pour investigation manuelle.'
                }
            }
        }
        cleanup {
            // Après archivage : supprime .terraform/, tfplan, inventaires (IPs) de l'agent.
            archiveArtifacts artifacts: 'security/**/*,terraform/tfsec-report.sarif,terraform/tfplan.txt', allowEmptyArchive: true
            cleanWs(notFailBuild: true)
        }
    }
}
