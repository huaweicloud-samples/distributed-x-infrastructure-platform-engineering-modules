# =============================================================================
# vpc-env
# 模块能力：基础 VPC + 子网 + 消息通知主题
# 资源构成：VPC、2 个公网子网、2 个私网子网、默认安全组、SMN 主题
# 实现说明：CIDR / 可用区等参数通过 variables.tf 传入，可独立部署
# =============================================================================

terraform {
  required_version = ">= 1.5"
  required_providers {
    huaweicloud = {
      source  = "huaweicloud/huaweicloud"
      version = "~> 1.70"
    }
  }
}

provider "huaweicloud" {
  region = var.region
}

# -----------------------------------------------------------------------------
# 变量
# -----------------------------------------------------------------------------

variable "region" {
  type    = string
  default = "cn-north-4"
}

variable "project_name" {
  type    = string
  default = "vpc-env"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_one_cidr" {
  type    = string
  default = "10.0.0.0/18"
}

variable "public_subnet_two_cidr" {
  type    = string
  default = "10.0.64.0/18"
}

variable "private_subnet_one_cidr" {
  type    = string
  default = "10.0.128.0/18"
}

variable "private_subnet_two_cidr" {
  type    = string
  default = "10.0.192.0/18"
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------

resource "huaweicloud_vpc" "this" {
  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr
}

# -----------------------------------------------------------------------------
# 子网（2 公网 + 2 私网）
# -----------------------------------------------------------------------------

resource "huaweicloud_vpc_subnet" "public_one" {
  name       = "${var.project_name}-public-one"
  vpc_id     = huaweicloud_vpc.this.id
  cidr       = var.public_subnet_one_cidr
  gateway_ip = cidrhost(var.public_subnet_one_cidr, 1)
}

resource "huaweicloud_vpc_subnet" "public_two" {
  name       = "${var.project_name}-public-two"
  vpc_id     = huaweicloud_vpc.this.id
  cidr       = var.public_subnet_two_cidr
  gateway_ip = cidrhost(var.public_subnet_two_cidr, 1)
}

resource "huaweicloud_vpc_subnet" "private_one" {
  name       = "${var.project_name}-private-one"
  vpc_id     = huaweicloud_vpc.this.id
  cidr       = var.private_subnet_one_cidr
  gateway_ip = cidrhost(var.private_subnet_one_cidr, 1)
}

resource "huaweicloud_vpc_subnet" "private_two" {
  name       = "${var.project_name}-private-two"
  vpc_id     = huaweicloud_vpc.this.id
  cidr       = var.private_subnet_two_cidr
  gateway_ip = cidrhost(var.private_subnet_two_cidr, 1)
}

# -----------------------------------------------------------------------------
# 安全组（默认放行出站 + 80 入站）
# -----------------------------------------------------------------------------

resource "huaweicloud_networking_secgroup" "default" {
  name        = "${var.project_name}-default-sg"
  description = "Default security group for ${var.project_name}"
}

resource "huaweicloud_networking_secgroup_rule" "allow_http_ingress" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = huaweicloud_networking_secgroup.default.id
}

# APIG 专享实例对外暴露 HTTPS（443）；绑定 EIP 后公网调用必须经此端口入站
resource "huaweicloud_networking_secgroup_rule" "allow_https_ingress" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = huaweicloud_networking_secgroup.default.id
}

resource "huaweicloud_networking_secgroup_rule" "allow_all_egress" {
  direction        = "egress"
  ethertype        = "IPv4"
  remote_ip_prefix = "0.0.0.0/0"
  # protocol 省略 = 全协议放行
  security_group_id = huaweicloud_networking_secgroup.default.id
}

# -----------------------------------------------------------------------------
# SMN 消息通知
# -----------------------------------------------------------------------------

resource "huaweicloud_smn_topic" "ping" {
  name         = "${var.project_name}-ping"
  display_name = "${var.project_name} ping topic"
}

# -----------------------------------------------------------------------------
# 输出
# -----------------------------------------------------------------------------

output "vpc_id" {
  value = huaweicloud_vpc.this.id
}

output "vpc_default_security_group_id" {
  value = huaweicloud_networking_secgroup.default.id
}

output "public_subnet_one_id" {
  value = huaweicloud_vpc_subnet.public_one.id
}

output "public_subnet_two_id" {
  value = huaweicloud_vpc_subnet.public_two.id
}

output "private_subnet_one_id" {
  value = huaweicloud_vpc_subnet.private_one.id
}

output "private_subnet_two_id" {
  value = huaweicloud_vpc_subnet.private_two.id
}

output "ping_topic_urn" {
  value = huaweicloud_smn_topic.ping.topic_urn
}

output "ping_topic_name" {
  value = huaweicloud_smn_topic.ping.name
}
