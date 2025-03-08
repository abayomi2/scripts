#!/bin/bash

# Exit on error and catch failures in pipes
set -e
set -o pipefail

# Function to install dependencies
install_dependencies() {
    echo "Installing required dependencies..."
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y wget curl tar gnupg2
}

# Function to install default Java
install_java() {
    echo "Installing default Java..."
    sudo apt install -y default-jdk

    # Set JAVA_HOME dynamically
    JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))
    echo "export JAVA_HOME=${JAVA_HOME}" | sudo tee /etc/profile.d/java.sh > /dev/null
    echo "Java installed at $JAVA_HOME"
}

# Function to install Maven
install_maven() {
    echo "Installing Maven..."
    sudo apt install -y maven
    echo "Maven installed."
}

# Function to install Jenkins
install_jenkins() {
    echo "Installing Jenkins..."

    # Remove any previous Jenkins repo list if it exists
    sudo rm -f /etc/apt/sources.list.d/jenkins.list

    # Add Jenkins GPG key securely
    curl -fsSL https://pkg.jenkins.io/debian/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null

    # Add Jenkins repository with secure key verification
    echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

    sudo apt update
    sudo apt install -y jenkins

    # Enable and start Jenkins
    sudo systemctl enable --now jenkins
    echo "Jenkins installation complete."
}

# Function to set environment variables
set_environment_variables() {
    echo "Setting up environment variables..."

    ENV_FILE="/etc/profile.d/java.sh"
    echo "export JAVA_HOME=${JAVA_HOME}" | sudo tee "$ENV_FILE" > /dev/null
    echo "export M2_HOME=/usr/share/maven" | sudo tee -a "$ENV_FILE" > /dev/null
    echo "export MAVEN_HOME=/usr/share/maven" | sudo tee -a "$ENV_FILE" > /dev/null
    echo "export PATH=\$PATH:\$JAVA_HOME/bin:\$M2_HOME/bin" | sudo tee -a "$ENV_FILE" > /dev/null

    echo "Environment variables set. Run 'source $ENV_FILE' or restart the shell to apply changes."
}

# Function to enable password authentication for SSH
enable_password_authentication() {
    echo "Enabling password authentication for SSH..."

    # Modify SSH configuration securely
    sudo sed -i 's/^#PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sudo sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

    # Restart SSH service
    sudo systemctl restart ssh
    echo "WARNING: Password authentication for SSH is enabled. Consider using SSH keys instead."
}

# Main script execution
install_dependencies
install_java
install_maven
install_jenkins
set_environment_variables
enable_password_authentication

# Verify installations
echo "Verifying installations..."
java -version
mvn -version
sudo systemctl status jenkins --no-pager

echo "Installation complete!"
