#!/bin/bash
# run.sh from https://github.com/wilsonmar/cicd-buzz
# Explained at https://wilsonmar.github.io/cicd-pipeline
# This first clean-up leftovers from previous run, then run Docker image,
# After running, the container process is removed.
# The image downloaded is also removed to save disk space.
# So the image is downloaded on every run.

# Variables:
NAME="cicd-buzz"
IMAGE="robvanderleek/cicd-buzz"
CONTAINER_PORT="8082"

### Set color variables (based on aws_code_deploy.sh): 
blink="\e[5m"
blue="\e[34m"
bold="\e[1m"
dim="\e[2m"
green="\e[32m"
red="\e[31m"
reset="\e[0m"
underline="\e[4m"

function echo_f() {  # echo fancy comment
  local fmt="$1"; shift
  printf "\\n    >>> $fmt\\n" "$@"
}

# For Git on Windows, see http://www.rolandfg.net/2014/05/04/intellij-idea-and-git-on-windows/
TIME_START="$(date -u +%s)"
#FREE_DISKBLOCKS_END=$(df | sed -n -e '2{p;q}' | cut -d' ' -f 6) # no longer works
FREE_DISKBLOCKS_START="$(df -P | awk '{print $4}' | sed -n 2p)"  # e.g. 342771200 from:
   # Filesystem    512-blocks      Used Available Capacity  Mounted on
   # /dev/disk1s1   976490568 611335160 342771200    65%    /
LOG_PREFIX=$(date +%Y-%m-%dT%H:%M:%S%z)-$((1 + RANDOM % 1000))
   # ISO-8601 date plus RANDOM=$((1 + RANDOM % 1000))  # 3 digit random number.
   #  LOGFILE="$0.$LOG_PREFIX.log"
echo_f "STARTING $0 within $PWD "
echo_g "starting at $LOG_PREFIX with $FREE_DISKBLOCKS_START blocks free ..."

#########

docker image pull "${IMAGE}:latest"
# List images downloaded:
docker images "${IMAGE}"   # 61.8MB
IMAGE_ID=$(docker images --format="{{.Repository}} {{.ID}}" | grep "^$IMAGE " | cut -d' ' -f2)
echo "$IMAGE IMAGE_ID=$IMAGE_ID"

#docker ps
   CONTAINER_ID=$(docker ps -aqf "name=$NAME")
   echo "CONTAINER_ID=$CONTAINER_ID for $IMAGE"
   if ! [[ -z "${CONTAINER_ID// }" ]]; then  #it's blank
   	echo_f "Clean-up leftover: Stop running CONTAINER_ID=$CONTAINER_ID ... (takes a few seconds)"
      docker stop "${CONTAINER_ID}" > /dev/null 2>&1
      docker rm   "${CONTAINER_ID}" > /dev/null 2>&1
   fi
# TODO: Reusable function docker_cleanup() :

echo_f "Docker \"$NAME\" running in background for localhost:$CONTAINER_PORT ..."
docker run --name ${NAME} -p "$CONTAINER_PORT:5000" -i ${IMAGE} &
#sudo docker run --name ${NAME} -i -v ${PWD}:${PWD} -w ${PWD} ${IMAGE} $@
   # --rm ${IMAGE} to remove automatically?
sleep 1.5  # Wait seconds for start-up in background.

      RESPONSE=$(curl "localhost:$CONTAINER_PORT")
      echo "RESPONSE=$RESPONSE"
         # <html><body><h1>End-To-End Continuous Testing Remarkably Revamps Continuous Deployment</h1></body></html>

CONTAINER_ID=$(docker ps -aqf "name=$NAME")
      echo_f "Stop running CONTAINER_ID=$CONTAINER_ID ... (takes a few seconds)"
      # See https://stackoverflow.com/questions/33117068/use-of-supervisor-in-docker/33119321#33119321
      docker stop "${CONTAINER_ID}" # > /dev/null 2>&1
#      sleep 1.5  # Wait seconds for processing.

      echo_f "Removing CONTAINER_ID=$CONTAINER_ID ..."
      docker rm   "${CONTAINER_ID}" # > /dev/null 2>&1

# Dispose of image:
echo_f "Disposing image $NAME, IMAGE_ID=$IMAGE_ID ... (takes a few seconds)"
docker rmi "$IMAGE_ID"

# List all info:
# docker info

echo_f "Docker Prune dangling ..."
# Delete -all images, containers, volumes, and networks — that are dangling (not associated with a container):
yes | docker system prune -a
   # Total reclaimed space: ...
   # See https://www.digitalocean.com/community/tutorials/how-to-remove-docker-images-containers-and-volumes

FREE_DISKBLOCKS_END="$(df -P | awk '{print $4}' | sed -n 2p)"
DIFF=$(((FREE_DISKBLOCKS_START-FREE_DISKBLOCKS_END)/2048))
# 380691344 / 182G = 2091710.681318681318681 blocks per GB
# 182*1024=186368 MB
# 380691344 / 186368 G = 2042 blocks per MB

TIME_END=$(date -u +%s);
DIFF=$((TIME_END-TIME_START))
MSG="End of script after $((DIFF/60))m $((DIFF%60))s seconds elapsed"
echo_f "$MSG and $DIFF MB disk space consumed."
#say "script ended."  # through speaker
