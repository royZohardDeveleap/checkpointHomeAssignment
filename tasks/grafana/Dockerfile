FROM grafana/grafana:latest

# Install CloudWatch plugin
RUN grafana-cli plugins install cloudwatch

# Copy provisioning configuration
COPY provisioning/datasources /etc/grafana/provisioning/datasources
COPY provisioning/dashboards /etc/grafana/provisioning/dashboards

# Copy dashboard JSON files
COPY dashboards /var/lib/grafana/dashboards

# Set environment variables
ENV GF_AUTH_ANONYMOUS_ENABLED=false
ENV GF_SECURITY_ADMIN_PASSWORD=admin
ENV GF_INSTALL_PLUGINS=""

USER grafana

EXPOSE 3000
