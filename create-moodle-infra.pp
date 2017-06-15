# Brings up a moodle infrastructure in AWS:
# 
# - Load balancer
# - 2 x EC2 instances (web servers)
# - RDS database (MySQL)
# - Security groups
#
# This uses the puppetlabs/puppetlabs-aws module:
#  https://github.com/puppetlabs/puppetlabs-aws
#
# EFS storage (for moodledata) and ElastiCache (memcache)
# would need to be setup manually as the puppetlabs-aws module
# does not support these resources currently.
#

# Set some defaults

Ec2_securitygroup {
  region => 'eu-west-1',
}

Ec2_instance {
  region            => 'eu-west-1',
  availability_zone => 'eu-west-1a',
}

Elb_loadbalancer {
  region => 'eu-west-1',
}

# Create security groups

ec2_securitygroup { 'example-moodle-lb-sg':
  ensure      => present,
  description => 'Security group for example moodle load balancer',
  ingress     => [{
    protocol => 'tcp',
    port     => 80,
    cidr     => '0.0.0.0/0'
  },{
    protocol => 'tcp',
    port     => 443,
    cidr     => '0.0.0.0/0'
  }],
}

ec2_securitygroup { 'example-moodle-web-sg':
  ensure      => present,
  description => 'Security group for example moodle web servers',
  ingress     => [{
    security_group => 'example-moodle-lb-sg',
  },{
    protocol => 'tcp',
    port     => 22,
    cidr     => '193.1.228.0/24'
  }],
}

# Web servers

ec2_instance { ['example-moodle-web-1', 'example-moodle-web-2']:
  ensure          => present,
  image_id        => 'ami-b8c41ccf',
  subnet          => <YOUR_SUBNET_HERE> # eg: subnet-3ca74f65
  security_groups => ['example-moodle-web-sg'],
  instance_type   => 't2.micro',
  tenancy         => 'default',
  tags            => {
    project    => 'example-moodle',
    created_by => $::id,
  }
}

# RDS databases

rds_instance { 'example-moodle-db':
  ensure                  => 'present',
  allocated_storage       => '5',
  backup_retention_period => '7',
  db_instance_class       => 'db.t2.small',
  db_name                 => 'example_moodle',
  db_parameter_group      => 'default.mysql5.6',
  db_subnet               => 'default',
  engine                  => 'mysql',
  engine_version          => '5.6.27',
  master_username         => 'moodle',
  multi_az                => 'true',
  port                    => '3306',
  region                  => 'eu-west-1',
  storage_type            => 'gp2',
  rds_tags                => {
    project    => 'example-moodle',
    created_by => $::id,
  }
}

# Load Balancer

elb_loadbalancer { 'example-moodle-lb-1':
  ensure             => present,
  availability_zones => ['eu-west-1a'],
  instances          => ['example-moodle-web-1', 'example-moodle-web-2'],
  listeners          => [{
    protocol           => 'tcp',
    load_balancer_port => 80,
    instance_protocol  => 'tcp',
    instance_port      => 80,
  },{
    protocol           => 'tcp',
    load_balancer_port => 443,
    instance_protocol  => 'tcp',
    instance_port      => 80,
  }],
}
