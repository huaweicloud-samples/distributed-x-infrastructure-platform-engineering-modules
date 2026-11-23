# =============================================================================
# cce-cluster-env
# 模块能力：CCE 集群（容器运行环境）+ 消息通知主题
# 资源构成：CCE 集群、默认安全组、SMN 主题
# 实现说明：
#   - 集群统一为 CCE Turbo，容器网络直通 VPC
#   - 算力由节点池（按需）提供，同时支持无服务器算力形态
#   - 服务发现使用 K8s Service / DNS，不使用独立的服务发现命名空间
#   - 工作负载访问云服务的授权由 IAM 委托承担（集群默认具备 cce-admin 委托）
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
  default = "cce-cluster-env"
}

variable "vpc_id" {
  type        = string
  description = "来自 vpc-env 模块"
}

variable "subnet_id" {
  type        = string
  description = "用于 CCE 集群的子网 ID（推荐用私网子网）"
}

variable "cluster_flavor_id" {
  type        = string
  default     = "cce.s1.small"
  description = "CCE 集群规格（按需调整）"
}

variable "container_network_type" {
  type    = string
  default = "overlay_l2"
}

# -----------------------------------------------------------------------------
# 复用 vpc-env 的安全组（如未传入则新建）
# -----------------------------------------------------------------------------

variable "security_group_id" {
  type        = string
  default     = null
  description = "如不传，将新建一个默认安全组"
}

resource "huaweicloud_networking_secgroup" "cce_default" {
  count       = var.security_group_id == null ? 1 : 0
  name        = "${var.project_name}-cce-sg"
  description = "Default SG for ${var.project_name} CCE cluster"
}

locals {
  effective_sg_id = var.security_group_id != null ? var.security_group_id : huaweicloud_networking_secgroup.cce_default[0].id
}

# -----------------------------------------------------------------------------
# CCE 集群
# -----------------------------------------------------------------------------

resource "huaweicloud_cce_cluster" "this" {
  name                   = "${var.project_name}-cce"
  cluster_type           = "VirtualMachine"
  flavor_id              = var.cluster_flavor_id
  vpc_id                 = var.vpc_id
  subnet_id              = var.subnet_id
  container_network_type = var.container_network_type
  service_network_cidr   = "172.16.0.0/16"
  authentication_mode    = "rbac"

  timeouts {
    create = "30m"
    delete = "30m"
  }
}

# -----------------------------------------------------------------------------
# SMN 主题（环境层 ping 主题，供上层服务模板订阅）
# -----------------------------------------------------------------------------

resource "huaweicloud_smn_topic" "ping" {
  name         = "${var.project_name}-ping"
  display_name = "${var.project_name} ping"
}

# -----------------------------------------------------------------------------
# 输出
# -----------------------------------------------------------------------------

output "cluster_id" {
  value = huaweicloud_cce_cluster.this.id
}

output "cluster_name" {
  value = huaweicloud_cce_cluster.this.name
}

output "cluster_status" {
  value = huaweicloud_cce_cluster.this.status
}

output "security_group_id" {
  value = local.effective_sg_id
}

output "ping_topic_urn" {
  value = huaweicloud_smn_topic.ping.topic_urn
}

output "ping_topic_name" {
  value = huaweicloud_smn_topic.ping.name
}
