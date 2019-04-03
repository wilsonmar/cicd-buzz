#!/bin/bash
# Run this from any directory:
# sh -c "$(curl -fsSL https://raw.githubusercontent.com/wilsonmar/cicd-buzz/master/run.sh)"
# or ./run.sh after cloning https://github.com/wilsonmar/cicd-buzz 
# Explained at https://wilsonmar.github.io/cicd-pipeline
# Tested on macOS Mojave 10.14
# This first checks if the port is already being used.
# Then it clean-up leftover docker process from previous run.
# Then run Docker image,
# After running, the container process is removed.
# The image downloaded is also removed to save disk space.
# So the image is downloaded on every run. Idempotent!

#1 Define variables you may change:
NAME="cicd-buzz"
IMAGE="robvanderleek/cicd-buzz"
CONTAINER_PORT="8099"

REMOVE_DOCKER_IMAGE="1"
DISPLAY_DOCKER_INFO="0"  # 0 for NO, 1 for YES for docker info
PRUNE_DOCKER="0"

#2 Set color variables (based on aws_code_deploy.sh): 
blink="\e[5m"
blue="\e[34m"
bold="\e[1m"
dim="\e[2m"
green="\e[32m"
red="\e[31m"
reset="\e[0m"
underline="\e[4m"

#3 Define reusable functions:
function echo_f() {  # echo fancy comment
  local fmt="$1"; shift
  printf "\\n    >>> $fmt\\n" "$@"
}
function echo_c() {  # echo common comment
  local fmt="$1"; shift
  printf "        $fmt\\n" "$@"
}

#4 Collect starting system information and display on console:
TIME_START="$(date -u +%s)"
#FREE_DISKBLOCKS_END=$(df | sed -n -e '2{p;q}' | cut -d' ' -f 6) # no longer works
FREE_DISKBLOCKS_START="$(df -P | awk '{print $4}' | sed -n 2p)"  # e.g. 342771200 from:
   # Filesystem    512-blocks      Used Available Capacity  Mounted on
   # /dev/disk1s1   976490568 611335160 342771200    65%    /
LOG_PREFIX=$(date +%Y-%m-%dT%H:%M:%S%z)-$((1 + RANDOM % 1000))
   # ISO-8601 date plus RANDOM=$((1 + RANDOM % 1000))  # 3 digit random number.
   #  LOGFILE="$0.$LOG_PREFIX.log"
echo_f "STARTING $0 within $PWD"
echo_c "at $LOG_PREFIX with $FREE_DISKBLOCKS_START blocks free ..."

#########

#5 If there is a Docker container running, stop and remove it:
   CONTAINER_ID=$(docker ps -aqf "name=$NAME")
   if ! [[ -z "${CONTAINER_ID// }" ]]; then  #it's blank
   	echo_f "Clean-up leftover: Stop running CONTAINER_ID=$CONTAINER_ID for $IMAGE ... (takes a few seconds)"
      docker stop "${CONTAINER_ID}" > /dev/null 2>&1
      docker rm   "${CONTAINER_ID}" > /dev/null 2>&1
   fi
   # TODO: Reusable function docker_cleanup() :

#6 Pull image from DockerHub:
docker image pull "${IMAGE}:latest"
if [ $? -eq 0 ]; then
   #7 Get from local Docker the IMAGE_ID to the Docker image downloaded:
   docker images "${IMAGE}"   # 61.8MB
   IMAGE_ID=$(docker images --format="{{.Repository}} {{.ID}}" | grep "^$IMAGE " | cut -d' ' -f2)
   echo "$IMAGE IMAGE_ID=$IMAGE_ID"
else
   echo_f "Error $? during docker run. Exiting script ..."
   exit
fi

#8 Verify that the port is available:
   RESULT=$(grep -w $CONTAINER_PORT/tcp /etc/services)
   if [[ -z "${RESULT// }" ]]; then  #it's blank
      echo_f "Port $CONTAINER_PORT is available ..."
   else
      echo_f "Please specify another port than $CONTAINER_PORT. Exiting script ..."
      echo_c "$RESULT"  # http             80/tcp     www www-http # World Wide Web HTTP
      exit
   fi

#9 Run:
echo_f "Docker \"$NAME\" running in background for localhost:$CONTAINER_PORT ..."
docker run --name ${NAME} -p "$CONTAINER_PORT:5000" -i ${IMAGE} &
#sudo docker run --name ${NAME} -i -v ${PWD}:${PWD} -w ${PWD} ${IMAGE} $@
   # --rm ${IMAGE} to remove automatically?

#10 Wait seconds for start-up to ready in background.
sleep 1.5  

#11 Verify if the last command finished OK:
if [ $? -eq 0 ]; then
   echo_f "While running in background: ..."
else
   echo_f "Error $? during docker run ..."
   exit
fi

#12 Invoke a response from the app and display response:
      RESPONSE=$(curl "localhost:$CONTAINER_PORT")
      echo_f "${#RESPONSE} characters in RESPONSE="
      echo "$RESPONSE"
         # <html><body><h1>End-To-End Continuous Testing Remarkably Revamps Continuous Deployment</h1></body></html>
#13 Twice, to see variation in the response:
      echo_f "${#RESPONSE} characters in RESPONSE="
      echo "$RESPONSE"

#14 Stop the run
CONTAINER_ID=$(docker ps -aqf "name=$NAME")
# docker logs "${CONTAINER_ID}"
      echo_f "Stop running CONTAINER_ID=$CONTAINER_ID ... (takes a few seconds)"
      # See https://stackoverflow.com/questions/33117068/use-of-supervisor-in-docker/33119321#33119321
      docker stop "${CONTAINER_ID}" # > /dev/null 2>&1
      echo_f "Removing CONTAINER_ID=$CONTAINER_ID ..."
      docker rm   "${CONTAINER_ID}" # > /dev/null 2>&1

#15 Remove image to save disk space:
if [ $REMOVE_DOCKER_IMAGE -eq "1" ]; then
   echo_f "Removing image $NAME, IMAGE_ID=$IMAGE_ID ... (takes a few seconds)"
   docker rmi "$IMAGE_ID"
fi

#16 List all info:
if [ $DISPLAY_DOCKER_INFO -eq "1" ]; then
   echo_f "Listing docker info ..."
   docker info
else
   echo_f "docker info not listed by default ..."
fi

#17 Delete -all images, containers, volumes, and networks — that are dangling (not associated with a container):
if [ $PRUNE_DOCKER -eq "1" ]; then
   echo_f "Docker Prune dangling ..."
   yes | docker system prune -a
   # Total reclaimed space: ...
   # See https://www.digitalocean.com/community/tutorials/how-to-remove-docker-images-containers-and-volumes
fi

#########

#18 Calculate and display end of run statistics:
FREE_DISKBLOCKS_END="$(df -P | awk '{print $4}' | sed -n 2p)"
DIFF=$(((FREE_DISKBLOCKS_START-FREE_DISKBLOCKS_END)/2048))
# 380691344 / 182G = 2091710.681318681318681 blocks per GB
# 182*1024=186368 MB
# 380691344 / 186368 G = 2042 blocks per MB
TIME_END=$(date -u +%s);
DIFF=$((TIME_END-TIME_START))
MSG="End of script after $((DIFF/60))m $((DIFF%60))s elapsed"
echo_f "$MSG and $DIFF MB disk space consumed."
#say "script ended."  # through speaker
