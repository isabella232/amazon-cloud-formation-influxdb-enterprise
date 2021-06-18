{
    "Type": "AWS::AutoScaling::LaunchConfiguration",
    "Metadata": {
        "AWS::CloudFormation::Init": {
            "configSets": {
                "SetupNode": [
                    "SetAWSCLIRegion",
                    "SetLicense",
                    "SetHostnames",
                    "SetMonitor",
                    "AttachNetwork",
                    "AttachVolume",
                    "MountVolume",
                    "StartInfluxDB",
                    "StartTelegraf"
                ]
            },
            "SetAWSCLIRegion": {
                "files": {
                    "/root/.aws/config": {
                        "content": {
                            "Fn::Sub": "[default]\nregion = ${AWS::Region}\n"
                        },
                        "mode": "000644",
                        "owner": "root",
                        "group": "root"
                    }
                }
            },
            "SetLicense": {
                "files": {
                    "/etc/default/influxdb-meta": {
                        "content": "INFLUXDB_ENTERPRISE_MARKETPLACE_ENV=aws",
                        "mode": "000644",
                        "owner": "root",
                        "group": "root"
                    }
                }
            },
            "SetHostnames": {
                "commands": {
                    "01_set_instance_hostname": {
                        "command": {
                            "Fn::Join": [
                                "",
                                [
                                    "set -x",
                                    "\n",
                                    "INFLUXDB_HOSTNAME=$( aws ec2 describe-tags",
                                    "        --filters \"Name=resource-id,Values=$INSTANCE_ID\"",
                                    "        --query \"Tags[?Key=='influxdb-hostname'].Value\"",
                                    "        --output text )",
                                    "\n",
                                    "echo \"INFLUXDB_HOSTNAME=$INFLUXDB_HOSTNAME\" >> /etc/default/influxdb",
                                    "\n"
                                ]
                            ]
                        }
                    }
                }
            },
            "SetMonitor": {
                "files": {
                    "/etc/default/telegraf": {
                        "content": {
                            "Fn::Join": [
                                "",
                                [
                                    "MONITOR_HOSTNAME=",
                                    {
                                        "Ref": "MonitorDns"
                                    },
                                    "\n",
                                    "MONITOR_USERNAME=",
                                    {
                                        "Ref": "Username"
                                    },
                                    "\n",
                                    "MONITOR_PASSWORD=",
                                    {
                                        "Ref": "Password"
                                    },
                                    "\n"
                                ]
                            ]
                        },
                        "mode": "000644",
                        "owner": "root",
                        "group": "root"
                    }
                }
            },
            "AttachNetwork": {
                "commands": {
                    "01_attach_network": {
                        "command": {
                            "Fn::Join": [
                                "",
                                [
                                    "set -x",
                                    "\n",
                                    "# If network interface is not attached to this instance, then attach it",
                                    "\n",
                                    "ENI_ID=$( aws ec2 describe-tags",
                                    "        --filters \"Name=resource-id,Values=$INSTANCE_ID\"",
                                    "        --query \"Tags[?Key=='influxdb-eni'].Value\"",
                                    "        --output text )",
                                    "\n",
                                    "STATUS=$( aws ec2 describe-network-interfaces",
                                    "        --network-interface-ids $ENI_ID",
                                    "        --filters \"Name=attachment.instance-id,Values=$INSTANCE_ID\"",
                                    "        --query \"NetworkInterfaces[0].Attachment.Status\"",
                                    "        --output text )",
                                    "\n",
                                    "# TODO: switch to until 'attached' loop",
                                    "\n",
                                    "if ! [[ $STATUS =~ (attached|attaching) ]]; then",
                                    "\n",
                                    "# Wait until network interface is available",
                                    "\n",
                                    "aws ec2 wait network-interface-available",
                                    "        --network-interface-ids $ENI_ID",
                                    "\n",
                                    "aws ec2 attach-network-interface",
                                    "        --network-interface-id $ENI_ID",
                                    "        --instance-id $INSTANCE_ID",
                                    "        --device-index 1",
                                    "\n",
                                    "# Reload network to automatically enable eth1 via Amazon Linux 2 ec2-net-utils",
                                    "\n",
                                    "systemctl restart network",
                                    "\n",
                                    "fi",
                                    "\n"
                                ]
                            ]
                        }
                    }
                }
            },
            "AttachVolume": {
                "commands": {
                    "01_attach_volume": {
                        "command": {
                            "Fn::Join": [
                                "",
                                [
                                    "set -x",
                                    "\n",
                                    "# If EBS volume is not attached to this instance, then attach it",
                                    "\n",
                                    "VOLUME_ID=$( aws ec2 describe-tags",
                                    "        --filters \"Name=resource-id,Values=$INSTANCE_ID\"",
                                    "        --query \"Tags[?Key=='influxdb-volume'].Value\"",
                                    "        --output text )",
                                    "\n",
                                    "STATUS=$( aws ec2 describe-volumes",
                                    "        --volume-ids $VOLUME_ID",
                                    "        --filters \"Name=attachment.instance-id,Values=$INSTANCE_ID\"",
                                    "        --query \"Volumes[0].Attachments[0].State\"",
                                    "        --output text )",
                                    "\n",
                                    "if ! [[ $STATUS =~ (attached|attaching) ]]; then",
                                    "\n",
                                    "# Wait until volume is available",
                                    "\n",
                                    "aws ec2 wait volume-available",
                                    "        --volume-ids $VOLUME_ID",
                                    "\n",
                                    "aws ec2 attach-volume",
                                    "        --volume-id $VOLUME_ID",
                                    "        --instance-id $INSTANCE_ID",
                                    "        --device /dev/xvdh",
                                    "\n",
                                    "until [[ \"$(",
                                    "aws ec2 describe-volume-status",
                                    "        --volume-ids $VOLUME_ID",
                                    "        --query 'VolumeStatuses[0].VolumeStatus.Details[?Name==`io-enabled`].Status'",
                                    "        --output text",
                                    ")\" == 'passed' ]]; do sleep 5; done",
                                    "\n",
                                    "fi",
                                    "\n"
                                ]
                            ]
                        }
                    }
                }
            },
            "MountVolume": {
                "commands": {
                    "01_mount_volumes": {
                        "command": {
                            "Fn::Join": [
                                "",
                                [
                                    "set -x",
                                    "\n",
                                    "/sbin/ebsnvme-id -b /dev/nvme1n1",
                                    "\n",
                                    "until [ -b $(readlink -f /dev/xvdh) ]; do sleep 1; done",
                                    "\n",
                                    "if [[ \"$(lsblk -no FSTYPE /dev/xvdh)\" != \"ext4\" ]]; then",
                                    "\n",
                                    "/usr/sbin/mkfs -t ext4 /dev/xvdh",
                                    "\n",
                                    "sleep 10",
                                    "\n",
                                    "fi",
                                    "\n",
                                    "mkdir -p /influxdb",
                                    "\n",
                                    "mount /dev/xvdh /influxdb",
                                    "\n",
                                    "/sbin/resize2fs /dev/xvdh",
                                    "\n",
                                    "mkdir -p /influxdb/meta /influxdb /influxdb/wal /influxdb/hh",
                                    "\n",
                                    "chown -R influxdb:influxdb /influxdb",
                                    "\n"
                                ]
                            ]
                        }
                    },
                    "02_set_fstab": {
                        "command": {
                            "Fn::Join": [
                                "",
                                [
                                    "set -x",
                                    "\n",
                                    "DEVICE_UUID=\"$(blkid -s UUID -o value /dev/xvdh)\"",
                                    "\n",
                                    "if grep -q \"$DEVICE_UUID\" /etc/fstab; then",
                                    "\n",
                                    "echo \"fstab already set\"",
                                    "\n",
                                    "else",
                                    "\n",
                                    "cp /etc/fstab /etc/fstab.original",
                                    "\n",
                                    "echo -e \"UUID=$DEVICE_UUID\t/influxdb\text4\tdefaults,nofail\t0\t2\" >> /etc/fstab",
                                    "\n",
                                    "fi",
                                    "\n"
                                ]
                            ]
                        }
                    }
                }
            },
            "StartInfluxDB": {
                "commands": {
                    "01_enable_influxdb_service": {
                        "command": "systemctl enable influxdb"
                    },
                    "02_start_influxdb_service": {
                        "command": "systemctl start influxdb"
                    }
                }
            },
            "StartTelegraf": {
                "commands": {
                    "01_enable_telegraf_service": {
                        "command": "systemctl enable telegraf"
                    },
                    "02_start_telegraf_service": {
                        "command": "systemctl start telegraf"
                    }
                }
            }
        }
    },
    "Properties": {
        "ImageId": {
            "Fn::FindInMap": [
                "AMIRegionMap",
                {
                    "Ref": "AWS::Region"
                },
                "Data"
            ]
        },
        "InstanceType": {
            "Ref": "DataNodeInstanceType"
        },
        "SecurityGroups": [
            {
                "Ref": "SshSecurityGroup"
            },
            {
                "Ref": "InfluxDBInternalSecurityGroup"
            },
            {
                "Ref": "InfluxDBDataNodeSecurityGroup"
            }
        ],
        "KeyName": {
            "Ref": "KeyName"
        },
        "EbsOptimized": true,
        "IamInstanceProfile": {
            "Ref": "InfluxDBInstanceProfile"
        },
        "UserData": {
            "Fn::Base64": {
                "Fn::Join": [
                    "",
                    [
                        "#!/usr/bin/env bash",
                        "\n",
                        "set -euxo pipefail",
                        "\n",
                        "yum update -y aws-cfn-bootstrap ec2-net-utils",
                        "\n",
                        "export INSTANCE_ID=$( curl -s http://169.254.169.254/latest/meta-data/instance-id )",
                        "\n",
                        "/opt/aws/bin/cfn-init -v ",
                        "        --stack ",
                        {
                            "Ref": "AWS::StackName"
                        },
                        "        --region ",
                        {
                            "Ref": "AWS::Region"
                        },
                        "        --resource DataNodeLaunchConfiguration ",
                        "        --configsets SetupNode",
                        "\n",
                        "ASG_NAME=$( aws ec2 describe-tags",
                        "        --filters \"Name=resource-id,Values=$INSTANCE_ID\"",
                        "        --query \"Tags[?Key=='aws:cloudformation:logical-id'].Value\"",
                        "        --output text )",
                        "\n",
                        "# Signal the status from cfn-init\n",
                        "/opt/aws/bin/cfn-signal -e $? ",
                        "        --stack ",
                        {
                            "Ref": "AWS::StackName"
                        },
                        "        --region ",
                        {
                            "Ref": "AWS::Region"
                        },
                        "        --resource $ASG_NAME",
                        "\n"
                    ]
                ]
            }
        }
    }
}