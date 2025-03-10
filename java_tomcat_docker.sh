#!/bin/bash

# Exit on error
set -e

# Function to install Java (default JDK)
install_java() {
    echo "Installing default Java (OpenJDK)..."

    # Install default JDK (Ubuntu)
    sudo apt update && sudo apt update -y
    sudo apt install -y default-jdk

    # Verify Java installation
    if ! command -v java &> /dev/null; then
        echo "Java installation failed or is not in the PATH." >&2
        exit 1
    fi

    # Set JAVA_HOME dynamically
    JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))
    echo "export JAVA_HOME=${JAVA_HOME}" | sudo tee /etc/profile.d/java.sh > /dev/null
    echo "export PATH=\$PATH:\$JAVA_HOME/bin" | sudo tee -a /etc/profile.d/java.sh > /dev/null

    echo "Java installation complete."
}

install_tomcat() {
    echo "Installing Tomcat 11.0.5..."

    # Set Tomcat version and paths
    TOMCAT_VERSION="11.0.5"
    TOMCAT_TAR="apache-tomcat-${TOMCAT_VERSION}.tar.gz"
    TOMCAT_URL="https://dlcdn.apache.org/tomcat/tomcat-11/v${TOMCAT_VERSION}/bin/${TOMCAT_TAR}"
    TOMCAT_DIR="/usr/local/tomcat"

    # Download Tomcat
    if wget -O /tmp/${TOMCAT_TAR} ${TOMCAT_URL}; then
        # Check if Tomcat directory already exists
        if [ -d "${TOMCAT_DIR}" ]; then
            echo "Existing Tomcat installation found. Backing up..."
            sudo mv ${TOMCAT_DIR} ${TOMCAT_DIR}_backup_$(date +%Y%m%d%H%M%S)
        fi

        # Extract Tomcat
        sudo tar -xvzf /tmp/${TOMCAT_TAR} -C /usr/local/
        
        # Rename the extracted folder
        sudo mv /usr/local/apache-tomcat-${TOMCAT_VERSION} ${TOMCAT_DIR}

        # Set permissions
        sudo groupadd -f tomcat
        sudo useradd -s /bin/false -g tomcat -d ${TOMCAT_DIR} tomcat || true
        sudo chown -R tomcat:tomcat ${TOMCAT_DIR}
        sudo chmod -R 755 ${TOMCAT_DIR}

        echo "Tomcat installation complete."
    else
        echo "Tomcat download failed." >&2
        exit 1
    fi
}

# Function to create a systemd service file for Tomcat
setup_tomcat_service() {
    echo "Creating Tomcat systemd service file..."

    # Create the systemd service file for Tomcat
    sudo tee /etc/systemd/system/tomcat.service > /dev/null <<EOL
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking

User=tomcat
Group=tomcat

Environment="JAVA_HOME=${JAVA_HOME}"
Environment="CATALINA_HOME=${TOMCAT_DIR}"
Environment="CATALINA_BASE=${TOMCAT_DIR}"
Environment="CATALINA_PID=${TOMCAT_DIR}/temp/tomcat.pid"
Environment="CATALINA_OPTS=-Xms512M -Xmx1024M"
ExecStartPre=/bin/rm -f \${CATALINA_PID}
ExecStart=${TOMCAT_DIR}/bin/startup.sh
ExecStop=${TOMCAT_DIR}/bin/shutdown.sh

[Install]
WantedBy=multi-user.target
EOL

    # Reload the systemd daemon to recognize the new Tomcat service
    sudo systemctl daemon-reload

    # Enable Tomcat to start on boot
    sudo systemctl enable tomcat

    # Start the Tomcat service
    sudo systemctl start tomcat

    echo "Tomcat systemd service setup complete."
}

# Function to install Docker
install_docker() {
    echo "Installing Docker..."

    # Install necessary packages for Docker
    sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

    # Add Docker repository
    sudo add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

    # Install Docker
    sudo apt update
    sudo apt install -y docker-ce

    # Add the current user to the Docker group
    sudo usermod -aG docker $USER
    newgrp docker
    echo "Docker installation complete. Please log out and back in for group changes to take effect."
}




# Function to set environment variables for Java and Tomcat
set_environment_variables() {
    echo "Setting up environment variables..."

    # Create or update the environment file for Java and Tomcat
    echo "export JAVA_HOME=${JAVA_HOME}" | sudo tee -a /etc/profile.d/java.sh > /dev/null
    echo "export CATALINA_HOME=${TOMCAT_DIR}" | sudo tee -a /etc/profile.d/java.sh > /dev/null
    echo "export PATH=\$PATH:\$JAVA_HOME/bin:\$CATALINA_HOME/bin" | sudo tee -a /etc/profile.d/java.sh > /dev/null

    # Load the environment variables
    source /etc/profile.d/java.sh

    echo "Environment variables set."
}

# Function to enable password authentication for SSH
enable_password_authentication() {
    echo "Enabling password authentication for SSH..."

    # Modify SSH config to allow password authentication
    sudo sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sudo sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

    # Restart the SSH service to apply changes
    sudo systemctl restart ssh

    echo "Password authentication enabled."
}

# Main script execution
install_java
install_tomcat
setup_tomcat_service
install_docker
set_environment_variables
enable_password_authentication

# Verify installations
echo "Verifying installations..."
java -version
echo "Tomcat installation directory: ${TOMCAT_DIR}"

echo "Java and Tomcat configuration complete!"
docker ps
