#!/bin/bash

# Install SSM Agent manually
dnf install -y amazon-ssm-agent

# Enable and start SSM Agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Update packages
dnf update -y

# Install nginx and cloudwatch agent
dnf install -y nginx
dnf install -y amazon-cloudwatch-agent
systemctl start nginx
systemctl enable nginx

# Check SSM status after install
systemctl status amazon-ssm-agent > /tmp/ssm-status.txt 2>&1
cp /tmp/ssm-status.txt /usr/share/nginx/html/ssm.txt

# Fetch instance ID
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)

# 3.sync images from S3 bucket to nginx html directory every minute using a cron job
mkdir -p /usr/share/nginx/html/images
chown -R nginx:nginx /usr/share/nginx/html/images

cat <<EOF > /usr/local/bin/sync_s3.sh
#!/bin/bash
/usr/bin/aws s3 sync s3://${static_bucket_name}/images /usr/share/nginx/html/images --delete
chown -R nginx:nginx /usr/share/nginx/html/images
EOF

chmod +x /usr/local/bin/sync_s3.sh

/usr/local/bin/sync_s3.sh

echo "*/1 * * * * root /usr/local/bin/sync_s3.sh" >> /etc/crontab

# 4. Create the main page with the image
# Note: We will place the image inside an <img> tag and specify its width to make it look consistent
cat <<HTML > /usr/share/nginx/html/index.html
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="UTF-8">
    <title>Aymen's Cloud App</title>
    <style>
        body { font-family: sans-serif; text-align: center; padding-top: 50px; background-color: #f4f4f4; }
        .container { background: white; padding: 20px; border-radius: 10px; display: inline-block; box-shadow: 0 4px 8px rgba(0,0,0,0.1); }
        img { max-width: 400px; border-radius: 10px; margin-top: 20px; border: 3px solid #0093d0; }
        h1 { color: #232f3e; } /* AWS Navy Blue */
    </style>
</head>
<body>
    <div class="container">
        <h1>Hello, welcome to Aymen's Cloud App</h1>
        <p>i wanna just tell u: شكراً لقبول طلب الصداقة</p>
        
        <img src="images/cat.jpg" alt="Cat's Picture">
        
        <p style="color: gray; font-size: 0.8em; margin-top: 20px;">
            Served by EC2 Instance: <b>$INSTANCE_ID</b>
        </p>
    </div>
</body>
</html>
HTML

# Fetch CloudWatch Agent config from SSM Parameter Store and start the agent.
# The parameter path uses the environment name injected by Terraform templatefile().
# -a fetch-config : fetch and apply the config
# -m ec2          : running on EC2
# -s              : start the agent after applying config
# -c ssm:...      : SSM parameter path to fetch config from
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c ssm:/ec2/${environment}/cloudwatch-agent-config