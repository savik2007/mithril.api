#!/bin/bash
if [ "$TRAVIS_PULL_REQUEST" == "false" ]; then
    if [ "$TRAVIS_BRANCH" == "$TRUNK_BRANCH" ]; then

      echo "Start deploy container process"
## install kubectl
      curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
      chmod +x ./kubectl
      sudo mv ./kubectl /usr/local/bin/kubectl
## Install helm
      curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > get_helm.sh
      chmod 700 get_helm.sh
      ./get_helm.sh
# Credentials to GCE
      gcloud auth  activate-service-account  --key-file=$TRAVIS_BUILD_DIR/eHealth-8110bd102a69.json
      gcloud container clusters get-credentials dev --zone europe-west1-d --project ehealth-162117
#get helm charts
      git clone https://$GITHUB_TOKEN@github.com/edenlabllc/ehealth.charts.git
      cd ehealth.charts
#get version and project name
      sed -i'' -e "20,25s/tag:.*/tag: \"$NEXT_VERSION\"/g" "$CHART/values.yaml"
      helm init --upgrade
      sleep 15
      echo "helm upgrade ${CHART} with version: ${NEXT_VERSION}"
      helm upgrade  -f $CHART/values.yaml  $CHART $CHART
      cd $TRAVIS_BUILD_DIR/bin
      ./wait-for-deployment.sh api $CHART 180
           if [ "$?" -eq 0 ]; then
             kubectl get pod -n$CHART | grep api
             cd $TRAVIS_BUILD_DIR/ehealth.charts && git add . && sudo  git commit -m "Bump $CHART api to $NEXT_VERSION" && sudo git pull && sudo git push
             exit 0;
           else
              kubectl logs $(sudo kubectl get pod -n$CHART | awk '{ print $1 }' | grep api) -n$CHART
              helm rollback $CHART  $(($(helm ls | grep $CHART | awk '{ print $2 }') -1))
              exit 1;
           fi;
     fi;
fi;