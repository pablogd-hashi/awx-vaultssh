# Use Fedora as the base image
FROM fedora:latest

# Install necessary packages
RUN dnf install -y openssh-server sudo && dnf clean all

# Create a new user
RUN useradd -m -s /bin/bash rhel 

# Enable passwordless sudo for the new user
RUN echo "rhel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Set up SSH daemon config
RUN mkdir -p /var/run/sshd && \
    echo "PermitRootLogin no" >> /etc/ssh/sshd_config && \
    echo "AllowUsers rhel" >> /etc/ssh/sshd_config && \
    echo "AuthorizedKeysCommand none" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication no" >> /etc/ssh/sshd_config && \
    echo "ListenAddress 0.0.0.0" >> /etc/ssh/sshd_config && \
    echo "TrustedUserCAKeys /etc/ssh/trusted-user-ca-keys.pem" >> /etc/ssh/sshd_config && \
    echo "LogLevel VERBOSE" >> /etc/ssh/sshd_config  # Enable verbose logging

# Generate SSH host keys
RUN ssh-keygen -A

# Expose the SSH port
EXPOSE 22

# Start the SSH service with debug logging
CMD ["/usr/sbin/sshd", "-D", "-e"]