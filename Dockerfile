# 1 From Apline Linux
FROM alpine:3.11

# 2 Maintainer name
LABEL maintainer="antonio@flood.io"

# 3 Copy local JMeter to the image and set environment variables
ARG JMETER_BINARIES="apache-jmeter-5.3.tgz"
ARG JMETER_FOLDER="apache-jmeter-5.3"
COPY ${JMETER_BINARIES} /tmp/
ENV JMETER_HOME /home/jmeter
ENV JMETER_BIN ${JMETER_HOME}/${JMETER_FOLDER}/bin
ENV JMETER_SCRIPT JMeter_Docker_Script_Plugins.jmx
ENV JMETER_FILE ${JMETER_HOME}/${JMETER_SCRIPT}
ENV JMETER_RESULTS ${JMETER_HOME}/result.jtl
ENV JMETER_LOG ${JMETER_HOME}/jmeter.log
COPY ${JMETER_SCRIPT} ${JMETER_FILE}
ENV AWS_ACCESS_KEY_ID ###################
ENV AWS_SECRET_ACCESS_KEY ###################
ENV AWS_DEFAULT_REGION ###################
ENV JVM_ARGS="-Xms2048m -Xmx4096m -XX:NewSize=1024m -XX:MaxNewSize=2048m -Duser.timezone=UTC"
#ENV JVM_ARGS "-Xms256m -Xmx1024m -XX:NewSize=256m -XX:MaxNewSize=1024m -Duser.timezone=UTC"
ENV PATH ${PATH}:${JMETER_HOME}:${JMETER_BIN}

# 4 Update & Upgrade, then decompress local JMeter and delete tar ball file
RUN apk update \
	&& apk upgrade \
	&& apk add ca-certificates wget python python-dev py-pip \
	&& update-ca-certificates \
	&& apk add --update openjdk8-jre tzdata curl unzip bash jq \
	&& apk add --no-cache nss \
	&& pip install --upgrade --user awscli \
	&& rm -rf /var/cache/apk/* \
	&& mkdir -p ${JMETER_HOME} \
	&& tar -zvxf /tmp/${JMETER_BINARIES} -C ${JMETER_HOME} \
	&& rm -f /tmp/${JMETER_BINARIES}

#5 Run JMeter when the image is running
CMD echo -n > ${JMETER_LOG} \
	&& echo -n > ${JMETER_RESULTS} \
	&& export PATH=~/.local/bin:${PATH} \
	&& ${JMETER_BIN}/jmeter.sh -n \
	-t ${JMETER_FILE} \
	-l ${JMETER_RESULTS} \
	-j ${JMETER_LOG} \
	-Jthreads=1000 \
	-Jrampup=100 \
	-Jduration=3600 \
	&& LOCAL_IP=`hostname -i` \
	&& PUBLIC_IP=`curl -4 ifconfig.co/json | jq -r .ip` \
	&& mv ${JMETER_RESULTS} ${JMETER_HOME}/result-${PUBLIC_IP}-${LOCAL_IP}.jtl \
	&& mv ${JMETER_LOG} ${JMETER_HOME}/jmeter-${PUBLIC_IP}-${LOCAL_IP}.log \
	&& aws s3 cp ${JMETER_HOME}/result-${PUBLIC_IP}-${LOCAL_IP}.jtl s3://bucket/ \
	&& aws s3 cp ${JMETER_HOME}/jmeter-${PUBLIC_IP}-${LOCAL_IP}.log s3://bucket/