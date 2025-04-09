# Dockerfile Documentation

This Dockerfile builds a custom Docker image for running Apache JMeter load tests with AWS CLI integration.

---

## 1. Base Image

```dockerfile
FROM alpine:3.11
```
Uses Alpine Linux 3.11 as the lightweight base image.

---

## 2. Maintainer

```dockerfile
LABEL maintainer="antonio@flood.io"
```
Specifies the image maintainer's contact information.

---

## 3. JMeter Setup and Environment Variables

- **JMeter Binaries and Folder**

```dockerfile
ARG JMETER_BINARIES="apache-jmeter-5.3.tgz"
ARG JMETER_FOLDER="apache-jmeter-5.3"
COPY ${JMETER_BINARIES} /tmp/
```
Defines build arguments for the JMeter tarball and folder, then copies the JMeter binaries into the image.

- **Environment Variables**

```dockerfile
ENV JMETER_HOME /home/jmeter
ENV JMETER_BIN ${JMETER_HOME}/${JMETER_FOLDER}/bin
ENV JMETER_SCRIPT JMeter_Docker_Script_Plugins.jmx
ENV JMETER_FILE ${JMETER_HOME}/${JMETER_SCRIPT}
ENV JMETER_RESULTS ${JMETER_HOME}/result.jtl
ENV JMETER_LOG ${JMETER_HOME}/jmeter.log
```
Sets up paths for JMeter home, binaries, test script, results, and log files.

- **Copy JMeter Test Script**

```dockerfile
COPY ${JMETER_SCRIPT} ${JMETER_FILE}
```
Copies the JMeter test plan into the container.

- **AWS Credentials (placeholders)**

```dockerfile
ENV AWS_ACCESS_KEY_ID ###################
ENV AWS_SECRET_ACCESS_KEY ###################
ENV AWS_DEFAULT_REGION ###################
```
Environment variables for AWS credentials and region (replace with actual values or inject securely).

- **Java VM Arguments**

```dockerfile
ENV JVM_ARGS="-Xms2048m -Xmx4096m -XX:NewSize=1024m -XX:MaxNewSize=2048m -Duser.timezone=UTC"
# Alternative smaller JVM settings commented out
```
Configures JVM memory and timezone settings.

- **Update PATH**

```dockerfile
ENV PATH ${PATH}:${JMETER_HOME}:${JMETER_BIN}
```
Adds JMeter directories to the system PATH.

---

## 4. Install Dependencies and Setup JMeter

```dockerfile
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
```

- Updates package lists and upgrades packages
- Installs required packages: Java runtime, Python, pip, AWS CLI, timezone data, curl, unzip, bash, jq, nss
- Cleans up cache to reduce image size
- Creates JMeter home directory
- Extracts JMeter binaries
- Removes the tarball after extraction

---

## 5. Default Command

Runs the JMeter test and uploads results to AWS S3:

```dockerfile
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
```

### Explanation:
- Clears previous log and result files
- Updates PATH to include user-local binaries (for AWS CLI)
- Runs JMeter in non-GUI mode with specified test plan and parameters:
  - `threads=1000`: Number of virtual users
  - `rampup=100`: Ramp-up period in seconds
  - `duration=3600`: Test duration in seconds (1 hour)
- Retrieves local and public IP addresses
- Renames result and log files to include IP info
- Uploads the renamed files to an S3 bucket (replace `s3://bucket/` with your actual bucket)

---

## Summary

This Dockerfile automates the setup of a JMeter load testing environment with AWS integration, enabling scalable, repeatable performance tests whose results are automatically uploaded to S3 for analysis.