local data_launch_template = import 'data-launch-template.jsonnet';
// local data_node_template = import 'data-node-template.jsonnet';
local build_data_nodes = function(data_node_index) if data_node_index == 0 then [] else build_data_nodes(data_node_index - 1) + [data_node_index];

function(data_node_count=2) {
    "AWSTemplateFormatVersion": "2010-09-09",
    "Description": "InfluxDB Enterprise",
    "Metadata": {
        "AWS::CloudFormation::Interface": {
            "ParameterGroups": [
                {
                    "Label": {
                        "default": "Network Configuration"
                    },
                    "Parameters": [
                        "VpcClassB",
                        "InfluxDBIngressCIDR",
                        "KeyName",
                        "SSHCIDR"
                    ]
                },
                {
                    "Label": {
                        "default": "InfluxDB Configuration"
                    },
                    "Parameters": [
                        "Username",
                        "Password",
                        "DataNodeDiskSize",
                        "DataNodeDiskIops"
                    ]
                }
            ],
            "ParameterLabels": {
                "KeyName": {
                    "default": "SSH Key Name"
                },
                "InfluxDBIngressCIDR": {
                    "default": "InfluxDB ingress CIDR (Public IPv4 address range of InfluxDB users)"
                },
                "SSHCIDR": {
                    "default": "SSH Access CIDR (Public IPv4 address range of the administrator's network)"
                },
                "Username": {
                    "default": "InfluxDB Administrator Username"
                },
                "Password": {
                    "default": "InfluxDB Administrator Password"
                },
                "DataNodeInstanceType": {
                    "default": "InfluxDB Data Node Instance Type"
                },
                "DataNodeDiskSize": {
                    "default": "InfluxDB Data Node Disk Size"
                },
                "DataNodeDiskIops": {
                    "default": "InfluxDB Data Node Disk IOPS"
                },
                "MetaNodeInstanceType": {
                    "default": "InfluxDB Meta Node Instance Type"
                },
                "MonitorInstanceType": {
                    "default": "InfluxDB Monitor Instance Type"
                }
            }
        }
    },
    "Parameters": {
        "VpcClassB": {
            "Type": "Number",
            "Description": "Class B of Virtual Private Cloud's (VPC) CIDR, e.g. 10.XXX.0.0/16",
            "Default": 0,
            "ConstraintDescription": "Allowed values are 0 through 255",
            "MinValue": 0,
            "MaxValue": 255
        },
        "Username": {
            "Description": "Username for the initial cluster administrator user",
            "Type": "String"
        },
        "Password": {
            "Description": "Password for cluster administrator user",
            "Type": "String",
            "NoEcho": true
        },
        "DataNodeInstanceType": {
            "Description": "Instance type for data nodes",
            "Type": "String",
            "Default": "m5.large",
            "AllowedValues": [
                "m4.xlarge",
                "m4.2xlarge",
                "m4.4xlarge",
                "m4.10xlarge",
                "m4.16xlarge",
                "m5.large",
                "m5.xlarge",
                "m5.2xlarge",
                "m5.4xlarge",
                "m5.8xlarge",
                "m5.12xlarge",
                "m5.16xlarge",
                "m5.24xlarge",
                "c4.xlarge",
                "c4.2xlarge",
                "c4.4xlarge",
                "c4.8xlarge",
                "c5.xlarge",
                "c5.2xlarge",
                "c5.4xlarge",
                "c5.9xlarge",
                "c5.12xlarge",
                "c5.18xlarge",
                "c5.24xlarge",
                "r4.xlarge",
                "r4.2xlarge",
                "r4.4xlarge",
                "r4.8xlarge",
                "r4.16xlarge",
                "r5.xlarge",
                "r5.2xlarge",
                "r5.4xlarge",
                "r5.8xlarge",
                "r5.12xlarge",
                "r5.16xlarge",
                "r5.24xlarge",
                "r5.xlarge"
            ],
            "ConstraintDescription": "must be a valid EC2 instance type."
        },
        "DataNodeDiskSize": {
            "Description": "Size in GB of the EBS io1 volume on each data node",
            "Type": "Number",
            "Default": 250
        },
        "DataNodeDiskIops": {
            "Description": "IOPS of the EBS io1 volume on each data node",
            "Type": "Number",
            "Default": 1000
        },
        "MetaNodeInstanceType": {
            "Description": "Instance type for meta nodes",
            "Type": "String",
            "Default": "t3.small",
            "AllowedValues": [
                "t2.small",
                "t2.medium",
                "t2.large",
                "t3.small",
                "t3.medium",
                "t3.large"
            ],
            "ConstraintDescription": "must be a valid EC2 instance type."
        },
        "MonitorInstanceType": {
            "Description": "Instance type for monitoring node",
            "Type": "String",
            "Default": "t3.small",
            "AllowedValues": [
                "t2.small",
                "t2.medium",
                "t2.large",
                "t3.small",
                "t3.medium",
                "t3.large"
            ],
            "ConstraintDescription": "must be a valid EC2 instance type."
        },
        "KeyName": {
            "Description": "Name of an existing EC2 KeyPair to enable SSH access to the instances",
            "Type": "AWS::EC2::KeyPair::KeyName",
            "ConstraintDescription": "must be the name of an existing EC2 KeyPair."
        },
        "InfluxDBIngressCIDR": {
            "Description": "The IP address range that can be used to connect to the InfluxDB API endpoint",
            "Type": "String",
            "MinLength": "9",
            "MaxLength": "18",
            "AllowedPattern": "(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})/(\\d{1,2})",
            "ConstraintDescription": "must be a valid IP CIDR range of the form x.x.x.x/x."
        },
        "SSHCIDR": {
            "Description": "The IP address range that can be used to SSH to the EC2 instances",
            "Type": "String",
            "MinLength": "9",
            "MaxLength": "18",
            "AllowedPattern": "(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})/(\\d{1,2})",
            "ConstraintDescription": "must be a valid IP CIDR range of the form x.x.x.x/x."
        }
    },
    "Outputs": {
        "InfluxDBAPIEndpoint": {
            "Description": "The ALB endpoint that can be used to access the InfluxDB API. Listens on port 8086.",
            "Value": {
                "Fn::GetAtt": [
                    "InfluxDBLoadBalancer",
                    "DNSName"
                ]
            },
            "Export": {
                "Name": {
                    "Fn::Join": [
                        ":",
                        [
                            {
                                "Ref": "AWS::StackName"
                            },
                            "InfluxDBAPIEndpoint"
                        ]
                    ]
                }
            }
        }
    },
    "Mappings": {
        "AMIRegionMap": {
            "us-east-1": {
                "Data": "ami-0c63a32c3ab901af4",
                "Meta": "ami-02f1f34d3582babdc",
                "Monitor": "ami-090cf6257fe0c8a8c"
            }
        }
    },
    "Resources": {
        "VPC": {
            "Type": "AWS::EC2::VPC",
            "Properties": {
                "CidrBlock": {
                    "Fn::Sub": "10.${VpcClassB}.0.0/16"
                },
                "EnableDnsSupport": true,
                "EnableDnsHostnames": true,
                "InstanceTenancy": "default"
            }
        },
        "InternetGateway": {
            "Type": "AWS::EC2::InternetGateway"
        },
        "VPCGatewayAttachment": {
            "Type": "AWS::EC2::VPCGatewayAttachment",
            "Properties": {
                "InternetGatewayId": {
                    "Ref": "InternetGateway"
                },
                "VpcId": {
                    "Ref": "VPC"
                }
            }
        },
        "RouteTable": {
            "Type": "AWS::EC2::RouteTable",
            "Properties": {
                "VpcId": {
                    "Ref": "VPC"
                }
            }
        },
        "Route": {
            "DependsOn": "VPCGatewayAttachment",
            "Type": "AWS::EC2::Route",
            "Properties": {
                "RouteTableId": {
                    "Ref": "RouteTable"
                },
                "DestinationCidrBlock": "0.0.0.0/0",
                "GatewayId": {
                    "Ref": "InternetGateway"
                }
            }
        },
        "Subnet00": {
            "Type": "AWS::EC2::Subnet",
            "Properties": {
                "VpcId": {
                    "Ref": "VPC"
                },
                "CidrBlock": {
                    "Fn::Sub": "10.${VpcClassB}.0.0/20"
                },
                "AvailabilityZone": {
                    "Fn::Select": [
                        "0",
                        {
                            "Fn::GetAZs": ""
                        }
                    ]
                },
                "MapPublicIpOnLaunch": true
            }
        },
        "Subnet00RouteTableAssociation": {
            "Type": "AWS::EC2::SubnetRouteTableAssociation",
            "Properties": {
                "SubnetId": {
                    "Ref": "Subnet00"
                },
                "RouteTableId": {
                    "Ref": "RouteTable"
                }
            }
        },
        "Subnet01": {
            "Type": "AWS::EC2::Subnet",
            "Properties": {
                "VpcId": {
                    "Ref": "VPC"
                },
                "CidrBlock": {
                    "Fn::Sub": "10.${VpcClassB}.16.0/20"
                },
                "AvailabilityZone": {
                    "Fn::Select": [
                        "1",
                        {
                            "Fn::GetAZs": ""
                        }
                    ]
                },
                "MapPublicIpOnLaunch": true
            }
        },
        "Subnet01RouteTableAssociation": {
            "Type": "AWS::EC2::SubnetRouteTableAssociation",
            "Properties": {
                "SubnetId": {
                    "Ref": "Subnet01"
                },
                "RouteTableId": {
                    "Ref": "RouteTable"
                }
            }
        },
        "Subnet02": {
            "Type": "AWS::EC2::Subnet",
            "Properties": {
                "VpcId": {
                    "Ref": "VPC"
                },
                "CidrBlock": {
                    "Fn::Sub": "10.${VpcClassB}.32.0/20"
                },
                "AvailabilityZone": {
                    "Fn::Select": [
                        "2",
                        {
                            "Fn::GetAZs": ""
                        }
                    ]
                },
                "MapPublicIpOnLaunch": true
            }
        },
        "Subnet02RouteTableAssociation": {
            "Type": "AWS::EC2::SubnetRouteTableAssociation",
            "Properties": {
                "SubnetId": {
                    "Ref": "Subnet02"
                },
                "RouteTableId": {
                    "Ref": "RouteTable"
                }
            }
        },
        "InfluxDBPrivateHostedZone": {
            "Type": "AWS::Route53::HostedZone",
            "Properties": {
                "Name": "internal",
                "VPCs": [
                    {
                        "VPCId": {
                            "Ref": "VPC"
                        },
                        "VPCRegion": {
                            "Ref": "AWS::Region"
                        }
                    }
                ]
            }
        },
        "InfluxDBLoadBalancerRecordSet": {
            "Type": "AWS::Route53::RecordSet",
            "Properties": {
                "AliasTarget": {
                    "DNSName": {
                        "Fn::GetAtt": [
                            "InfluxDBLoadBalancer",
                            "DNSName"
                        ]
                    },
                    "HostedZoneId": {
                        "Fn::GetAtt": [
                            "InfluxDBLoadBalancer",
                            "CanonicalHostedZoneID"
                        ]
                    }
                },
                "HostedZoneId": {
                    "Ref": "InfluxDBPrivateHostedZone"
                },
                "Name": "influxdb.internal",
                "Type": "A"
            }
        },
        "InfluxDBLoadBalancer": {
            "Type": "AWS::ElasticLoadBalancingV2::LoadBalancer",
            "Properties": {
                "SecurityGroups": [
                    {
                        "Ref": "InfluxDBALBSecurityGroup"
                    }
                ],
                "Subnets": [
                    {
                        "Ref": "Subnet00"
                    },
                    {
                        "Ref": "Subnet01"
                    },
                    {
                        "Ref": "Subnet02"
                    }
                ]
            }
        },
        "InfluxDBLoadBalancerListener": {
            "Type": "AWS::ElasticLoadBalancingV2::Listener",
            "Properties": {
                "DefaultActions": [
                    {
                        "Type": "forward",
                        "TargetGroupArn": {
                            "Ref": "InfluxDBLoadBalancerTargetGroup"
                        }
                    }
                ],
                "LoadBalancerArn": {
                    "Ref": "InfluxDBLoadBalancer"
                },
                "Port": 8086,
                "Protocol": "HTTP"
            }
        },
        "InfluxDBLoadBalancerTargetGroup": {
            "Type": "AWS::ElasticLoadBalancingV2::TargetGroup",
            "Properties": {
                "HealthCheckIntervalSeconds": 30,
                "HealthCheckPath": "/ping",
                "HealthCheckPort": "8086",
                "HealthCheckProtocol": "HTTP",
                "HealthCheckTimeoutSeconds": 10,
                "HealthyThresholdCount": 2,
                "Matcher": {
                    "HttpCode": "204"
                },
                "Port": 8086,
                "Protocol": "HTTP",
                "UnhealthyThresholdCount": 2,
                "VpcId": {
                    "Ref": "VPC"
                }
            }
        },
        "InfluxDBInstanceProfile": {
            "Type": "AWS::IAM::InstanceProfile",
            "Properties": {
                "Roles": [
                    {
                        "Ref": "InfluxDBRole"
                    }
                ]
            }
        },
        "InfluxDBRole": {
            "Type": "AWS::IAM::Role",
            "Properties": {
                "AssumeRolePolicyDocument": {
                    "Version": "2012-10-17",
                    "Statement": [
                        {
                            "Effect": "Allow",
                            "Principal": {
                                "Service": [
                                    "ec2.amazonaws.com"
                                ]
                            },
                            "Action": [
                                "sts:AssumeRole"
                            ]
                        }
                    ]
                },
                "Policies": [
                    {
                        "PolicyName": "InfluxDBPolicy",
                        "PolicyDocument": {
                            "Version": "2012-10-17",
                            "Statement": [
                                {
                                    "Effect": "Allow",
                                    "Action": [
                                        "ec2:AttachNetworkInterface",
                                        "ec2:AttachVolume",
                                        "ec2:DescribeVolumes",
                                        "ec2:DescribeVolumeStatus",
                                        "ec2:DescribeInstances",
                                        "ec2:DescribeNetworkInterfaces",
                                        "ec2:DescribeTags",
                                        "autoscaling:DescribeAutoScalingGroups"
                                    ],
                                    "Resource": "*"
                                }
                            ]
                        }
                    }
                ]
            }
        },
        "SshSecurityGroup": {
            "Type": "AWS::EC2::SecurityGroup",
            "Properties": {
                "GroupDescription": "Allow external SSH traffic from SSH CIDR parameter",
                "SecurityGroupIngress": [
                    {
                        "IpProtocol": "tcp",
                        "FromPort": 22,
                        "ToPort": 22,
                        "CidrIp": {
                            "Ref": "SSHCIDR"
                        }
                    }
                ],
                "VpcId": {
                    "Ref": "VPC"
                }
            }
        },
        "InfluxDBALBSecurityGroup": {
            "Type": "AWS::EC2::SecurityGroup",
            "Properties": {
                "GroupDescription": "Allow traffic from public internet to go to port 8086 on InfluxDB data nodes",
                "VpcId": {
                    "Ref": "VPC"
                }
            }
        },
        "InfluxDBALBSGIngress": {
            "Type": "AWS::EC2::SecurityGroupIngress",
            "Properties": {
                "GroupId": {
                    "Ref": "InfluxDBALBSecurityGroup"
                },
                "IpProtocol": "tcp",
                "FromPort": 8086,
                "ToPort": 8086,
                "CidrIp": {
                    "Ref": "InfluxDBIngressCIDR"
                }
            }
        },
        "InfluxDBALBSGEgress": {
            "Type": "AWS::EC2::SecurityGroupEgress",
            "Properties": {
                "GroupId": {
                    "Ref": "InfluxDBALBSecurityGroup"
                },
                "IpProtocol": "tcp",
                "FromPort": 8086,
                "ToPort": 8086,
                "DestinationSecurityGroupId": {
                    "Ref": "InfluxDBDataNodeSecurityGroup"
                }
            }
        },
        "InfluxDBDataNodeSecurityGroup": {
            "Type": "AWS::EC2::SecurityGroup",
            "Properties": {
                "GroupDescription": "Allow traffic from ALB to go to port 8086 on InfluxDB data nodes",
                "VpcId": {
                    "Ref": "VPC"
                }
            }
        },
        "InfluxDBDataNodeSGIngress": {
            "Type": "AWS::EC2::SecurityGroupIngress",
            "Properties": {
                "GroupId": {
                    "Ref": "InfluxDBDataNodeSecurityGroup"
                },
                "IpProtocol": "tcp",
                "FromPort": 8086,
                "ToPort": 8086,
                "SourceSecurityGroupId": {
                    "Ref": "InfluxDBALBSecurityGroup"
                }
            }
        },
        "InfluxDBInternalSecurityGroup": {
            "Type": "AWS::EC2::SecurityGroup",
            "Properties": {
                "GroupDescription": "Allow all traffic between InfluxDB instances",
                "VpcId": {
                    "Ref": "VPC"
                }
            }
        },
        "InfluxDBInternalSGIngress": {
            "Type": "AWS::EC2::SecurityGroupIngress",
            "Properties": {
                "GroupId": {
                    "Ref": "InfluxDBInternalSecurityGroup"
                },
                "IpProtocol": "-1",
                "SourceSecurityGroupId": {
                    "Ref": "InfluxDBInternalSecurityGroup"
                }
            }
        },
        "InfluxDBInternalSGEgress": {
            "Type": "AWS::EC2::SecurityGroupEgress",
            "Properties": {
                "GroupId": {
                    "Ref": "InfluxDBInternalSecurityGroup"
                },
                "IpProtocol": "-1",
                "DestinationSecurityGroupId": {
                    "Ref": "InfluxDBInternalSecurityGroup"
                }
            }
        },
        DataNodeLaunchConfiguration: data_launch_template,
        build_data_nodes(data_node_count),
    }
}