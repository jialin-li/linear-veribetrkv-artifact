FROM ubuntu:18.04

# https://askubuntu.com/questions/909277/avoiding-user-interaction-with-tzdata-when-installing-certbot-in-a-docker-contai
ARG DEBIAN_FRONTEND=noninteractive

# Load mono keys so we can install PPA to get a recent version (ubuntu ships
# with 4.x; we want 6.x)
RUN apt-get update
RUN apt-get install -y ca-certificates gnupg2
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys A6A19B38D3D831EF

COPY mono-official-stable.list /etc/apt/sources.list.d/

RUN apt-get update
RUN apt-get install -y mono-runtime mono-mcs mono-devel git make wget unzip
RUN apt-get install -y vim emacs

# install dafny 3.0 dependencies 
RUN wget https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
RUN dpkg -i packages-microsoft-prod.deb
RUN rm packages-microsoft-prod.deb
RUN apt-get update; \
apt-get install -y apt-transport-https && \
apt-get update && \
apt-get install -y dotnet-sdk-5.0

COPY veribetrkv-linear /home/veribetrkv-linear
WORKDIR /home/veribetrkv-linear
RUN tools/install-dafny.sh

WORKDIR /home/veribetrkv-linear
RUN /bin/bash
