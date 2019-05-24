#!/usr/bin/env groovy
node('master') {
  properties([disableConcurrentBuilds(), pipelineTriggers([githubPush()])])
  
  node {
    git url: 'https://github.com/TeamTWD40/python-web-scraper.git', branch: 'dev'
  }
  
  try {
      notifySlack('STARTED')
      def appType = 'java'  //Enter either java or nodejs
      def internalApiDNS = 'api-internal.twdaws.net'    //Enter the same value as in the cloudformation parameter
      def apiDNS = 'api.twdaws.net'    //Enter the same value as in the cloudformation parameter
      def appComponent = 'backend'   //Enter either frontend or backend
      def platform = 'eks'      //Enter either openshift or eks
      def healthcheckPath = getPath(appComponent)
      def ocpHost='https://ocp.twdaws.net' //Enter the same value as in the cloudformation parameter
      def region = 'us-east-1'
      def appName = 'python-web-scraper'
      def nodePort = getNodePort(BRANCH_NAME)
      def containerPort = getContainerPort(BRANCH_NAME)
      TAG = "twd-demo-${BRANCH_NAME}/${appName}:${BUILD_NUMBER}"
      def TAG2 = "twd-demo-${BRANCH_NAME}/${appName}:latest"
      REGISTRY = '755676269208.dkr.ecr.us-east-1.amazonaws.com'
      TAGPROD = "twd-demo-prod/${appName}:${BUILD_NUMBER}"
      def TAG2PROD = "twd-demo-prod/${appName}:latest"
      def IMAGE = getImage(BRANCH_NAME)
      def githubURL = "git@github.com:TeamTWD40/${appName}.git"
      passedBuilds = []

      stage('Checkout') {
          checkout([$class: 'GitSCM', branches: [[name: BRANCH_NAME]], userRemoteConfigs: [[credentialsId: 'jenkins_SSH_Key_Auth', url: githubURL]]])

      }      

    if (BRANCH_NAME ==~ "release.*" || BRANCH_NAME == 'stage' || BRANCH_NAME == 'dev'){
        stage('Build and Push Image') {
          withDockerRegistry(credentialsId: "ecr:${region}:ECS_Access", url: "http://${REGISTRY}") {
            if (BRANCH_NAME ==~ "release.*"){
              def newImage = docker.build("${REGISTRY}/${TAGPROD}")
              newImage.push()
              newImage.push('latest')
            }
            else {
              def newImage = docker.build("${REGISTRY}/${TAG}")
              newImage.push()
              newImage.push('latest')
            }
          }
        }
    }

      if (BRANCH_NAME ==~ "release.*" || BRANCH_NAME == 'stage' || BRANCH_NAME == 'dev'){
        stage("Deploy to ${getEnv(BRANCH_NAME)}"){
           timeout(time: 10, unit: 'MINUTES'){
              switch(platform){
                  case 'openshift':
                  withCredentials([string(credentialsId: 'Openshift_login', variable: 'Token')]) {
                      sh "oc login $ocpHost --token=$Token"
                  }
                      if (BRANCH_NAME ==~ "release.*"){
                          sh "chmod +x ocp-deploy1"
                          sh "./ocp-deploy1 $REGISTRY $appName $TAG2PROD $containerPort $nodePort $healthcheckPath"
                      }
                      else {
                          sh "chmod +x ocp-deploy2"
                          sh "./ocp-deploy2 $REGISTRY $BRANCH_NAME $appName $TAG2 $containerPort $nodePort $healthcheckPath"
                      }
                      break;
                  case 'eks':
                      if (BRANCH_NAME ==~ "release.*"){
                        sh "kubectl create deployment ${appName} --image=${IMAGE} -n prod || kubectl set image deployment ${appName} ${appName}=${IMAGE} -n prod --record=true"
                        sh "kubectl patch deployment ${appName} -n prod -p '{\"spec\": { \"template\": {  \"spec\": { \"containers\": [{ \"name\": \"${appName}\", \"readinessProbe\": { \"httpGet\": { \"path\": \"${healthcheckPath}\", \"port\": ${containerPort} },\"initialDelaySeconds\": 60, \"timeoutSeconds\": 5}, \"livenessProbe\": { \"httpGet\": { \"path\": \"${healthcheckPath}\", \"port\": ${containerPort} }, \"initialDelaySeconds\": 70,\"timeoutSeconds\": 10, \"failureThreshold\": 5 } } ]}}}}' || echo 'deployment ${appName} already patched'"
                        sh "kubectl scale --replicas=2 deployment/${appName} -n prod"
                        sh "kubectl expose deployment ${appName} --port=${containerPort}  --type=NodePort -n prod || echo 'Service ${appName} already created'"
                        sh "kubectl patch service ${appName} -n prod -p '{\"spec\":{\"ports\":[{\"port\":${containerPort},\"nodePort\":${nodePort}}]}}' || echo 'Service ${appName} already updated'"
                      }
                      else {
                        sh "kubectl create deployment ${appName} --image=${IMAGE} -n ${BRANCH_NAME} || kubectl set image deployment ${appName} ${appName}=${IMAGE} -n ${BRANCH_NAME} --record=true"
                        sh "kubectl patch deployment ${appName} -n ${BRANCH_NAME} -p '{\"spec\": { \"template\": {  \"spec\": { \"containers\": [{ \"name\": \"${appName}\", \"readinessProbe\": { \"httpGet\": { \"path\": \"${healthcheckPath}\", \"port\": ${containerPort} },\"initialDelaySeconds\": 60, \"timeoutSeconds\": 5}, \"livenessProbe\": { \"httpGet\": { \"path\": \"${healthcheckPath}\", \"port\": ${containerPort} }, \"initialDelaySeconds\": 70,\"timeoutSeconds\": 10, \"failureThreshold\": 5 } } ]}}}}' || echo 'deployment ${appName} already patched'"
                        sh "kubectl scale --replicas=2 deployment/${appName} -n ${BRANCH_NAME}"
                        sh "kubectl expose deployment ${appName} --port=${containerPort} --type=NodePort -n ${BRANCH_NAME} || echo 'Service ${appName} already created'"
                        sh "kubectl patch service ${appName} -n ${BRANCH_NAME}  -p '{\"spec\":{\"ports\":[{\"port\":${containerPort},\"nodePort\":${nodePort}}]}}' || echo 'Service ${appName} already updated'"
                      }
                      break;
                }
                if (appComponent == 'backend'){
                sleep (10)
                sh 'chmod +x api-import.sh'
                  sh "./api-import.sh $internalApiDNS $containerPort $appName $region ${getEnv(BRANCH_NAME)} $apiDNS"
                }
            }
          }
        }

    switch(BRANCH_NAME){
      case 'dev':
        stage('Promote to stage'){
           sh "git tag -a Build-${BUILD_NUMBER} -m \"Build Number ${BUILD_NUMBER}\""
            sh 'git checkout stage -f'
            sh 'git merge origin/dev'
            sh "git push origin stage"
         }
          break;
      case 'stage':
        stage('Promote to release'){
            def userInput
            try {
              timeout(time: 60, unit: 'MINUTES'){
                slackSend (color: '#FFFF00', message: "${appName} stage branch is ready for promotion to release. Login to Jenkins to approve")
                userInput = input(
                    id: 'Promote1', message: 'Promote Code to Production?', parameters: [
                    [$class: 'BooleanParameterDefinition', defaultValue: true, description: '', name: 'Please Confirm Promotion to Production']
                    ])
              }
            } catch(err) {
                echo "Code will not be promoted"
            }
            if (userInput == true) {
              sh '''if [[ $(git branch | grep release) ]]
              then
                git checkout release -f
              else
                git checkout -b release -f
              fi'''              
              sh 'git merge origin/stage'
              sh 'git push origin release'              
            } else {
                echo "Code not promoted to production"
            }
        }
        break;
     case 'release':
      stage ('Publish release & Promote to master') {        
        lastSuccessfullBuild(currentBuild.getPreviousBuild());
        withCredentials([string(credentialsId: 'github_token', variable: 'token')]) {
                  sh "curl --data '{\"tag_name\": \"v${getReleaseTag(passedBuilds.size()+1)}\",\"target_commitish\": \"release\",\"name\": \"v${getReleaseTag(passedBuilds.size()+1)}\",\"body\": \"Release of version ${getReleaseTag(passedBuilds.size()+1)}\",\"draft\": false,\"prerelease\": false}' https://api.github.com/repos/TeamTWD40/microservice-seed/releases?access_token=$token"
              }
        sh 'git checkout master -f'
        sh 'git merge origin/release'
        sh 'git push origin master'
      } 
    }
       stage('Clean Up'){
            sh "docker rmi ${REGISTRY}/${TAG} || echo 'No such image'"
            sh "docker system prune -f"
            hygieiaBuildPublishStep buildStatus: 'Success'
        }

  }
  catch (err) {
      currentBuild.result = "FAILED"
      sh "docker rmi ${REGISTRY}/${TAG} || echo 'No such image'"
      sh "docker system prune -f"
      throw err
  } finally {
          notifySlack(currentBuild.result)
    }
}

def notifySlack(String buildStatus) {

  buildStatus =  buildStatus ?: 'SUCCESSFUL'
  def colorName = 'RED'
  def colorCode = '#FF0000'
  def subject = "${buildStatus}: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]'"
  def summary = "${subject} (${env.BUILD_URL})"

  if (buildStatus == 'STARTED') {
    color = 'YELLOW'
    colorCode = '#FFFF00'
  } else if (buildStatus == 'SUCCESSFUL') {
    color = 'GREEN'
    colorCode = '#00FF00'
  } else {
    color = 'RED'
    colorCode = '#FF0000'
  }

  slackSend (color: colorCode, message: summary)
}

def getNodePort(String branch){
  if (branch == 'dev'){
    return 30200
  }
  else if (branch == 'stage'){
    return 31200
  }
  else if (branch ==~ "release.*"){
    return 32200
  }
}

def getContainerPort(String branch){
  if (branch == 'dev'){
    return 8082
  }
  else if (branch == 'stage'){
    return 9082
  }
  else if (branch ==~ "release.*"){
    return 10082
  }
}

def getPath(String component){
  if (component == 'frontend'){
    return '/'
  }
  else if (component == 'backend'){
    return '/actuator/health'
  }
}
def getImage(String branch){
  if (branch ==~ "release.*"){
    return "${REGISTRY}/${TAGPROD}"
  }
  else {
    return "${REGISTRY}/${TAG}"
  }
}
def lastSuccessfullBuild(build) {
    if(build != null && build.result != 'FAILURE') {
        //Recurse now to handle in chronological order
        lastSuccessfullBuild(build.getPreviousBuild());
        //Add the build to the array
        passedBuilds.add(build);
    }
 }
def getReleaseTag(int number){
    double version;
    version = number / 10;
    return version
}
def getEnv(String branch){
  if (branch ==~ "release.*"){
    return 'production'
  }
  else {
    return "${branch}"
  }
}
