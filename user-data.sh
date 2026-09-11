#!/bin/bash

# ============================================================
# UrjaSathi EC2 Bootstrap
# ============================================================

echo "USER DATA STARTED at $(date)" > /home/ubuntu/userdata_started.txt

# ============================================================
# LOGGING
# ============================================================

LOG_FILE="/var/log/urjasathi-user-data.log"

touch "$LOG_FILE"
chmod 644 "$LOG_FILE"

exec > >(tee -a "$LOG_FILE") 2>&1

# ============================================================
# ERROR HANDLING
# ============================================================

set -Eeuo pipefail

trap '
    EXIT_CODE=$?
    echo ""
    echo "============================================================"
    echo "ERROR: UrjaSathi User Data FAILED"
    echo "Time: $(date)"
    echo "Line: $LINENO"
    echo "Command: $BASH_COMMAND"
    echo "Exit code: $EXIT_CODE"
    echo "============================================================"
    touch /home/ubuntu/userdata_failed.txt
    exit $EXIT_CODE
' ERR

# ============================================================
# START
# ============================================================

echo ""
echo "============================================================"
echo "        UrjaSathi EC2 Bootstrap Started"
echo "============================================================"
echo "Started at: $(date)"
echo ""

# ============================================================
# SYSTEM INFORMATION
# ============================================================

echo "============================================================"
echo "SYSTEM INFORMATION"
echo "============================================================"

echo "Hostname:"
hostname

echo ""

echo "OS:"
cat /etc/os-release

echo ""

echo "Kernel:"
uname -a

echo ""

echo "Disk:"
df -h

echo ""

echo "Memory:"
free -h

# ============================================================
# STEP 1 - APT UPDATE
# ============================================================

echo ""
echo "============================================================"
echo "STEP 1: Updating apt"
echo "============================================================"

apt-get update -y

echo "STEP 1 COMPLETE: apt updated successfully."

# ============================================================
# STEP 2 - INSTALL BASIC PACKAGES
# ============================================================

echo ""
echo "============================================================"
echo "STEP 2: Installing basic packages"
echo "============================================================"

apt-get install -y \
    curl \
    ca-certificates \
    snapd

echo "STEP 2 COMPLETE: Basic packages installed."

# ============================================================
# STEP 3 - INSTALL DOCKER
# ============================================================

echo ""
echo "============================================================"
echo "STEP 3: Installing Docker"
echo "============================================================"

if command -v docker >/dev/null 2>&1; then

    echo "Docker is already installed."

else

    echo "Installing Docker from Ubuntu repository..."

    apt-get install -y docker.io

    echo "Docker package installed."

fi

echo "Docker binary:"
which docker

echo "Docker version:"
docker --version

# ============================================================
# STEP 4 - START DOCKER
# ============================================================

echo ""
echo "============================================================"
echo "STEP 4: Starting Docker"
echo "============================================================"

systemctl enable docker

systemctl start docker

echo "Checking Docker service..."

systemctl is-active docker

echo ""
echo "Docker service status:"
systemctl --no-pager status docker || true

echo "STEP 4 COMPLETE: Docker is running."

# ============================================================
# STEP 5 - INSTALL DOCKER COMPOSE
# ============================================================

echo ""
echo "============================================================"
echo "STEP 5: Installing Docker Compose"
echo "============================================================"

# Ubuntu repository does not provide docker-compose-plugin
# on this EC2 image, so install Compose as a CLI plugin.

DOCKER_CLI_PLUGIN_DIR="/usr/local/lib/docker/cli-plugins"

mkdir -p "$DOCKER_CLI_PLUGIN_DIR"

echo "Downloading Docker Compose..."

COMPOSE_VERSION="v2.39.2"

curl -SL \
    "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-x86_64" \
    -o "${DOCKER_CLI_PLUGIN_DIR}/docker-compose"

chmod +x "${DOCKER_CLI_PLUGIN_DIR}/docker-compose"

echo "Docker Compose installed."

echo "Docker Compose version:"

docker compose version

# ============================================================
# STEP 6 - CONFIGURE SNAPD
# ============================================================

echo ""
echo "============================================================"
echo "STEP 6: Configuring snapd"
echo "============================================================"

systemctl enable snapd

systemctl start snapd

echo "Waiting for snapd to initialize..."

sleep 10

echo "snap version:"
snap version

echo "STEP 6 COMPLETE: snapd is running."

# ============================================================
# STEP 7 - INSTALL AWS SSM AGENT
# ============================================================

echo ""
echo "============================================================"
echo "STEP 7: Installing AWS SSM Agent"
echo "============================================================"

if snap list amazon-ssm-agent >/dev/null 2>&1; then

    echo "SSM Agent is already installed."

else

    echo "SSM Agent is not installed."

    echo "Installing SSM Agent..."

    snap install amazon-ssm-agent --classic

    echo "SSM Agent installation completed."

fi

echo ""
echo "SSM Agent package:"
snap list amazon-ssm-agent

echo ""
echo "Enabling SSM Agent service..."

systemctl enable \
    snap.amazon-ssm-agent.amazon-ssm-agent.service

echo "Starting SSM Agent..."

systemctl start \
    snap.amazon-ssm-agent.amazon-ssm-agent.service

echo ""
echo "SSM Agent service status:"

systemctl --no-pager status \
    snap.amazon-ssm-agent.amazon-ssm-agent.service || true

echo "STEP 7 COMPLETE: SSM Agent configured."

# ============================================================
# STEP 8 - CREATE PROJECT DIRECTORIES
# ============================================================

echo ""
echo "============================================================"
echo "STEP 8: Creating UrjaSathi directories"
echo "============================================================"

mkdir -p /opt/urjasathi

mkdir -p /opt/urjasathi/deploy

mkdir -p /opt/urjasathi/logs

echo "Project directories created."

echo ""
echo "Directory structure:"
find /opt/urjasathi -maxdepth 2 -type d -print

echo "STEP 8 COMPLETE."

# ============================================================
# STEP 9 - CREATE DOCKER COMPOSE FILE
# ============================================================

echo ""
echo "============================================================"
echo "STEP 9: Creating Docker Compose configuration"
echo "============================================================"

cat > /opt/urjasathi/deploy/docker-compose.prod.yml <<'EOF'
services:

  backend:
    image: ${DOCKERHUB_USERNAME}/urjasathi-backend:${IMAGE_TAG}
    container_name: urjasathi-backend
    restart: unless-stopped
    env_file:
      - .env
    expose:
      - "8000"

  frontend:
    image: ${DOCKERHUB_USERNAME}/urjasathi-frontend:${IMAGE_TAG}
    container_name: urjasathi-frontend
    restart: unless-stopped
    depends_on:
      - backend
    ports:
      - "80:80"
EOF

echo "Docker Compose file created."

echo ""
echo "============================================================"
echo "docker-compose.prod.yml"
echo "============================================================"

cat /opt/urjasathi/deploy/docker-compose.prod.yml

echo "STEP 9 COMPLETE."

# ============================================================
# STEP 10 - DOCKER GROUP
# ============================================================

echo ""
echo "============================================================"
echo "STEP 10: Configuring Docker permissions"
echo "============================================================"

usermod -aG docker ubuntu

echo "User ubuntu added to docker group."

echo "STEP 10 COMPLETE."

# ============================================================
# STEP 11 - PROJECT PERMISSIONS
# ============================================================

echo ""
echo "============================================================"
echo "STEP 11: Configuring project permissions"
echo "============================================================"

chown -R ubuntu:ubuntu /opt/urjasathi

chmod 755 /opt/urjasathi

chmod 755 /opt/urjasathi/deploy

echo "Project permissions configured."

echo "STEP 11 COMPLETE."

# ============================================================
# STEP 12 - FINAL VERIFICATION
# ============================================================

echo ""
echo "============================================================"
echo "STEP 12: FINAL VERIFICATION"
echo "============================================================"

echo ""
echo "----- Docker -----"

docker --version

echo ""
echo "----- Docker Compose -----"

docker compose version

echo ""
echo "----- Docker Service -----"

systemctl is-active docker

echo ""
echo "----- SSM Agent -----"

systemctl is-active \
    snap.amazon-ssm-agent.amazon-ssm-agent.service

echo ""
echo "----- Project Directory -----"

ls -la /opt/urjasathi

echo ""
echo "----- Deploy Directory -----"

ls -la /opt/urjasathi/deploy

echo ""
echo "----- Compose File -----"

test -f /opt/urjasathi/deploy/docker-compose.prod.yml

echo "docker-compose.prod.yml exists."

# ============================================================
# STEP 13 - SUCCESS
# ============================================================

echo ""
echo "============================================================"
echo "STEP 13: BOOTSTRAP SUCCESSFUL"
echo "============================================================"

cat > /opt/urjasathi/bootstrap-complete.txt <<EOF
UrjaSathi EC2 bootstrap completed successfully.

Completed at:
$(date)

Docker:
$(docker --version)

Docker Compose:
$(docker compose version)

SSM:
$(systemctl is-active snap.amazon-ssm-agent.amazon-ssm-agent.service)
EOF

touch /home/ubuntu/userdata_completed.txt

echo ""
echo "============================================================"
echo "        URJASATHI BOOTSTRAP COMPLETE"
echo "============================================================"
echo "Completed at: $(date)"
echo ""
echo "Log:"
echo "/var/log/urjasathi-user-data.log"
echo ""
echo "Success marker:"
echo "/home/ubuntu/userdata_completed.txt"
echo ""
echo "============================================================"