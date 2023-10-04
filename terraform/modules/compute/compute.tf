# RESOURCE: EC2 LAUNCH TEMPLATE

data "template_file" "user_data" {
    template = "${file("./modules/compute/scripts/user_data.sh")}"
    vars = {
        rds_endpoint      = "${var.rds_endpoint}"
        rds_dbuser        = "${var.rds_dbuser}"
        rds_dbpassword    = "${var.rds_dbpassword}"
        rds_dbname        = "${var.rds_dbname}"
        # access_key_id     = "${var.access_key_id}"
        # secret_access_key = "${var.secret_access_key}"
        # session_token     = "${var.session_token}"
    }
}

resource "aws_launch_template" "ec2_lt" {
    name                   = "${var.ec2_lt_name}"
    image_id               = "${var.ec2_lt_ami}"
    instance_type          = "${var.ec2_lt_instance_type}"
    key_name               = "${var.ec2_lt_ssh_key_name}"

    user_data              = <<-EOF
                              #!/bin/bash


# 1- Update/Install required OS packages
yum update -y
amazon-linux-extras install -y php7.2 epel
yum install -y httpd mysql php-mtdowling-jmespath-php php-xml telnet tree git


# 2- (Optional) Enable PHP to send AWS SNS events
# NOTE: If uncommented, more configs are required
# - Step 4: Deploy PHP app
# - Module Compute: compute.tf and vars.tf manifests

# 2.1- Config AWS SDK for PHP
# mkdir -p /opt/aws/sdk/php/
# cd /opt/aws/sdk/php/
# wget https://docs.aws.amazon.com/aws-sdk-php/v3/download/aws.zip
# unzip aws.zip

# 2.2- Config AWS Account
# mkdir -p /var/www/html/.aws/
# cat <<EOT >> /var/www/html/.aws/credentials
# [default]
# aws_access_key_id=12345
# aws_secret_access_key=12345
# aws_session_token=12345
# EOT


# 3- Config PHP app Connection to Database
cat <<EOT >> /var/www/config.php
<?php
define('DB_SERVER', '${rds_endpoint}');
define('DB_USERNAME', '${rds_dbuser}');
define('DB_PASSWORD', '${rds_dbpassword}');
define('DB_DATABASE', '${rds_dbname}');
?>
EOT


# 4- Deploy PHP app
cd /tmp
git clone https://github.com/kledsonhugo/notifier
cp /tmp/notifier/app/*.php /var/www/html/
# mv /var/www/html/sendsms.php /var/www/html/index.php
rm -rf /tmp/notifier


# 5- Config Apache WebServer
usermod -a -G apache ec2-user
chown -R ec2-user:apache /var/www
chmod 2775 /var/www
find /var/www -type d -exec chmod 2775 {} \;
find /var/www -type f -exec chmod 0664 {} \;


# 6- Start Apache WebServer
systemctl enable httpd
service httpd restart
                              EOF

    vpc_security_group_ids = ["${var.vpc_sg_pub_id}"]
}



# RESOURCE: APPLICATION LOAD BALANCER

resource "aws_lb" "ec2_lb" {
    name               = "${var.ec2_lb_name}"
    load_balancer_type = "application"
    subnets            = ["${var.vpc_sn_pub_az1_id}", "${var.vpc_sn_pub_az2_id}"]
    security_groups    = ["${var.vpc_sg_pub_id}"]
}

resource "aws_lb_target_group" "ec2_lb_tg" {
    name     = "${var.ec2_lb_tg_name}"
    protocol = "${var.ec2_lb_tg_protocol}"
    port     = "${var.ec2_lb_tg_port}"
    vpc_id   = "${var.vpc_id}"
}

resource "aws_lb_listener" "ec2_lb_listener" {
    protocol          = "${var.ec2_lb_listener_protocol}"
    port              = "${var.ec2_lb_listener_port}"
    load_balancer_arn = aws_lb.ec2_lb.arn
    
    default_action {
        type             = "${var.ec2_lb_listener_action_type}"
        target_group_arn = aws_lb_target_group.ec2_lb_tg.arn
    }
}


# RESOURCE: AUTO SCALING GROUP

resource "aws_autoscaling_group" "ec2_asg" {
    name                = "${var.ec2_asg_name}"
    desired_capacity    = "${var.ec2_asg_desired_capacity}"
    min_size            = "${var.ec2_asg_min_size}"
    max_size            = "${var.ec2_asg_max_size}"
    vpc_zone_identifier = ["${var.vpc_sn_pub_az1_id}", "${var.vpc_sn_pub_az2_id}"]
    target_group_arns   = [aws_lb_target_group.ec2_lb_tg.arn]
    launch_template {
        id      = aws_launch_template.ec2_lt.id
        version = "$Latest"
    }
}