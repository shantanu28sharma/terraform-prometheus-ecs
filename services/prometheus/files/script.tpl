#!/bin/bash
# #cloud-config
# package_upgrade: true
# packages:
#   - aws-cli
#   - ec2-instance-connect
#   - jq

# runcmd:
#   - yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
#   - systemctl enable amazon-ssm-agent
#   - systemctl start amazon-ssm-agent
#   - /bin/bash /root/config_sync.sh
#   - /bin/bash /root/init.sh

# write_files:
#   - path: /root/init.sh
#     permissions: '0755'
#     owner: root:root
#     content: |
#       #!/bin/bash
#       set -ex

#       AWS_EC2_AVAIL_ZONE=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
#       AWS_INSTANCE_ID=`curl -s http://169.254.169.254/latest/meta-data/instance-id`

#       # Attach EBS
#       aws ec2 attach-volume --volume-id ${ebs_id_prometheus} --instance-id $AWS_INSTANCE_ID --device /dev/xvdx --region us-east-1
#       aws ec2 attach-volume --volume-id ${ebs_id_grafana}    --instance-id $AWS_INSTANCE_ID --device /dev/xvdz --region us-east-1

#       # Wait few seconds for attaching
#       sleep 10

#       # Mount EBS there is some weird stuff going on with nvme attaching instead of xvd devices
#       mkdir -p /var/lib/prometheus
#       mount /dev/nvme1n1 /var/lib/prometheus
#       chown 65534:65534 /var/lib/prometheus/

#       mkdir -p /var/lib/grafana
#       mount /dev/nvme2n1 /var/lib/grafana
#       chown 472:472 /var/lib/grafana/

#   - path: /root/config_sync.sh
#     permissions: '0755'
#     owner: root:root
#     content: |
#       #!/bin/bash
#       set -ex

#       # Copy configuration
#       aws s3 cp --recursive s3://${bucket_config}/prometheus /etc/prometheus/
#       aws s3 cp --recursive s3://${bucket_config}/alertmanager /etc/alertmanager/

#       # Enable cron to sync files

#       # If doesn't exist create /etc/prometheus/ecs_file_sd.yml

#   # ECS Config
#   -   content: |
#         ECS_CLUSTER=${cluster_name}
#         AWS_DEFAULT_REGION=${aws_region}
#       path: /etc/ecs/ecs.config
#       owner: root:root
#       permissions: '0644'
        

#install dependencies
yum install -y aws-cli ec2-instance-connect jq

yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

touch /root/init.sh
touch /root/config_sync.sh

echo ECS_CLUSTER=${cluster_name} >> /etc/ecs/ecs.config
echo AWS_DEFAULT_REGION=${aws_region} >> /etc/ecs/ecs.config

chmod 0755 /root/config_sync.sh
chmod 0755 /root/init.sh

echo set -ex >> /root/config_sync.sh
echo aws s3 cp --recursive s3://${bucket_config}/prometheus /etc/prometheus/ >> /root/config_sync.sh
echo aws s3 cp --recursive s3://${bucket_config}/alertmanager /etc/alertmanager/ >> /root/config_sync.sh

echo AWS_EC2_AVAIL_ZONE=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone` >> /root/init.sh
echo AWS_INSTANCE_ID=`curl -s http://169.254.169.254/latest/meta-data/instance-id` >> /root/init.sh
echo aws ec2 attach-volume --volume-id ${ebs_id_prometheus} --instance-id $AWS_INSTANCE_ID --device /dev/xvdx --region us-east-1 >> /root/init.sh
echo aws ec2 attach-volume --volume-id ${ebs_id_grafana}    --instance-id $AWS_INSTANCE_ID --device /dev/xvdz --region us-east-1 >> /root/init.sh
echo sleep 10 >> /root/init.sh
echo mkdir -p /var/lib/prometheus >> /root/init.sh
echo mount /dev/nvme1n1 /var/lib/prometheus >> /root/init.sh
echo chown 65534:65534 /var/lib/prometheus/  >> /root/init.sh
echo mkdir -p /var/lib/grafana >> /root/init.sh
echo mount /dev/nvme2n1 /var/lib/grafana >> /root/init.sh
echo chown 472:472 /var/lib/grafana/ >> /root/init.sh

/bin/bash /root/config_sync.sh
/bin/bash /root/init.sh
