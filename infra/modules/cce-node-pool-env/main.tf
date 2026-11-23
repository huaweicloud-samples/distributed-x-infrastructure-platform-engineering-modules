# =============================================================================
# cce-node-pool-env
# 模块能力：CCE 集群 + 节点池（节点形态的容器运行环境）
# 资源构成：CCE 集群、节点池、默认安全组、SMN 主题
# 实现说明：
#   - 节点弹性由 CCE 节点池原生承担（min / max / desired 节点数）
#   - 节点下线时由 CCE 自动排空并驱逐节点上的 Pod
#   - 服务发现使用 K8s Service（ClusterIP）
#   - 节点登录凭据由 node_key_pair / node_password 变量提供
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
  default = "cce-node-pool-env"
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "cluster_flavor_id" {
  type    = string
  default = "cce.s1.small"
}

variable "node_pool_flavor" {
  type    = string
  default = "s6.large.2"
}

variable "node_key_pair" {
  type        = string
  description = "节点登录密钥对名称（需在华为云提前创建）"
}

variable "initial_node_count" {
  type    = number
  default = 1
}

variable "max_node_count" {
  type    = number
  default = 5
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
  container_network_type = "overlay_l2"
  service_network_cidr   = "172.16.0.0/16"
}

# -----------------------------------------------------------------------------
# 节点池
# -----------------------------------------------------------------------------

resource "huaweicloud_cce_node_pool" "this" {
  cluster_id         = huaweicloud_cce_cluster.this.id
  name               = "${var.project_name}-nodepool"
  flavor_id          = var.node_pool_flavor
  initial_node_count = var.initial_node_count
  subnet_id          = var.subnet_id
  key_pair           = var.node_key_pair

  scall_enable             = true
  min_node_count           = 1
  max_node_count           = var.max_node_count
  scale_down_cooldown_time = 300
  priority                 = 0
  type                     = "vm"

  root_volume {
    size       = 40
    volumetype = "SSD"
  }

  data_volumes {
    size       = 100
    volumetype = "SSD"
  }
}

# -----------------------------------------------------------------------------
# SMN 主题（环境层 ping）
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

output "node_pool_id" {
  value = huaweicloud_cce_node_pool.this.id
}

output "ping_topic_urn" {
  value = huaweicloud_smn_topic.ping.topic_urn
}
